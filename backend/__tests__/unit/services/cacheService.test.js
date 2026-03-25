const mockRedis = require('../../helpers/mockRedis');

jest.mock('../../../src/config/redis', () => ({
  getRedisClient: () => mockRedis,
}));

const cacheService = require('../../../src/services/cacheService');

describe('CacheService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('cacheStoryContext / getCachedStoryContext', () => {
    it('should cache story context with correct TTL', async () => {
      const context = { summary: 'A test story', genre: 'fantastik' };
      await cacheService.cacheStoryContext(42, context);

      expect(mockRedis.set).toHaveBeenCalledWith(
        'story:context:42',
        JSON.stringify(context),
        'EX',
        3600,
      );
    });

    it('should return cached story context', async () => {
      const context = { summary: 'Cached story' };
      mockRedis.get.mockResolvedValue(JSON.stringify(context));

      const result = await cacheService.getCachedStoryContext(42);
      expect(result).toEqual(context);
      expect(mockRedis.get).toHaveBeenCalledWith('story:context:42');
    });

    it('should return null when no cache exists', async () => {
      mockRedis.get.mockResolvedValue(null);
      const result = await cacheService.getCachedStoryContext(99);
      expect(result).toBeNull();
    });

    it('should return null on redis error', async () => {
      mockRedis.get.mockRejectedValue(new Error('Connection refused'));
      const result = await cacheService.getCachedStoryContext(42);
      expect(result).toBeNull();
    });
  });

  describe('cacheEntities / getCachedEntities', () => {
    it('should cache entities with 30min TTL', async () => {
      const entities = [{ name: 'Hero', type: 'character' }];
      await cacheService.cacheEntities(1, entities);

      expect(mockRedis.set).toHaveBeenCalledWith(
        'story:entities:1',
        JSON.stringify(entities),
        'EX',
        1800,
      );
    });

    it('should return cached entities', async () => {
      const entities = [{ name: 'Hero' }];
      mockRedis.get.mockResolvedValue(JSON.stringify(entities));

      const result = await cacheService.getCachedEntities(1);
      expect(result).toEqual(entities);
    });

    it('should return null on error', async () => {
      mockRedis.get.mockRejectedValue(new Error('fail'));
      const result = await cacheService.getCachedEntities(1);
      expect(result).toBeNull();
    });
  });

  describe('cacheLore / getCachedLore', () => {
    it('should cache lore with 1hr TTL', async () => {
      const lore = [{ category: 'magic', title: 'Fire' }];
      await cacheService.cacheLore(5, lore);

      expect(mockRedis.set).toHaveBeenCalledWith(
        'story:lore:5',
        JSON.stringify(lore),
        'EX',
        3600,
      );
    });

    it('should return cached lore', async () => {
      const lore = [{ category: 'magic' }];
      mockRedis.get.mockResolvedValue(JSON.stringify(lore));

      const result = await cacheService.getCachedLore(5);
      expect(result).toEqual(lore);
    });
  });

  describe('cacheLatestSummary', () => {
    it('should cache summary string with 2hr TTL', async () => {
      await cacheService.cacheLatestSummary(3, 'Hero entered the cave.');

      expect(mockRedis.set).toHaveBeenCalledWith(
        'story:summary:3',
        'Hero entered the cave.',
        'EX',
        7200,
      );
    });
  });

  describe('invalidateStoryContext', () => {
    it('should delete all 5 cache keys for story', async () => {
      await cacheService.invalidateStoryContext(10);

      expect(mockRedis.del).toHaveBeenCalledWith(
        'story:context:10',
        'story:entities:10',
        'story:relationships:10',
        'story:lore:10',
        'story:summary:10',
      );
    });
  });

  describe('trackDailyTokens', () => {
    it('should increment input and output token counts', async () => {
      await cacheService.trackDailyTokens(7, 100, 200);

      const today = new Date().toISOString().split('T')[0];
      const key = `tokens:7:${today}`;

      expect(mockRedis.hincrby).toHaveBeenCalledWith(key, 'input', 100);
      expect(mockRedis.hincrby).toHaveBeenCalledWith(key, 'output', 200);
      expect(mockRedis.expire).toHaveBeenCalledWith(key, 2592000);
    });
  });

  describe('getDailyTokenUsage', () => {
    it('should return parsed token usage', async () => {
      mockRedis.hgetall.mockResolvedValue({ input: '500', output: '1000' });

      const result = await cacheService.getDailyTokenUsage(7);
      expect(result).toEqual({ input: 500, output: 1000 });
    });

    it('should return zero when no data', async () => {
      mockRedis.hgetall.mockResolvedValue({});

      const result = await cacheService.getDailyTokenUsage(7);
      expect(result).toEqual({ input: 0, output: 0 });
    });

    it('should return zero on error', async () => {
      mockRedis.hgetall.mockRejectedValue(new Error('fail'));

      const result = await cacheService.getDailyTokenUsage(7);
      expect(result).toEqual({ input: 0, output: 0 });
    });
  });
});
