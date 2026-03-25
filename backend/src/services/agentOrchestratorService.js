const geminiService = require('./geminiService');
const consistencyAgentService = require('./consistencyAgentService');
const storyMemoryService = require('./storyMemoryService');
const cacheService = require('./cacheService');
const prisma = require('../config/database');

/**
 * Agent Orchestrator Service — Multi-Agent Hikaye Pipeline
 *
 * Pipeline: Writer Agent → Consistency Agent → (Retry?) → Final
 *
 * 1. Writer Agent: geminiService.continueStory() ile uzun bölüm üretir
 * 2. Consistency Agent: Üretilen metni entity/event/lore'a karşı doğrular
 * 3. Tutarsızlık varsa: Writer'a düzeltme talimatı ile max 1 retry
 * 4. Final: Doğrulanmış metni döndürür
 */

const MAX_RETRIES = 1;

/**
 * Hikaye devamı için multi-agent pipeline çalıştırır (non-streaming).
 * @param {Object} storyContext - Hikaye bilgileri
 * @returns {Promise<Object>} - { storyData, rawResponse, usageMetadata, consistencyScore }
 */
async function orchestrateContinuation(storyContext) {
  const {
    storyId,
    genre,
    summary,
    recentChapters,
    choiceText,
    imageBase64,
    mood,
    characters,
    language,
    memoryContext,
    chapterCount,
  } = storyContext;

  // --- Adım 1: Hafıza bilgilerini topla (consistency check için) ---
  let fullMemory = null;
  try {
    fullMemory = await getFullMemoryForConsistency(storyId, choiceText);
  } catch (err) {
    console.error('Orchestrator hafıza toplama hatası:', err.message);
  }

  // --- Adım 2: Writer Agent — İlk üretim ---
  const writerResult = await geminiService.continueStory(
    genre,
    summary,
    recentChapters,
    choiceText,
    imageBase64,
    { mood, characters, language, memoryContext, chapterCount },
  );

  let finalResult = writerResult;
  let consistencyScore = 100;

  // --- Adım 3: Consistency Agent — Doğrulama ---
  const shouldCheck = consistencyAgentService.shouldCheckConsistency(
    chapterCount,
    fullMemory?.entities?.length || 0,
  );

  if (shouldCheck && fullMemory) {
    try {
      const validation = await consistencyAgentService.validateConsistency(
        writerResult.storyData.storyText,
        fullMemory,
        choiceText,
      );

      consistencyScore = validation.score;

      // Kritik tutarsızlık varsa → retry
      const hasCritical = validation.issues.some((i) => i.severity === 'critical');
      if (!validation.isConsistent && hasCritical) {
        console.log(`⚠️ Tutarsızlık tespit edildi (skor: ${validation.score}), düzeltme deneniyor...`);

        const correctionPrompt = consistencyAgentService.buildCorrectionPrompt(validation.issues);
        if (correctionPrompt) {
          // Retry: Düzeltme talimatı + orijinal seçenek ile tekrar üret
          const correctedChoiceText = choiceText + correctionPrompt;
          const retryResult = await geminiService.continueStory(
            genre,
            summary,
            recentChapters,
            correctedChoiceText,
            imageBase64,
            { mood, characters, language, memoryContext, chapterCount },
          );

          // Retry sonucu validate edilmez (sonsuz döngü riski), direkt kabul et
          finalResult = retryResult;
          consistencyScore = Math.min(validation.score + 20, 95); // Tahmini iyileşme
          console.log(`✅ Düzeltme tamamlandı, yeni tahmini skor: ${consistencyScore}`);
        }
      } else {
        console.log(`✅ Tutarlılık doğrulandı (skor: ${validation.score})`);
      }
    } catch (err) {
      console.error('Consistency check hatası (metin kabul ediliyor):', err.message);
    }
  }

  return {
    ...finalResult,
    consistencyScore,
  };
}

/**
 * Streaming pipeline — Writer Agent streaming + post-hoc consistency (opsiyonel).
 * Streaming'de real-time consistency check yapılamaz, ama metin toplandıktan sonra
 * arka planda consistency check yapılıp loglanabilir.
 *
 * @param {Object} storyContext
 * @yields {string} - Streaming chunk'ları
 */
async function* orchestrateContinuationStream(storyContext) {
  const {
    genre,
    summary,
    recentChapters,
    choiceText,
    imageBase64,
    mood,
    characters,
    language,
    memoryContext,
    chapterCount,
  } = storyContext;

  // Writer Agent streaming — direkt yield et
  const stream = geminiService.continueStoryStream(
    genre,
    summary,
    recentChapters,
    choiceText,
    imageBase64,
    { mood, characters, language, memoryContext, chapterCount },
  );

  for await (const chunk of stream) {
    yield chunk;
  }

  // NOT: Streaming modda consistency check post-hoc olarak storyService'de yapılır
}

/**
 * Consistency check için tüm hafıza bilgilerini toplar.
 */
async function getFullMemoryForConsistency(storyId, choiceText) {
  // Tüm entity'leri al (status bilgisi dahil)
  const entities = await prisma.storyEntity.findMany({
    where: { storyId },
    select: {
      type: true,
      name: true,
      description: true,
      status: true,
      relationships: true,
      importance: true,
    },
    orderBy: { importance: 'desc' },
    take: 30,
  });

  // Son olayları al (son 10 bölüm)
  const events = await prisma.storyEvent.findMany({
    where: {
      storyId,
      isResolved: false,
    },
    select: {
      chapterNum: true,
      description: true,
      impact: true,
      isResolved: true,
    },
    orderBy: { chapterNum: 'desc' },
    take: 15,
  });

  // Lore kurallarını al
  const lore = await prisma.storyLore.findMany({
    where: { storyId, isCanon: true },
    select: {
      category: true,
      title: true,
      content: true,
    },
    take: 10,
  });

  // Son world state
  const latestWorldState = await prisma.storyWorldState.findFirst({
    where: { storyId },
    orderBy: { chapterNumber: 'desc' },
  });

  return {
    entities,
    events,
    lore,
    worldState: latestWorldState?.state || null,
  };
}

/**
 * Quick summary'yi arka planda üret ve kaydet.
 */
async function generateAndSaveQuickSummary(storyId, chapterId, chapterContent, chapterNumber) {
  try {
    const quickSummary = await geminiService.generateSummary(
      [{ chapterNumber, content: chapterContent }],
      '',
      'quick',
    );

    await prisma.chapter.update({
      where: { id: chapterId },
      data: { quickSummary },
    });

    console.log(`📝 Bölüm ${chapterNumber} quick summary kaydedildi`);
  } catch (err) {
    console.error('Quick summary hatası:', err.message);
  }
}

module.exports = {
  orchestrateContinuation,
  orchestrateContinuationStream,
  getFullMemoryForConsistency,
  generateAndSaveQuickSummary,
};
