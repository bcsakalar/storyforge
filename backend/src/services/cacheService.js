const { getRedisClient } = require('../config/redis');

const TTL = {
  STORY_CONTEXT: 3600, // 1 saat
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
 * Hikaye bağlam cache'ini temizle (yeni bölüm eklendiğinde).
 */
async function invalidateStoryContext(storyId) {
  try {
    const redis = getRedisClient();
    await redis.del(`story:context:${storyId}`);
  } catch (err) {
    console.error('Cache invalidate error:', err.message);
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
  trackDailyTokens,
  getDailyTokenUsage,
};
