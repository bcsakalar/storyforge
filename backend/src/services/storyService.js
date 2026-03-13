const prisma = require('../config/database');
const geminiService = require('./geminiService');
const characterService = require('./characterService');
const storyMemoryService = require('./storyMemoryService');
const cacheService = require('./cacheService');

const RECENT_CHAPTERS_COUNT = 5;

/**
 * Kullanıcının tüm hikayelerini getirir.
 */
async function getUserStories(userId) {
  return prisma.story.findMany({
    where: { userId },
    include: {
      chapters: {
        orderBy: { chapterNumber: 'desc' },
        take: 1,
      },
      _count: { select: { chapters: true } },
    },
    orderBy: { updatedAt: 'desc' },
  });
}

/**
 * Bir hikayeyi tüm chapter'larıyla getirir.
 */
async function getStoryWithChapters(storyId, userId) {
  return prisma.story.findFirst({
    where: { id: storyId, userId },
    include: {
      chapters: {
        orderBy: { chapterNumber: 'asc' },
      },
    },
  });
}

/**
 * Yeni hikaye başlatır ve ilk chapter'ı üretir.
 */
async function createStory(userId, genre, { mood, language } = {}) {
  // Gemini'den ilk bölümü al
  const result = await geminiService.startNewStory(genre, { mood, language });
  const { storyData } = result;

  // Story ve ilk chapter'ı kaydet
  const story = await prisma.story.create({
    data: {
      userId,
      title: storyData.storyText.substring(0, 80).replace(/\n/g, ' ').trim() + '...',
      genre,
      mood: mood || null,
      summary: storyData.chapterSummary || '',
      interactionId: result.interactionId,
      chapters: {
        create: {
          chapterNumber: 1,
          content: storyData.storyText,
          choices: storyData.choices,
          summary: storyData.chapterSummary || null,
          interactionId: result.interactionId || 'initial',
        },
      },
    },
    include: {
      chapters: true,
    },
  });

  // İlk bölüm için hafıza işleme (arka planda)
  storyMemoryService.processChapter(story.id, 1, storyData.storyText, storyData.chapterSummary).catch((err) => {
    console.error('İlk bölüm hafıza hatası:', err.message);
  });

  return story;
}

/**
 * Kullanıcı seçimi yaparak hikayeyi devam ettirir.
 */
async function makeChoice(storyId, userId, choiceId, imageBase64 = null) {
  // Hikayeyi ve chapter'ları getir
  const story = await prisma.story.findFirst({
    where: { id: storyId, userId },
    include: {
      chapters: {
        orderBy: { chapterNumber: 'asc' },
      },
    },
  });

  if (!story) throw new Error('Hikaye bulunamadı');
  if (!story.isActive) throw new Error('Bu hikaye artık aktif değil');

  // Son chapter'ı bul
  const lastChapter = story.chapters[story.chapters.length - 1];
  if (lastChapter.selectedChoice !== null) {
    throw new Error('Bu bölüm için zaten bir seçim yapılmış');
  }

  // Seçilen seçeneğin metnini bul
  const choices = lastChapter.choices;
  const selectedChoice = choices.find((c) => c.id === choiceId);
  if (!selectedChoice) throw new Error('Geçersiz seçenek');

  // Son N chapter'ı al (context için)
  const recentChapters = story.chapters.slice(-RECENT_CHAPTERS_COUNT).map((ch) => ({
    chapterNumber: ch.chapterNumber,
    content: ch.content,
    selectedChoiceText: ch.selectedChoice !== null
      ? ch.choices.find((c) => c.id === ch.selectedChoice)?.text
      : null,
  }));

  // Gemini'ye gönder
  const characters = await characterService.getCharacters(story.id, userId);

  // RAG: İlgili hafıza kontekstini al (cache'den veya pgvector'den)
  let memoryContext = '';
  try {
    const cached = await cacheService.getCachedStoryContext(storyId);
    if (cached) {
      memoryContext = cached;
    } else {
      const ragContext = await storyMemoryService.getRelevantContext(storyId, selectedChoice.text);
      memoryContext = storyMemoryService.buildMemoryContext(ragContext);
      if (memoryContext) {
        await cacheService.cacheStoryContext(storyId, memoryContext);
      }
    }
  } catch (err) {
    console.error('RAG context hatası:', err.message);
  }

  const result = await geminiService.continueStory(
    story.genre,
    story.summary,
    recentChapters,
    selectedChoice.text,
    imageBase64,
    { mood: story.mood, characters, memoryContext, chapterCount: lastChapter.chapterNumber },
  );

  const { storyData } = result;
  const newChapterNumber = lastChapter.chapterNumber + 1;

  // Transaction: son chapter'ın seçimini güncelle + yeni chapter oluştur + story güncelle
  const [, , updatedStory] = await prisma.$transaction([
    // Son chapter'ın seçimini kaydet
    prisma.chapter.update({
      where: { id: lastChapter.id },
      data: { selectedChoice: choiceId, imageData: imageBase64 },
    }),
    // Yeni chapter oluştur
    prisma.chapter.create({
      data: {
        storyId: story.id,
        chapterNumber: newChapterNumber,
        content: storyData.storyText,
        choices: storyData.choices,
        summary: storyData.chapterSummary || null,
        interactionId: result.interactionId || `chapter_${newChapterNumber}`,
      },
    }),
    // Story'yi güncelle
    prisma.story.update({
      where: { id: story.id },
      data: {
        interactionId: result.interactionId,
        updatedAt: new Date(),
      },
    }),
  ]);

  // Periyodik özet kontrolü
  if (geminiService.shouldGenerateSummary(newChapterNumber)) {
    // Özeti arka planda üret (kullanıcıyı bekletme)
    generateAndSaveSummary(story.id).catch((err) => {
      console.error('Özet üretme hatası:', err.message);
    });
  }

  // Hafıza sistemi: yeni bölümü arka planda işle
  storyMemoryService.processChapter(story.id, newChapterNumber, storyData.storyText, storyData.chapterSummary).catch((err) => {
    console.error('Hafıza işleme hatası:', err.message);
  });

  // Cache'i invalidate et (yeni bölüm eklendi)
  cacheService.invalidateStoryContext(storyId).catch(() => {});

  // Token kullanımını kaydet
  if (result.usageMetadata) {
    const um = result.usageMetadata;
    storyMemoryService.trackTokenUsage(userId, storyId, 'gemini-3-flash-preview', um.promptTokenCount || 0, um.candidatesTokenCount || 0, 'generate').catch(() => {});
    cacheService.trackDailyTokens(userId, um.promptTokenCount || 0, um.candidatesTokenCount || 0).catch(() => {});
  }

  // Güncellenmiş hikayeyi döndür
  return getStoryWithChapters(story.id, userId);
}

/**
 * Hikaye özetini üretir ve kaydeder.
 */
async function generateAndSaveSummary(storyId) {
  const story = await prisma.story.findUnique({
    where: { id: storyId },
    include: {
      chapters: {
        orderBy: { chapterNumber: 'asc' },
      },
    },
  });

  if (!story) return;

  const summary = await geminiService.generateSummary(story.chapters, story.summary);

  await prisma.story.update({
    where: { id: storyId },
    data: { summary },
  });

  console.log(`Hikaye #${storyId} için özet güncellendi (${story.chapters.length} bölüm)`);
}

/**
 * Hikayeyi siler.
 */
async function deleteStory(storyId, userId) {
  const story = await prisma.story.findFirst({
    where: { id: storyId, userId },
  });

  if (!story) throw new Error('Hikaye bulunamadı');

  await prisma.story.delete({ where: { id: storyId } });
  return true;
}

/**
 * Hikaye ağacını döndürür — tüm bölümler, seçimler ve dallanma yapısı.
 */
async function getStoryTree(storyId, userId) {
  const story = await prisma.story.findFirst({
    where: { id: storyId, userId },
    include: {
      chapters: {
        orderBy: { chapterNumber: 'asc' },
        select: {
          id: true,
          chapterNumber: true,
          summary: true,
          choices: true,
          selectedChoice: true,
        },
      },
    },
  });

  if (!story) throw new Error('Hikaye bulunamadı');
  return story;
}

/**
 * Belirli bir bölümden dallanarak yeni hikaye oluşturur (alternatif son).
 */
async function branchFromChapter(storyId, userId, chapterId, newChoiceId) {
  const story = await prisma.story.findFirst({
    where: { id: storyId, userId },
    include: {
      chapters: { orderBy: { chapterNumber: 'asc' } },
      characters: true,
    },
  });

  if (!story) throw new Error('Hikaye bulunamadı');

  const branchPoint = story.chapters.find((ch) => ch.id === chapterId);
  if (!branchPoint) throw new Error('Bölüm bulunamadı');

  const selectedChoice = branchPoint.choices.find((c) => c.id === newChoiceId);
  if (!selectedChoice) throw new Error('Geçersiz seçenek');

  // Branch noktasına kadar olan bölümleri al
  const chaptersUpToBranch = story.chapters.filter((ch) => ch.chapterNumber < branchPoint.chapterNumber);

  // Özet oluştur
  const summaryChapters = [...chaptersUpToBranch, branchPoint];
  let summary = '';
  for (const ch of summaryChapters) {
    summary += (ch.summary || ch.content.substring(0, 200)) + ' ';
  }

  // Yeni hikaye oluştur
  const result = await geminiService.continueStory(
    story.genre,
    summary.trim(),
    summaryChapters.slice(-RECENT_CHAPTERS_COUNT).map((ch) => ({
      chapterNumber: ch.chapterNumber,
      content: ch.content,
      selectedChoiceText: ch.selectedChoice !== null
        ? ch.choices.find((c) => c.id === ch.selectedChoice)?.text
        : null,
    })),
    selectedChoice.text,
    null,
    { mood: story.mood, characters: story.characters },
  );

  const { storyData } = result;

  // Yeni Story oluştur (fork)
  const newStory = await prisma.story.create({
    data: {
      userId,
      title: `${story.title} (Alternatif)`,
      genre: story.genre,
      mood: story.mood,
      summary: summary.trim(),
      chapters: {
        create: [
          // Önceki bölümleri kopyala
          ...chaptersUpToBranch.map((ch) => ({
            chapterNumber: ch.chapterNumber,
            content: ch.content,
            choices: ch.choices,
            selectedChoice: ch.selectedChoice,
            summary: ch.summary,
            interactionId: `fork_${ch.interactionId || ch.chapterNumber}`,
          })),
          // Branch noktası — yeni seçimle
          {
            chapterNumber: branchPoint.chapterNumber,
            content: branchPoint.content,
            choices: branchPoint.choices,
            selectedChoice: newChoiceId,
            summary: branchPoint.summary,
            interactionId: `fork_branch_${branchPoint.chapterNumber}`,
          },
          // Yeni devam bölümü
          {
            chapterNumber: branchPoint.chapterNumber + 1,
            content: storyData.storyText,
            choices: storyData.choices,
            summary: storyData.chapterSummary || null,
            interactionId: `fork_new_${branchPoint.chapterNumber + 1}`,
          },
        ],
      },
    },
    include: { chapters: true },
  });

  // Karakterleri de kopyala
  if (story.characters.length > 0) {
    await prisma.character.createMany({
      data: story.characters.map((ch) => ({
        storyId: newStory.id,
        userId,
        name: ch.name,
        personality: ch.personality,
        appearance: ch.appearance,
      })),
    });
  }

  return newStory;
}

/**
 * Hikayenin recap özetini döndürür.
 */
async function getRecap(storyId, userId) {
  const story = await prisma.story.findFirst({
    where: { id: storyId, userId },
    include: {
      chapters: { orderBy: { chapterNumber: 'asc' } },
    },
  });

  if (!story) throw new Error('Hikaye bulunamadı');
  if (story.chapters.length === 0) throw new Error('Henüz bölüm yok');

  const recap = await geminiService.generateRecap(story.chapters);
  return recap;
}

/**
 * Hikayeyi tamamlandı olarak işaretle.
 */
async function completeStory(storyId, userId) {
  const story = await prisma.story.findFirst({ where: { id: storyId, userId } });
  if (!story) throw new Error('Hikaye bulunamadı');

  return prisma.story.update({
    where: { id: storyId },
    data: { isCompleted: true, isActive: false },
  });
}

/**
 * Hikayeyi tüm bölümleriyle indirme için paketler (offline mod).
 */
async function downloadStory(storyId, userId) {
  const story = await prisma.story.findFirst({
    where: { id: storyId, userId },
    include: {
      chapters: { orderBy: { chapterNumber: 'asc' } },
      characters: true,
    },
  });

  if (!story) throw new Error('Hikaye bulunamadı');
  return story;
}

/**
 * Streaming: Yeni hikaye başlatır, chunk callback ile akış sağlar.
 */
async function createStoryStream(userId, genre, { mood, language } = {}, onChunk) {
  const stream = geminiService.startNewStoryStream(genre, { mood, language });

  let fullText = '';
  for await (const chunk of stream) {
    fullText += chunk;
    if (onChunk) onChunk(chunk);
  }

  const parsed = JSON.parse(fullText);

  const story = await prisma.story.create({
    data: {
      userId,
      title: parsed.storyText.substring(0, 80).replace(/\n/g, ' ').trim() + '...',
      genre,
      mood: mood || null,
      summary: parsed.chapterSummary || '',
      chapters: {
        create: {
          chapterNumber: 1,
          content: parsed.storyText,
          choices: parsed.choices,
          summary: parsed.chapterSummary || null,
          interactionId: 'initial',
        },
      },
    },
    include: { chapters: true },
  });

  return story;
}

/**
 * Streaming: Hikayeyi devam ettirir, chunk callback ile akış sağlar.
 */
async function makeChoiceStream(storyId, userId, choiceId, imageBase64, onChunk) {
  const story = await prisma.story.findFirst({
    where: { id: storyId, userId },
    include: {
      chapters: { orderBy: { chapterNumber: 'asc' } },
    },
  });

  if (!story) throw new Error('Hikaye bulunamadı');
  if (!story.isActive) throw new Error('Bu hikaye artık aktif değil');

  const lastChapter = story.chapters[story.chapters.length - 1];
  if (lastChapter.selectedChoice !== null) {
    throw new Error('Bu bölüm için zaten bir seçim yapılmış');
  }

  const selectedChoice = lastChapter.choices.find((c) => c.id === choiceId);
  if (!selectedChoice) throw new Error('Geçersiz seçenek');

  const recentChapters = story.chapters.slice(-RECENT_CHAPTERS_COUNT).map((ch) => ({
    chapterNumber: ch.chapterNumber,
    content: ch.content,
    selectedChoiceText: ch.selectedChoice !== null
      ? ch.choices.find((c) => c.id === ch.selectedChoice)?.text
      : null,
  }));

  const characters = await characterService.getCharacters(story.id, userId);

  // RAG: İlgili hafıza kontekstini al
  let memoryContext = '';
  try {
    const cached = await cacheService.getCachedStoryContext(storyId);
    if (cached) {
      memoryContext = cached;
    } else {
      const ragContext = await storyMemoryService.getRelevantContext(storyId, selectedChoice.text);
      memoryContext = storyMemoryService.buildMemoryContext(ragContext);
      if (memoryContext) {
        await cacheService.cacheStoryContext(storyId, memoryContext);
      }
    }
  } catch (err) {
    console.error('RAG context hatası:', err.message);
  }

  const stream = geminiService.continueStoryStream(
    story.genre,
    story.summary,
    recentChapters,
    selectedChoice.text,
    imageBase64,
    { mood: story.mood, characters, memoryContext, chapterCount: lastChapter.chapterNumber },
  );

  let fullText = '';
  for await (const chunk of stream) {
    fullText += chunk;
    if (onChunk) onChunk(chunk);
  }

  const parsed = JSON.parse(fullText);
  const newChapterNumber = lastChapter.chapterNumber + 1;

  await prisma.$transaction([
    prisma.chapter.update({
      where: { id: lastChapter.id },
      data: { selectedChoice: choiceId, imageData: imageBase64 },
    }),
    prisma.chapter.create({
      data: {
        storyId: story.id,
        chapterNumber: newChapterNumber,
        content: parsed.storyText,
        choices: parsed.choices,
        summary: parsed.chapterSummary || null,
        interactionId: `chapter_${newChapterNumber}`,
      },
    }),
    prisma.story.update({
      where: { id: story.id },
      data: { updatedAt: new Date() },
    }),
  ]);

  if (geminiService.shouldGenerateSummary(newChapterNumber)) {
    generateAndSaveSummary(story.id).catch((err) => {
      console.error('Özet üretme hatası:', err.message);
    });
  }

  // Hafıza sistemi: yeni bölümü arka planda işle
  storyMemoryService.processChapter(story.id, newChapterNumber, parsed.storyText, parsed.chapterSummary).catch((err) => {
    console.error('Hafıza işleme hatası:', err.message);
  });

  // Cache'i invalidate et
  cacheService.invalidateStoryContext(storyId).catch(() => {});

  return getStoryWithChapters(story.id, userId);
}

module.exports = {
  getUserStories,
  getStoryWithChapters,
  createStory,
  createStoryStream,
  makeChoice,
  makeChoiceStream,
  deleteStory,
  getStoryTree,
  branchFromChapter,
  getRecap,
  completeStory,
  downloadStory,
};
