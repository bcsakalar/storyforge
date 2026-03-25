const { getRedisClient } = require('../config/redis');

const TTL = {
  STORY_CONTEXT: 3600, // 1 saat
  STORY_ENTITIES: 1800, // 30 dk
  STORY_RELATIONSHIPS: 1800, // 30 dk
  STORY_LORE: 3600, // 1 saat
  STORY_SUMMARY: 7200, // 2 saat
  TOKEN_USAGE: 2592000, // 30 gün
};

/**
 * Hikaye bağlamını Redis'e cache'le.
 */
async function cacheStoryContext(storyId, context) {
  try {
    const redis = getRedisClient();
    const key = `story:context:${storyId}`;
    await redis.set(key, JSON.stringify(context), 'EX', TTL.STORY_CONTEXT);
  } catch (err) {
    console.error('Cache set error:', err.message);
  }
}

/**
 * Cache'lenmiş hikaye bağlamını getir.
 * @returns {Object|null}
 */
async function getCachedStoryContext(storyId) {
  try {
    const redis = getRedisClient();
    const key = `story:context:${storyId}`;
    const data = await redis.get(key);
    return data ? JSON.parse(data) : null;
  } catch (err) {
    console.error('Cache get error:', err.message);
    return null;
  }
}

/**
 * Hikaye bağlam cache'ini ve ilgili tüm alt cache'leri temizle.
 */
async function invalidateStoryContext(storyId) {
  try {
    const redis = getRedisClient();
    await redis.del(
      `story:context:${storyId}`,
      `story:entities:${storyId}`,
      `story:relationships:${storyId}`,
      `story:lore:${storyId}`,
      `story:summary:${storyId}`,
    );
  } catch (err) {
    console.error('Cache invalidate error:', err.message);
  }
}

/**
 * Entity listesini cache'le.
 */
async function cacheEntities(storyId, entities) {
  try {
    const redis = getRedisClient();
    await redis.set(`story:entities:${storyId}`, JSON.stringify(entities), 'EX', TTL.STORY_ENTITIES);
  } catch (err) {
    console.error('Entity cache error:', err.message);
  }
}

/**
 * Cache'lenmiş entity listesini getir.
 */
async function getCachedEntities(storyId) {
  try {
    const redis = getRedisClient();
    const data = await redis.get(`story:entities:${storyId}`);
    return data ? JSON.parse(data) : null;
  } catch (err) {
    return null;
  }
}

/**
 * Lore bilgisini cache'le.
 */
async function cacheLore(storyId, lore) {
  try {
    const redis = getRedisClient();
    await redis.set(`story:lore:${storyId}`, JSON.stringify(lore), 'EX', TTL.STORY_LORE);
  } catch (err) {
    console.error('Lore cache error:', err.message);
  }
}

/**
 * Cache'lenmiş lore bilgisini getir.
 */
async function getCachedLore(storyId) {
  try {
    const redis = getRedisClient();
    const data = await redis.get(`story:lore:${storyId}`);
    return data ? JSON.parse(data) : null;
  } catch (err) {
    return null;
  }
}

/**
 * Latest summary'yi cache'le.
 */
async function cacheLatestSummary(storyId, summary) {
  try {
    const redis = getRedisClient();
    await redis.set(`story:summary:${storyId}`, summary, 'EX', TTL.STORY_SUMMARY);
  } catch (err) {
    console.error('Summary cache error:', err.message);
  }
}

/**
 * Günlük token kullanımını Redis'te takip et.
 */
async function trackDailyTokens(userId, inputTokens, outputTokens) {
  try {
    const redis = getRedisClient();
    const today = new Date().toISOString().split('T')[0];
    const key = `tokens:${userId}:${today}`;

    await redis.hincrby(key, 'input', inputTokens);
    await redis.hincrby(key, 'output', outputTokens);
    await redis.expire(key, TTL.TOKEN_USAGE);
  } catch (err) {
    console.error('Token tracking error:', err.message);
  }
}

/**
 * Kullanıcının günlük token kullanımını getir.
 */
async function getDailyTokenUsage(userId) {
  try {
    const redis = getRedisClient();
    const today = new Date().toISOString().split('T')[0];
    const key = `tokens:${userId}:${today}`;
    const data = await redis.hgetall(key);
    return {
      input: parseInt(data.input || '0', 10),
      output: parseInt(data.output || '0', 10),
    };
  } catch (err) {
    console.error('Token usage get error:', err.message);
    return { input: 0, output: 0 };
  }
}

module.exports = {
  cacheStoryContext,
  getCachedStoryContext,
  invalidateStoryContext,
  cacheEntities,
  getCachedEntities,
  cacheLore,
  getCachedLore,
  cacheLatestSummary,
  trackDailyTokens,
  getDailyTokenUsage,
};
