const ai = require('../config/gemini');

const MODEL = 'gemini-3-flash-preview';
const SUMMARY_INTERVAL = 5;
const CHAIN_RESET_INTERVAL = 15;

const GENRE_DESCRIPTIONS = {
  fantastik: 'Büyü, ejderhalar, elfler ve destansı savaşlar içeren yüksek fantezi dünyası',
  korku: 'Gerilim, karanlık atmosfer, doğaüstü varlıklar ve psikolojik korku öğeleri',
  bilim_kurgu: 'Uzay yolculukları, ileri teknoloji, yapay zeka ve gelecek senaryoları',
  romantik: 'Aşk, ilişkiler, duygusal derinlik ve karakter gelişimi odaklı',
  macera: 'Aksiyon dolu, keşifler, tehlikeli görevler ve kahramanlık hikayeleri',
  gizem: 'Dedektiflik, suç çözme, sırlar ve beklenmedik plot twistleri',
};

const MOOD_DESCRIPTIONS = {
  korku: 'Karanlık, ürkütücü, tedirgin edici atmosfer. Gerilimi sürekli yüksek tut.',
  romantik: 'Duygusal, sıcak ve romantik. Karakterler arası bağ ve duygusal derinlik ön planda.',
  komedi: 'Eğlenceli, espirili ve hafif. Mizahi diyaloglar ve komik durumlar.',
  gerilim: 'Sürekli merak uyandıran, heyecan verici. Sürprizler ve tehlike hissi.',
  epik: 'Görkemli, büyük ölçekli ve destansı. Kadersel olaylar ve kahramanlık.',
  melankolik: 'Hüzünlü, düşündürücü ve nostaljik. Derin duygusal yansımalar.',
};

function buildSystemInstruction(genre, summary = '', { mood, characters, language, memoryContext } = {}) {
  const lang = language === 'en' ? 'en' : 'tr';
  const langText = lang === 'en' ? 'İngilizce' : 'Türkçe';

  let instruction = `Sen yetenekli bir interaktif hikaye yazarısın. ${langText} yazıyorsun.

## GÖREV
Kullanıcı için "${genre}" türünde interaktif bir hikaye yazıyorsun. Her yanıtında hikayenin bir bölümünü yazacak ve kullanıcıya seçenekler sunacaksın.

## TÜR ÖZELLİKLERİ
${GENRE_DESCRIPTIONS[genre] || 'Genel hikaye'}`;

  if (mood && MOOD_DESCRIPTIONS[mood]) {
    instruction += `

## MOOD / TON
Hikayenin tonu: "${mood}". ${MOOD_DESCRIPTIONS[mood]}`;
  }

  if (characters && characters.length > 0) {
    instruction += `

## KARAKTERLER
Hikayede aşağıdaki kullanıcı tanımlı karakterler yer alıyor. Bu karakterleri hikayeye doğal bir şekilde entegre et, isimlerini ve özelliklerini tutarlı kullan:
`;
    for (const char of characters) {
      instruction += `- **${char.name}**: Kişilik: ${char.personality || 'belirtilmemiş'}. Görünüş: ${char.appearance || 'belirtilmemiş'}.\n`;
    }
  }

  instruction += `

## KURALLAR
1. Her yanıtını MUTLAKA aşağıdaki JSON formatında ver. Başka hiçbir şey yazma.
2. Hikaye metni EN AZ 8-12 paragraf olmalı, her paragraf 4-6 cümle içermeli. Sahne tasvirleri, karakter diyalogları, iç monologlar ve atmosfer detayları dahil. Minimum 800-1200 kelime hedefle.
3. Her bölümde 2 ile 4 arasında seçenek sun (kendi kafana göre karar ver).
4. Seçenekler hikayeyi farklı yönlere çekmeli, her biri anlamlı ve ilginç olmalı.
5. Önceki olaylarla ASLA çelişme. Tutarlılığı koru. HAFIZA bölümünde verilen entity durumlarına (aktif/ölü/kayıp) kesinlikle uy.
6. Karakterlerin isimleri, özellikleri ve ilişkileri tutarlı olmalı. İlişki değişimlerini doğal yansıt.
7. Atmosferi türe uygun tut.
8. Her bölümün sonunda gerilim veya merak unsuru olsun.
9. "chapterSummary" alanında bu bölümde olan önemli olayları kısaca özetle (2-3 cümle).
10. HER ŞEYİ ${langText} yaz.
11. Karakter isimleri MUTLAKA benzersiz, yaratıcı ve nadir olmalı. "Elif", "Ali", "Ayşe", "Mehmet", "Zeynep", "Ahmet", "Fatma", "Mustafa", "Emre", "Burak" gibi sık kullanılan isimleri ASLA kullanma. Bunun yerine farklı kültürlerden, mitolojilerden veya tamamen özgün isimler tercih et.
12. Her hikayede tamamen orijinal bir dünya, olay örgüsü ve karakterler oluştur. Klişe açılışlardan ve kalıplardan kaçın. Sürpriz ve yaratıcılık ön planda olsun.
13. Diyalog sahneleri MUTLAKA olmalı — karakterlerin konuşmaları, düşünceleri ve hisleri detaylı aktarılmalı.
14. Her bölümde en az bir sahne geçişi veya zaman atlaması olmalı, sahne geçişlerini "***" ile ayır.
15. Mekan tasvirlerini zenginleştir — ses, koku, dokunma duyuları dahil et.
16. JSON storyText alanında paragrafları MUTLAKA \\n\\n (çift newline) ile ayır. Sahne geçişlerini \\n***\\n şeklinde yaz. Diyalog satırlarını da \\n ile ayır. Düz metin bloğu oluşturma, okunabilir paragraflar halinde yaz.

## JSON FORMAT
\`\`\`json
{
  "storyText": "Hikaye metni burada...",
  "choices": [
    {"id": 1, "text": "Seçenek açıklaması"},
    {"id": 2, "text": "Seçenek açıklaması"},
    {"id": 3, "text": "Seçenek açıklaması"}
  ],
  "mood": "gerilim|huzur|kaos|gizem|romantik|aksiyon|korku",
  "chapterSummary": "Bu bölümde olan önemli olayların kısa özeti"
}
\`\`\``;

  if (summary) {
    instruction += `

## HİKAYE ÖZETİ (ŞU ANA KADAR OLANLAR)
${summary}

ÖNEMLI: Yukarıdaki özet, hikayenin şu ana kadarki tüm olaylarını içeriyor. Bu bilgileri kullanarak hikayeyi tutarlı bir şekilde devam ettir. Önceki olaylarla çelişme.`;
  }

  // RAG hafıza konteksti ekle
  if (memoryContext) {
    instruction += `\n${memoryContext}`;
  }

  return instruction;
}

/**
 * Yeni bir hikaye başlatır. İlk chapter'ı üretir.
 */
async function startNewStory(genre, { mood, characters, language } = {}) {
  const systemInstruction = buildSystemInstruction(genre, '', { mood, characters, language });

  // Randomize opening prompt to ensure variety
  const openings = [
    'Hikayeyi tamamen beklenmedik bir olayla başlat. Benzersiz isimli bir ana karakter oluştur, dünyayı tanıt ve ilk seçenekleri sun.',
    'Sıra dışı bir sahneyle hikayeyi aç. Farklı ve yaratıcı isimli bir karakter yarat, atmosferi kur ve seçenekleri sun.',
    'Merak uyandıran gizemli bir başlangıç yaz. Nadir bir isimle ana karakteri tanıt, ortamı detaylı anlat ve ilk seçenekleri ver.',
    'Dramatik ve etkileyici bir açılış sahnesi yaz. Özgün isimli karakterleri hayata getir ve okuyucuyu hikayeye çek.',
    'Aksiyonun ortasında başla. Eşsiz isimli bir kahramanı tanıt, olayları hızlı bir tempoda başlat ve seçenekleri sun.',
  ];
  const prompt = openings[Math.floor(Math.random() * openings.length)];

  const interaction = await ai.models.generateContent({
    model: MODEL,
    contents: prompt,
    config: {
      systemInstruction,
      responseMimeType: 'application/json',
      temperature: 0.9,
      topP: 0.95,
      maxOutputTokens: 8192,
    },
  });

  const text = interaction.text;
  const parsed = JSON.parse(text);

  return {
    interactionId: null, // generateContent doesn't return interaction IDs; we use stateless with summary approach
    storyData: parsed,
    rawResponse: text,
  };
}

/**
 * Hikayeyi kullanıcı seçimiyle devam ettirir.
 * @param {string} genre - Hikaye türü
 * @param {string} summary - Şu ana kadarki hikaye özeti
 * @param {Array} recentChapters - Son chapter'ların içerikleri
 * @param {string} choiceText - Kullanıcının seçtiği seçenek metni
 * @param {string|null} imageBase64 - Kameradan gelen base64 fotoğraf (opsiyonel)
 * @param {Object} options - mood, characters, language
 */
async function continueStory(genre, summary, recentChapters, choiceText, imageBase64 = null, { mood, characters, language, memoryContext, chapterCount } = {}) {
  const systemInstruction = buildSystemInstruction(genre, summary, { mood, characters, language, memoryContext });

  // Build context from recent chapters
  let contextMessage = '';
  if (recentChapters.length > 0) {
    contextMessage = '## SON BÖLÜMLER\n';
    for (const ch of recentChapters) {
      contextMessage += `\n### Bölüm ${ch.chapterNumber}\n${ch.content}\nSeçilen: ${ch.selectedChoiceText || 'bilinmiyor'}\n`;
    }
    contextMessage += '\n---\n\n';
  }

  contextMessage += `Kullanıcı şu seçimi yaptı: "${choiceText}"\n\nBu seçime göre hikayeyi devam ettir.`;

  // Build contents array (multimodal if image provided)
  const parts = [];

  if (imageBase64) {
    parts.push({
      inlineData: {
        mimeType: 'image/jpeg',
        data: imageBase64,
      },
    });
    contextMessage += '\n\nKullanıcı ayrıca bir fotoğraf paylaştı. Bu fotoğrafı inceleyip hikayeye ve seçeneklere ilham kaynağı olarak kullan. Fotoğraftaki unsurları hikayeye doğal bir şekilde entegre et.';
  }

  parts.push({ text: contextMessage });

  const interaction = await ai.models.generateContent({
    model: MODEL,
    contents: [{ role: 'user', parts }],
    config: {
      systemInstruction,
      responseMimeType: 'application/json',
      temperature: 0.85,
      topP: 0.95,
      maxOutputTokens: 8192,
      // Thinking mode: 10+ bölümde derin akıl yürütme
      ...(chapterCount >= 10 && { thinkingConfig: { thinkingBudget: 2048 } }),
    },
  });

  const text = interaction.text;
  const parsed = JSON.parse(text);

  return {
    storyData: parsed,
    rawResponse: text,
    usageMetadata: interaction.usageMetadata || null,
  };
}

/**
 * Hikayenin kapsamlı özetini üretir (hafıza yenileme).
 * @param {Array} allChapters - Tüm chapter'ların listesi
 * @param {string} currentSummary - Mevcut özet (varsa)
 * @param {string} mode - 'deep' (kapsamlı, her 5 bölüm) | 'quick' (kısa, her bölüm)
 */
async function generateSummary(allChapters, currentSummary = '', mode = 'deep') {
  if (mode === 'quick') {
    // Son bölümün hızlı özeti (2-3 cümle)
    const lastChapter = allChapters[allChapters.length - 1];
    const quickPrompt = `Aşağıdaki hikaye bölümünün 2-3 cümlelik kısa bir özetini yaz. Sadece yeni olayları ve önemli değişiklikleri belirt. Başka bir şey yazma.\n\nBÖLÜM ${lastChapter.chapterNumber}:\n${lastChapter.content}`;

    const response = await ai.models.generateContent({
      model: MODEL,
      contents: quickPrompt,
      config: { temperature: 0.2, topP: 0.9, maxOutputTokens: 512 },
    });
    return response.text;
  }

  // Deep summary (kapsamlı)
  let prompt = 'Aşağıdaki hikaye bölümlerinin kapsamlı bir özetini oluştur. ';
  prompt += 'Özet şunları içermeli:\n';
  prompt += '1. Ana karakterler, özellikleri ve mevcut durumları (aktif/ölü/kayıp)\n';
  prompt += '2. Önemli olaylar kronolojik sırayla\n';
  prompt += '3. Mevcut durum ve açık kalan konular / çözülmemiş gerilimler\n';
  prompt += '4. Karakter ilişkileri ve değişimleri (düşman→dost gibi)\n';
  prompt += '5. Önemli mekanlar ve nesneler\n';
  prompt += '6. Evren kuralları ve keşfedilen sistemler\n\n';

  if (currentSummary) {
    prompt += `MEVCUT ÖZET:\n${currentSummary}\n\n`;
    prompt += 'YENİ BÖLÜMLER:\n';
  }

  for (const ch of allChapters) {
    prompt += `\nBölüm ${ch.chapterNumber}: ${ch.content}\n`;
  }

  prompt += '\n\nLütfen kapsamlı ve detaylı bir özet yaz (en az 500 kelime). Sadece özet metnini yaz, başka bir şey ekleme.';

  const response = await ai.models.generateContent({
    model: MODEL,
    contents: prompt,
    config: {
      temperature: 0.3,
      topP: 0.9,
      maxOutputTokens: 4096,
    },
  });

  return response.text;
}

/**
 * Periyodik özet gerekip gerekmediğini kontrol eder.
 */
function shouldGenerateSummary(chapterCount) {
  return chapterCount > 0 && chapterCount % SUMMARY_INTERVAL === 0;
}

/**
 * Zincir yenileme gerekip gerekmediğini kontrol eder.
 */
function shouldResetChain(chapterCount) {
  return chapterCount > 0 && chapterCount % CHAIN_RESET_INTERVAL === 0;
}

const TTS_MODEL = 'gemini-2.5-flash-preview-tts';

/**
 * Hikaye metnini Gemini TTS ile sese dönüştürür.
 * @param {string} text - Okunacak hikaye metni
 * @returns {string} - Base64 encoded PCM audio data
 */
async function generateSpeech(text) {
  const response = await ai.models.generateContent({
    model: TTS_MODEL,
    contents: text,
    config: {
      responseModalities: ['AUDIO'],
      speechConfig: {
        voiceConfig: {
          prebuiltVoiceConfig: { voiceName: 'Kore' },
        },
      },
    },
  });

  const audioData = response.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data;
  if (!audioData) {
    throw new Error('TTS yanıtından ses verisi alınamadı');
  }

  return audioData; // base64 PCM
}

/**
 * PCM base64 verisini WAV base64'e dönüştürür.
 * PCM: 24000 Hz, 16-bit, mono
 * Clipping önlemek için normalize eder.
 */
function pcmToWavBase64(pcmBase64) {
  const pcmBuffer = Buffer.from(pcmBase64, 'base64');
  const sampleRate = 24000;
  const numChannels = 1;
  const bitsPerSample = 16;
  const byteRate = sampleRate * numChannels * (bitsPerSample / 8);
  const blockAlign = numChannels * (bitsPerSample / 8);

  // --- Normalize: clip varsa sesi düşür ---
  let peak = 0;
  for (let i = 0; i < pcmBuffer.length - 1; i += 2) {
    const sample = pcmBuffer.readInt16LE(i);
    const abs = sample < 0 ? -sample : sample;
    if (abs > peak) peak = abs;
  }

  const ceiling = 30000; // 32767'den biraz altı, headroom
  if (peak > ceiling) {
    const scale = ceiling / peak;
    for (let i = 0; i < pcmBuffer.length - 1; i += 2) {
      const sample = pcmBuffer.readInt16LE(i);
      pcmBuffer.writeInt16LE(Math.round(sample * scale), i);
    }
  }

  const dataSize = pcmBuffer.length;
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + dataSize, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(numChannels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(bitsPerSample, 34);
  header.write('data', 36);
  header.writeUInt32LE(dataSize, 40);

  const wavBuffer = Buffer.concat([header, pcmBuffer]);
  return wavBuffer.toString('base64');
}

/**
 * Kullanıcıya sunulacak kısa, okunabilir bir recap üretir.
 */
async function generateRecap(chapters, language = 'tr') {
  const lang = language === 'en' ? 'English' : 'Türkçe';
  let prompt = `Aşağıdaki hikaye bölümlerinin kısa ve akıcı bir "şimdiye kadar ne oldu" özetini yaz. ${lang} yaz. Özet 3-5 paragraf olsun, sade ve okunabilir olsun. Sadece özet metnini yaz.\n\n`;

  for (const ch of chapters) {
    prompt += `Bölüm ${ch.chapterNumber}: ${ch.content}\n\n`;
  }

  const response = await ai.models.generateContent({
    model: MODEL,
    contents: prompt,
    config: { temperature: 0.3, topP: 0.9 },
  });

  return response.text;
}

/**
 * Streaming: Yeni hikaye başlatır, chunk'ları yield eder.
 */
async function* startNewStoryStream(genre, { mood, characters, language } = {}) {
  const systemInstruction = buildSystemInstruction(genre, '', { mood, characters, language });

  const openings = [
    'Hikayeyi tamamen beklenmedik bir olayla başlat. Benzersiz isimli bir ana karakter oluştur, dünyayı tanıt ve ilk seçenekleri sun.',
    'Sıra dışı bir sahneyle hikayeyi aç. Farklı ve yaratıcı isimli bir karakter yarat, atmosferi kur ve seçenekleri sun.',
    'Merak uyandıran gizemli bir başlangıç yaz. Nadir bir isimle ana karakteri tanıt, ortamı detaylı anlat ve ilk seçenekleri ver.',
    'Dramatik ve etkileyici bir açılış sahnesi yaz. Özgün isimli karakterleri hayata getir ve okuyucuyu hikayeye çek.',
    'Aksiyonun ortasında başla. Eşsiz isimli bir kahramanı tanıt, olayları hızlı bir tempoda başlat ve seçenekleri sun.',
  ];
  const prompt = openings[Math.floor(Math.random() * openings.length)];

  const response = await ai.models.generateContentStream({
    model: MODEL,
    contents: prompt,
    config: {
      systemInstruction,
      responseMimeType: 'application/json',
      temperature: 0.9,
      topP: 0.95,
    },
  });

  for await (const chunk of response) {
    if (chunk.text) {
      yield chunk.text;
    }
  }
}

/**
 * Streaming: Hikayeyi devam ettirir, chunk'ları yield eder.
 */
async function* continueStoryStream(genre, summary, recentChapters, choiceText, imageBase64 = null, { mood, characters, language, memoryContext, chapterCount } = {}) {
  const systemInstruction = buildSystemInstruction(genre, summary, { mood, characters, language, memoryContext });

  let contextMessage = '';
  if (recentChapters.length > 0) {
    contextMessage = '## SON BÖLÜMLER\n';
    for (const ch of recentChapters) {
      contextMessage += `\n### Bölüm ${ch.chapterNumber}\n${ch.content}\nSeçilen: ${ch.selectedChoiceText || 'bilinmiyor'}\n`;
    }
    contextMessage += '\n---\n\n';
  }

  contextMessage += `Kullanıcı şu seçimi yaptı: "${choiceText}"\n\nBu seçime göre hikayeyi devam ettir.`;

  const parts = [];

  if (imageBase64) {
    parts.push({
      inlineData: {
        mimeType: 'image/jpeg',
        data: imageBase64,
      },
    });
    contextMessage += '\n\nKullanıcı ayrıca bir fotoğraf paylaştı. Bu fotoğrafı inceleyip hikayeye ve seçeneklere ilham kaynağı olarak kullan. Fotoğraftaki unsurları hikayeye doğal bir şekilde entegre et.';
  }

  parts.push({ text: contextMessage });

  const response = await ai.models.generateContentStream({
    model: MODEL,
    contents: [{ role: 'user', parts }],
    config: {
      systemInstruction,
      responseMimeType: 'application/json',
      temperature: 0.85,
      topP: 0.95,
      maxOutputTokens: 8192,
      ...(chapterCount >= 10 && { thinkingConfig: { thinkingBudget: 2048 } }),
    },
  });

  for await (const chunk of response) {
    if (chunk.text) {
      yield chunk.text;
    }
  }
}

module.exports = {
  startNewStory,
  continueStory,
  startNewStoryStream,
  continueStoryStream,
  generateSummary,
  generateRecap,
  shouldGenerateSummary,
  shouldResetChain,
  generateSpeech,
  pcmToWavBase64,
  SUMMARY_INTERVAL,
  CHAIN_RESET_INTERVAL,
};
