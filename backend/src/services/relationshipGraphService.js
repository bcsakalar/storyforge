const prisma = require('../config/database');
const ai = require('../config/gemini');

const MODEL = 'gemini-3-flash-preview';

/**
 * Relationship Graph Service — Karakter İlişki Grafiği
 *
 * Her bölümde karakter ilişkilerini çıkarır ve StoryEntity.relationships alanında tutar.
 * İlişki türleri: ally, enemy, lover, family, mentor, rival, stranger
 * İlişki değişimlerini izler: "düşman → dost" gibi arc'lar
 */

const RELATIONSHIP_EXTRACTION_TOOLS = [
  {
    functionDeclarations: [
      {
        name: 'extractRelationshipsAndStatus',
        description: 'Hikaye bölümünden karakter ilişkilerini ve durum değişikliklerini çıkarır.',
        parameters: {
          type: 'OBJECT',
          properties: {
            relationships: {
              type: 'ARRAY',
              description: 'Bölümde ortaya çıkan veya değişen ilişkiler',
              items: {
                type: 'OBJECT',
                properties: {
                  sourceName: { type: 'STRING', description: 'Kaynak karakter adı' },
                  targetName: { type: 'STRING', description: 'Hedef karakter/entity adı' },
                  type: {
                    type: 'STRING',
                    description: 'İlişki türü',
                    enum: ['ally', 'enemy', 'lover', 'family', 'mentor', 'rival', 'stranger', 'servant', 'master'],
                  },
                  description: { type: 'STRING', description: 'İlişkinin kısa açıklaması' },
                },
                required: ['sourceName', 'targetName', 'type'],
              },
            },
            statusChanges: {
              type: 'ARRAY',
              description: 'Bölümde gerçekleşen entity durum değişiklikleri',
              items: {
                type: 'OBJECT',
                properties: {
                  entityName: { type: 'STRING', description: 'Entity adı' },
                  entityType: { type: 'STRING', description: 'character, location, item' },
                  newStatus: {
                    type: 'STRING',
                    description: 'Yeni durum',
                    enum: ['active', 'dead', 'missing', 'transformed', 'inactive', 'destroyed'],
                  },
                  reason: { type: 'STRING', description: 'Durum değişikliğinin nedeni' },
                },
                required: ['entityName', 'newStatus', 'reason'],
              },
            },
          },
          required: ['relationships', 'statusChanges'],
        },
      },
    ],
  },
];

/**
 * Bölümden ilişki ve durum değişikliklerini çıkarır.
 */
async function extractRelationshipsFromChapter(chapterText, existingEntities) {
  let entityContext = '';
  if (existingEntities && existingEntities.length > 0) {
    entityContext = '\n\nMEVCUT ENTITY\'LER:\n';
    for (const e of existingEntities) {
      entityContext += `- [${e.type}] ${e.name} (durum: ${e.status || 'active'})\n`;
    }
  }

  const response = await ai.models.generateContent({
    model: MODEL,
    contents: `Aşağıdaki hikaye bölümünü analiz et. Karakter ilişkilerini ve entity durum değişikliklerini çıkar.${entityContext}\n\nBÖLÜM:\n${chapterText}`,
    config: {
      tools: RELATIONSHIP_EXTRACTION_TOOLS,
      toolConfig: { functionCallingConfig: { mode: 'ANY' } },
      temperature: 0.1,
      maxOutputTokens: 2048,
    },
  });

  const part = response.candidates?.[0]?.content?.parts?.[0];
  if (part?.functionCall?.name === 'extractRelationshipsAndStatus') {
    return part.functionCall.args;
  }

  return { relationships: [], statusChanges: [] };
}

/**
 * Çıkarılan ilişkileri mevcut entity'lere uygular.
 */
async function applyRelationships(storyId, chapterNum, relationships) {
  for (const rel of relationships) {
    // Kaynak entity'yi bul
    const sourceEntity = await prisma.storyEntity.findFirst({
      where: { storyId, name: rel.sourceName },
    });

    if (!sourceEntity) continue;

    // Mevcut ilişkileri al
    const currentRelationships = Array.isArray(sourceEntity.relationships) ? sourceEntity.relationships : [];

    // İlişkiyi güncelle veya ekle
    const existingIndex = currentRelationships.findIndex(
      (r) => r.targetName === rel.targetName,
    );

    const relEntry = {
      targetName: rel.targetName,
      type: rel.type,
      since: existingIndex >= 0 ? currentRelationships[existingIndex].since : chapterNum,
      description: rel.description || '',
      lastUpdated: chapterNum,
    };

    if (existingIndex >= 0) {
      currentRelationships[existingIndex] = relEntry;
    } else {
      currentRelationships.push(relEntry);
    }

    await prisma.storyEntity.update({
      where: { id: sourceEntity.id },
      data: { relationships: currentRelationships },
    });
  }
}

/**
 * Durum değişikliklerini entity'lere uygular.
 */
async function applyStatusChanges(storyId, chapterNum, statusChanges) {
  for (const change of statusChanges) {
    const entity = await prisma.storyEntity.findFirst({
      where: { storyId, name: change.entityName },
    });

    if (!entity) continue;
    if (entity.status === change.newStatus) continue; // Değişiklik yok

    // Status history'ye ekle
    const history = Array.isArray(entity.statusHistory) ? entity.statusHistory : [];
    history.push({
      chapter: chapterNum,
      from: entity.status,
      to: change.newStatus,
      reason: change.reason,
    });

    await prisma.storyEntity.update({
      where: { id: entity.id },
      data: {
        status: change.newStatus,
        statusHistory: history,
      },
    });

    console.log(`📊 Entity "${entity.name}" durumu: ${entity.status} → ${change.newStatus} (${change.reason})`);
  }
}

/**
 * Bir hikayenin karakter ilişki grafiğini döndürür (API için).
 */
async function getRelationshipGraph(storyId) {
  const entities = await prisma.storyEntity.findMany({
    where: { storyId, type: 'character' },
    select: {
      name: true,
      description: true,
      status: true,
      relationships: true,
      importance: true,
    },
    orderBy: { importance: 'desc' },
  });

  return entities.map((e) => ({
    name: e.name,
    description: e.description,
    status: e.status,
    importance: e.importance,
    relationships: Array.isArray(e.relationships) ? e.relationships : [],
  }));
}

/**
 * Hafıza kontekstinde ilişki grafiğini formatlar.
 */
function buildRelationshipContext(entities) {
  if (!entities || entities.length === 0) return '';

  const characters = entities.filter((e) => e.type === 'character' && e.relationships?.length > 0);
  if (characters.length === 0) return '';

  let context = '\n## KARAKTER İLİŞKİLERİ\n';
  for (const char of characters) {
    const rels = Array.isArray(char.relationships) ? char.relationships : [];
    for (const rel of rels) {
      context += `- ${char.name} → ${rel.targetName}: ${rel.type} (bölüm ${rel.since}'den beri)`;
      if (rel.description) context += ` — ${rel.description}`;
      context += '\n';
    }
  }

  return context;
}

module.exports = {
  extractRelationshipsFromChapter,
  applyRelationships,
  applyStatusChanges,
  getRelationshipGraph,
  buildRelationshipContext,
};
