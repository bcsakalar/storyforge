// Mock Prisma client for tests
const mockPrisma = {
  story: {
    findFirst: jest.fn(),
    findUnique: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
    count: jest.fn(),
    groupBy: jest.fn(),
  },
  chapter: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    updateMany: jest.fn(),
    count: jest.fn(),
  },
  storyEntity: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    upsert: jest.fn(),
    update: jest.fn(),
  },
  storyEvent: {
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    updateMany: jest.fn(),
  },
  storyWorldState: {
    findFirst: jest.fn(),
    upsert: jest.fn(),
  },
  storyLore: {
    findMany: jest.fn(),
    upsert: jest.fn(),
    create: jest.fn(),
  },
  user: {
    findUnique: jest.fn(),
    findFirst: jest.fn(),
    create: jest.fn(),
  },
  userStats: {
    create: jest.fn(),
    findUnique: jest.fn(),
  },
  $transaction: jest.fn((arr) => Promise.resolve(arr)),
  $queryRawUnsafe: jest.fn().mockResolvedValue([]),
};

module.exports = mockPrisma;
