const Redis = require('ioredis');

let redis = null;

function getRedisClient() {
  if (redis) return redis;

  const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

  redis = new Redis(redisUrl, {
    maxRetriesPerRequest: 3,
    retryStrategy(times) {
      if (times > 5) return null; // Stop retrying after 5 attempts
      return Math.min(times * 200, 2000);
    },
    lazyConnect: true,
  });

  redis.on('connect', () => {
    console.log('📦 Redis connected');
  });

  redis.on('error', (err) => {
    console.error('Redis connection error:', err.message);
  });

  return redis;
}

/**
 * Redis'e bağlan (opsiyonel, lazy connect kullanıldığı için
 * ilk komutta otomatik bağlanır).
 */
async function connectRedis() {
  const client = getRedisClient();
  try {
    await client.connect();
  } catch (err) {
    // Already connected or connecting
    if (!err.message.includes('already')) {
      console.error('Redis connect error:', err.message);
    }
  }
  return client;
}

/**
 * Redis bağlantısını kapat (graceful shutdown).
 */
async function disconnectRedis() {
  if (redis) {
    await redis.quit();
    redis = null;
  }
}

module.exports = { getRedisClient, connectRedis, disconnectRedis };
