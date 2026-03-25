// Mock Redis client for tests
const mockRedis = {
  get: jest.fn().mockResolvedValue(null),
  set: jest.fn().mockResolvedValue('OK'),
  del: jest.fn().mockResolvedValue(1),
  hincrby: jest.fn().mockResolvedValue(1),
  hgetall: jest.fn().mockResolvedValue({}),
  expire: jest.fn().mockResolvedValue(1),
};

module.exports = mockRedis;
