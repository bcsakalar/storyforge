const prisma = require('../config/database');
const ai = require('../config/gemini');
const relationshipGraphService = require('./relationshipGraphService');

const EMBEDDING_MODEL = 'gemini-embedding-2-preview';
const EMBEDDING_DIMENSIONS = 768;

// Function Calling declarations for entity extraction
const ENTITY_EXTRACTION_TOOLS = [
  {
    functionDeclarations: [
      {
        name: 'extractStoryEntities',
        description: 'Hikaye bölümünden karakterleri, mekanları, nesneleri ve olayları çıkarır.',
        parameters: {
          type: 'OBJECT',
          properties: {
            characters: {
              type: 'ARRAY',
              description: 'Bölümde geçen karakterler',
              items: {
                type: 'OBJECT',
                properties: {
                  name: { type: 'STRING', description: 'Karakter adı' },
                  description: { type: 'STRING', description: 'Kısa açıklama (1-2 cümle)' },
                  attributes: {
                    type: 'OBJECT',
                    description: 'Bilinen özellikler (meslek, ırk, güç vb.)',
                    properties: {},
                    additionalProperties: { type: 'STRING' },
                  },
                  importance: { type: 'NUMBER', description: '1-10 arası önem puanı' },
                },
                required: ['name', 'description', 'importance'],
              },
            },
            locations: {
              type: 'ARRAY',
              description: 'Bölümde geçen mekanlar',
              items: {
                type: 'OBJECT',
                properties: {
                  name: { type: 'STRING', description: 'Mekan adı' },
                  description: { type: 'STRING', description: 'Kısa açıklama' },
                  importance: { type: 'NUMBER', description: '1-10 arası önem puanı' },
                },
                required: ['name', 'description', 'importance'],
              },
            },
            items: {
              type: 'ARRAY',
              description: 'Önemli nesneler (silahlar, tılsımlar, eserler vb.)',
              items: {
                type: 'OBJECT',
                properties: {
                  name: { type: 'STRING', description: 'Nesne adı' },
                  description: { type: 'STRING', description: 'Kısa açıklama' },
                  importance: { type: 'NUMBER', description: '1-10 arası önem puanı' },
                },
                required: ['name', 'description', 'importance'],
              },
            },
            events: {
              type: 'ARRAY',
              description: 'Bölümdeki önemli olaylar',
              items: {
                type: 'OBJECT',
                properties: {
                  description: { type: 'STRING', description: 'Olay açıklaması (1-2 cümle)' },
                  impact: {
                    type: 'STRING',
                    description: 'Olayın etkisi',
                    enum: ['major', 'minor', 'twist'],
                  },
                  involvedEntities: {
                    type: 'ARRAY',
                    description: 'Olaya dahil olan karakter/mekan/nesne adları',
                    items: { type: 'STRING' },
                  },
                },
                required: ['description', 'impact'],
              },
            },
          },
          required: ['characters', 'locations', 'items', 'events'],
        },
      },
    ],
  },
];

/**
 * Metin için embedding vektörü üretir.
 * @param {string} text - Embedding üretilecek metin
 * @param {string} taskType - RETRIEVAL_DOCUMENT | RETRIEVAL_QUERY | SEMANTIC_SIMILARITY
 * @returns {Promise<number[]>} - 768 boyutlu vektör
 */
async function getEmbedding(text, taskType = 'RETRIEVAL_DOCUMENT') {
  // Gemini embedding API'de max 8192 token - uzun metinleri kırp
  const truncated = text.length > 25000 ? text.substring(0, 25000) : text;

  const response = await ai.models.embedContent({
    model: EMBEDDING_MODEL,
    contents: truncated,
    config: {
      taskType,
      outputDimensionality: EMBEDDING_DIMENSIONS,
    },
  });

  return response.embeddings[0].values;
}

/**
 * Function Calling ile bölümden entity ve olayları çıkarır.
 * @param {string} chapterText - Bölüm metni
 * @returns {Promise<Object>} - Çıkarılan entities ve events
 */
async function extractEntitiesFromText(chapterText) {
  const response = await ai.models.generateContent({
    model: 'gemini-3-flash-preview',
    contents: `Aşağıdaki hikaye bölümünü analiz et ve tüm karakterleri, mekanları, önemli nesneleri ve olayları çıkar.\n\nBÖLÜM:\n${chapterText}`,
    config: {
      tools: ENTITY_EXTRACTION_TOOLS,
      toolConfig: { functionCallingConfig: { mode: 'ANY' } },
      temperature: 0.1,
    },
  });

  // Function call yanıtından veriyi çıkar
  const part = response.candidates?.[0]?.content?.parts?.[0];
  if (part?.functionCall?.name === 'extractStoryEntities') {
    return part.functionCall.args;
  }

  // Fallback: boş sonuç
  return { characters: [], locations: [], items: [], events: [] };
}

/**
 * Entity'yi veritabanına upsert eder (varsa güncelle, yoksa ekle).
 */
async function upsertEntity(storyId, type, name, description, attributes, importance, chapterNum) {
  const existing = await prisma.storyEntity.findUnique({
    where: { storyId_type_name: { storyId, type, name } },
  });

  if (existing) {
    // Güncelle: description'ı birleştir, importance'ı max al
    const updatedDesc = existing.description.includes(description)
      ? existing.description
      : `${existing.description} ${description}`.trim();
    const mergedAttrs = { ...(existing.attributes || {}), ...(attributes || {}) };

    await prisma.storyEntity.update({
      where: { id: existing.id },
      data: {
        description: updatedDesc.substring(0, 2000),
        attributes: mergedAttrs,
        importance: Math.max(existing.importance, importance),
        lastSeenChapter: chapterNum,
      },
    });
  } else {
    // Embedding üret ve yeni entity oluştur
    const embeddingText = `${type}: ${name}. ${description}`;
    const embedding = await getEmbedding(embeddingText);

    await prisma.$executeRaw`
      INSERT INTO story_entities ("id", "storyId", "type", "name", "description", "attributes", "embedding", "firstSeenChapter", "lastSeenChapter", "importance", "createdAt", "updatedAt")
      VALUES (
        gen_random_uuid(),
        ${storyId},
        ${type},
        ${name},
        ${description.substring(0, 2000)},
        ${JSON.stringify(attributes || {})}::jsonb,
        ${embedding}::vector,
        ${chapterNum},
        ${chapterNum},
        ${importance},
        NOW(),
        NOW()
      )
    `;
  }
}

/**
 * Event'i veritabanına kaydeder.
 */
async function saveEvent(storyId, chapterNum, description, impact, involvedEntities) {
  const embedding = await getEmbedding(description);

  await prisma.$executeRaw`
    INSERT INTO story_events ("id", "storyId", "chapterNumber", "description", "impact", "entities", "embedding", "createdAt")
    VALUES (
      gen_random_uuid(),
      ${storyId},
      ${chapterNum},
      ${description.substring(0, 2000)},
      ${impact},
      ${JSON.stringify(involvedEntities || [])}::jsonb,
      ${embedding}::vector,
      NOW()
    )
  `;
}

/**
 * World state'i günceller (bölüm bazlı hikaye durumu).
 */
async function updateWorldState(storyId, chapterNum, state) {
  await prisma.storyWorldState.upsert({
    where: { storyId_chapterNumber: { storyId, chapterNumber: chapterNum } },
    update: { state },
    create: { storyId, chapterNumber: chapterNum, state },
  });
}

/**
 * Bir bölümü analiz edip tüm entity/event/world state bilgilerini çıkarır ve kaydeder.
 * Arka planda (async) çalıştırılmak üzere tasarlanmıştır.
 */
async function processChapter(storyId, chapterNum, chapterText, chapterSummary) {
  try {
    // 1. Function Calling ile entity extraction
    const extracted = await extractEntitiesFromText(chapterText);

    // 2. Karakterleri kaydet
    for (const char of extracted.characters || []) {
      await upsertEntity(storyId, 'character', char.name, char.description, char.attributes, char.importance, chapterNum);
    }

    // 3. Mekanları kaydet
    for (const loc of extracted.locations || []) {
      await upsertEntity(storyId, 'location', loc.name, loc.description, null, loc.importance, chapterNum);
    }

    // 4. Nesneleri kaydet
    for (const item of extracted.items || []) {
      await upsertEntity(storyId, 'item', item.name, item.description, null, item.importance, chapterNum);
    }

    // 5. Olayları kaydet
    for (const event of extracted.events || []) {
      await saveEvent(storyId, chapterNum, event.description, event.impact, event.involvedEntities);
    }

    // 6. İlişki ve durum değişikliklerini çıkar ve uygula
    try {
      const existingEntities = await prisma.storyEntity.findMany({
        where: { storyId },
        select: { type: true, name: true, status: true },
      });

      const relData = await relationshipGraphService.extractRelationshipsFromChapter(chapterText, existingEntities);

      if (relData.relationships && relData.relationships.length > 0) {
        await relationshipGraphService.applyRelationships(storyId, chapterNum, relData.relationships);
      }
      if (relData.statusChanges && relData.statusChanges.length > 0) {
        await relationshipGraphService.applyStatusChanges(storyId, chapterNum, relData.statusChanges);
      }
    } catch (relErr) {
      console.error('İlişki çıkarma hatası:', relErr.message);
    }

    // 7. Eski olayların relevanceDecay'ini güncelle (0.95 çarpanı)
    await decayEventRelevance(storyId);

    // 8. World state güncelle
    const entities = await prisma.storyEntity.findMany({
      where: { storyId },
      select: { type: true, name: true, importance: true, status: true },
      orderBy: { importance: 'desc' },
      take: 20,
    });

    const worldState = {
      chapterNumber: chapterNum,
      summary: chapterSummary || '',
      activeCharacters: entities.filter((e) => e.type === 'character' && e.status === 'active').map((e) => e.name),
      deadCharacters: entities.filter((e) => e.type === 'character' && e.status === 'dead').map((e) => e.name),
      knownLocations: entities.filter((e) => e.type === 'location' && e.status === 'active').map((e) => e.name),
      importantItems: entities.filter((e) => e.type === 'item' && e.status === 'active').map((e) => e.name),
    };

    await updateWorldState(storyId, chapterNum, worldState);

    console.log(`📚 Bölüm ${chapterNum} hafıza işlendi: ${(extracted.characters || []).length} karakter, ${(extracted.locations || []).length} mekan, ${(extracted.events || []).length} olay`);
  } catch (err) {
    console.error(`Hafıza işleme hatası (bölüm ${chapterNum}):`, err.message);
  }
}

/**
 * Kullanıcının seçimine göre ilgili entity'leri ve olayları bulur (RAG).
 * pgvector cosine similarity + relevanceDecay + importance weight kullanır.
 * @param {string} storyId
 * @param {string} choiceText - Kullanıcının seçtiği seçenek metni
 * @param {number} topK - Kaç sonuç döndür
 * @returns {Promise<Object>} - İlgili entities ve events
 */
async function getRelevantContext(storyId, choiceText, topK = 5) {
  // 1. Seçenek metni için query embedding üret
  const queryEmbedding = await getEmbedding(choiceText, 'RETRIEVAL_QUERY');

  // 2. En alakalı entity'leri bul (cosine similarity) — durumları dahil
  const relevantEntities = await prisma.$queryRaw`
    SELECT id, type, name, description, attributes, importance, status, relationships,
           1 - (embedding <=> ${queryEmbedding}::vector) as similarity
    FROM story_entities
    WHERE "storyId" = ${storyId}
    ORDER BY embedding <=> ${queryEmbedding}::vector
    LIMIT ${topK}
  `;

  // 3. En alakalı olayları bul — relevanceDecay dahil
  const relevantEvents = await prisma.$queryRaw`
    SELECT id, "chapterNumber", description, impact, entities, relevance_decay, is_resolved,
           (1 - (embedding <=> ${queryEmbedding}::vector)) * relevance_decay as weighted_similarity
    FROM story_events
    WHERE "storyId" = ${storyId}
      AND is_resolved = false
    ORDER BY weighted_similarity DESC
    LIMIT ${topK}
  `;

  // 4. Son world state'i al
  const latestWorldState = await prisma.storyWorldState.findFirst({
    where: { storyId },
    orderBy: { chapterNumber: 'desc' },
  });

  return {
    entities: relevantEntities,
    events: relevantEvents,
    worldState: latestWorldState?.state || null,
  };
}

/**
 * RAG sonuçlarından geliştirilmiş prompt konteksti oluşturur.
 * Temporal entity durumları, ilişkiler ve lore bilgilerini içerir.
 * @param {Object} ragContext - getRelevantContext() sonucu
 * @returns {string} - Sisteme eklenecek bağlam metni
 */
function buildMemoryContext(ragContext) {
  if (!ragContext) return '';

  let context = '';

  // Entity konteksti — durum ve ilişki bilgileri dahil
  if (ragContext.entities?.length > 0) {
    context += '\n## HAFIZA: BİLİNEN VARLIKLAR\n';
    for (const entity of ragContext.entities) {
      const sim = Number(entity.similarity).toFixed(2);
      const status = entity.status || 'active';
      const statusTag = status !== 'active' ? ` ⚠️ DURUM: ${status.toUpperCase()}` : '';
      context += `- [${entity.type}] **${entity.name}**: ${entity.description} (alakalılık: ${sim})${statusTag}\n`;
      if (entity.attributes && Object.keys(entity.attributes).length > 0) {
        context += `  Özellikler: ${JSON.stringify(entity.attributes)}\n`;
      }
      // İlişkileri göster
      const rels = Array.isArray(entity.relationships) ? entity.relationships : [];
      if (rels.length > 0) {
        for (const rel of rels) {
          context += `  → ${rel.targetName}: ${rel.type} (bölüm ${rel.since}'den beri)\n`;
        }
      }
    }

    // ÖNEMLİ kural: Ölü/kayıp entity uyarısı
    const deadOrMissing = ragContext.entities.filter((e) => e.status === 'dead' || e.status === 'missing' || e.status === 'destroyed');
    if (deadOrMissing.length > 0) {
      context += '\n⚠️ TEMPORAL KURAL: Aşağıdaki entity\'ler artık aktif DEĞİL — konuşamaz, hareket edemez, kullanılamaz:\n';
      for (const e of deadOrMissing) {
        context += `  - ${e.name} (${e.status})\n`;
      }
    }
  }

  // Event konteksti
  if (ragContext.events?.length > 0) {
    context += '\n## HAFIZA: GEÇMİŞ OLAYLAR\n';
    for (const event of ragContext.events) {
      const sim = Number(event.weighted_similarity || event.similarity || 0).toFixed(2);
      context += `- [Bölüm ${event.chapterNumber || event.chapterNum}, ${event.impact}] ${event.description} (alakalılık: ${sim})\n`;
    }
  }

  // Lore konteksti
  if (ragContext.lore?.length > 0) {
    context += '\n## HAFIZA: EVREN KURALLARI (LORE)\n';
    for (const entry of ragContext.lore) {
      context += `- [${entry.category}] **${entry.title}**: ${entry.content}\n`;
    }
    context += 'ÖNEMLİ: Yukarıdaki evren kurallarıyla çelişme. Bu kurallar kesinleşmiş (canon) bilgilerdir.\n';
  }

  // World state konteksti
  if (ragContext.worldState) {
    const ws = ragContext.worldState;
    context += '\n## HAFIZA: GÜNCEL DÜNYA DURUMU\n';
    if (ws.activeCharacters?.length > 0) context += `Aktif Karakterler: ${ws.activeCharacters.join(', ')}\n`;
    if (ws.deadCharacters?.length > 0) context += `Ölü/Devre Dışı Karakterler: ${ws.deadCharacters.join(', ')}\n`;
    if (ws.knownLocations?.length > 0) context += `Bilinen Mekanlar: ${ws.knownLocations.join(', ')}\n`;
    if (ws.importantItems?.length > 0) context += `Önemli Nesneler: ${ws.importantItems.join(', ')}\n`;
  }

  if (context) {
    context += '\nÖNEMLİ: Yukarıdaki hafıza bilgilerini kullanarak hikayeyi tutarlı devam ettir. Bu bilgilerle çelişme. Ölü karakterleri konuşturma.\n';
  }

  return context;
}

/**
 * Token kullanımını kaydeder.
 */
async function trackTokenUsage(userId, storyId, model, inputTokens, outputTokens, operation) {
  try {
    await prisma.tokenUsage.create({
      data: { userId, storyId, model, inputTokens, outputTokens, operation },
    });
  } catch (err) {
    console.error('Token usage tracking error:', err.message);
  }
}

/**
 * Tüm çözülmemiş olayların relevanceDecay'ini 0.95 ile çarpar.
 * Her yeni bölümde çağrılır — eski olaylar giderek daha az önemli hale gelir.
 */
async function decayEventRelevance(storyId) {
  try {
    await prisma.$executeRaw`
      UPDATE story_events
      SET relevance_decay = relevance_decay * 0.95
      WHERE "storyId" = ${storyId}
        AND is_resolved = false
        AND relevance_decay > 0.1
    `;
  } catch (err) {
    console.error('Event decay hatası:', err.message);
  }
}

/**
 * Lore entry kaydeder veya günceller.
 */
async function upsertLore(storyId, category, title, content) {
  const existing = await prisma.storyLore.findFirst({
    where: { storyId, category, title },
  });

  const embedding = await getEmbedding(`${category}: ${title}. ${content}`);

  if (existing) {
    await prisma.$executeRaw`
      UPDATE story_lore
      SET content = ${content.substring(0, 5000)},
          embedding = ${embedding}::vector,
          updated_at = NOW()
      WHERE id = ${existing.id}
    `;
  } else {
    await prisma.$executeRaw`
      INSERT INTO story_lore (story_id, category, title, content, embedding, is_canon, created_at, updated_at)
      VALUES (${storyId}, ${category}, ${title}, ${content.substring(0, 5000)}, ${embedding}::vector, true, NOW(), NOW())
    `;
  }
}

/**
 * Bir hikayenin tüm lore entry'lerini döndürür.
 */
async function getLore(storyId) {
  return prisma.storyLore.findMany({
    where: { storyId, isCanon: true },
    orderBy: { category: 'asc' },
  });
}

/**
 * İlgili lore entry'lerini vektör aramasıyla bulur.
 */
async function getRelevantLore(storyId, queryText, topK = 5) {
  const queryEmbedding = await getEmbedding(queryText, 'RETRIEVAL_QUERY');

  return prisma.$queryRaw`
    SELECT id, category, title, content,
           1 - (embedding <=> ${queryEmbedding}::vector) as similarity
    FROM story_lore
    WHERE story_id = ${storyId} AND is_canon = true
    ORDER BY embedding <=> ${queryEmbedding}::vector
    LIMIT ${topK}
  `;
}

/**
 * getRelevantContext'in lore bilgisini de dahil eden genişletilmiş versiyonu.
 */
async function getEnrichedContext(storyId, choiceText, topK = 5) {
  const baseContext = await getRelevantContext(storyId, choiceText, topK);

  // Lore bilgisini de ekle
  let lore = [];
  try {
    lore = await getRelevantLore(storyId, choiceText, 3);
  } catch {
    // Lore tablosu henüz yoksa veya boşsa atlama
  }

  return {
    ...baseContext,
    lore,
  };
}

module.exports = {
  getEmbedding,
  extractEntitiesFromText,
  processChapter,
  getRelevantContext,
  getEnrichedContext,
  buildMemoryContext,
  trackTokenUsage,
  upsertEntity,
  saveEvent,
  updateWorldState,
  decayEventRelevance,
  upsertLore,
  getLore,
  getRelevantLore,
  EMBEDDING_MODEL,
  EMBEDDING_DIMENSIONS,
};
