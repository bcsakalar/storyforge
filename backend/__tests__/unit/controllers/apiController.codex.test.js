/**
 * Tests for Codex, Timeline, and Reading Stats API endpoints
 */

const mockPrisma = require('../../helpers/mockPrisma');
jest.mock('../../../src/config/database', () => mockPrisma);
jest.mock('../../../src/services/storyService', () => ({}));
jest.mock('../../../src/services/geminiService', () => ({}));
jest.mock('../../../src/services/friendService', () => ({}));
jest.mock('../../../src/services/messageService', () => ({}));
jest.mock('../../../src/services/socialService', () => ({}));
jest.mock('../../../src/services/coopService', () => ({}));
jest.mock('../../../src/services/characterService', () => ({}));
jest.mock('../../../src/services/achievementService', () => ({}));
jest.mock('../../../src/services/levelService', () => ({}));
jest.mock('../../../src/services/questService', () => ({}));
jest.mock('../../../src/services/blockService', () => ({}));
jest.mock('../../../src/services/pushService', () => ({}));
jest.mock('../../../src/services/notificationService', () => ({}));
jest.mock('../../../src/services/exportService', () => ({}));
jest.mock('../../../src/config/socket', () => ({ emitToUser: jest.fn(), emitToAll: jest.fn() }));
jest.mock('../../../src/config/upload', () => ({ getPublicUrl: jest.fn(), deleteFile: jest.fn() }));
jest.mock('../../../src/controllers/storyController', () => ({ GENRES: [] }));

const apiController = require('../../../src/controllers/apiController');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

beforeEach(() => {
  jest.clearAllMocks();
});

// ===================== getStoryCodex =====================
describe('getStoryCodex', () => {
  test('returns 404 when story not found', async () => {
    mockPrisma.story.findFirst.mockResolvedValue(null);
    const req = { params: { id: '1' }, userId: 10 };
    const res = mockRes();
    const next = jest.fn();

    await apiController.getStoryCodex(req, res, next);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({ error: 'Hikaye bulunamadı' });
  });

  test('returns codex grouped by type', async () => {
    mockPrisma.story.findFirst.mockResolvedValue({ id: 1 });
    mockPrisma.storyEntity.findMany.mockResolvedValue([
      { id: 1, type: 'character', name: 'Arin', description: 'Hero', importance: 5 },
      { id: 2, type: 'location', name: 'Castle', description: 'Dark', importance: 3 },
      { id: 3, type: 'object', name: 'Sword', description: 'Magic', importance: 2 },
      { id: 4, type: 'faction', name: 'Rebels', description: 'Freedom', importance: 1 },
      { id: 5, type: 'character', name: 'Kira', description: 'Thief', importance: 4 },
    ]);
    mockPrisma.storyLore.findMany.mockResolvedValue([
      { id: 1, category: 'magic', title: 'Rune system', content: 'Ancient runes' },
    ]);

    const req = { params: { id: '1' }, userId: 10 };
    const res = mockRes();
    await apiController.getStoryCodex(req, res, jest.fn());

    expect(res.json).toHaveBeenCalledWith({
      codex: {
        characters: expect.arrayContaining([
          expect.objectContaining({ name: 'Arin' }),
          expect.objectContaining({ name: 'Kira' }),
        ]),
        locations: [expect.objectContaining({ name: 'Castle' })],
        items: [expect.objectContaining({ name: 'Sword' })],
        factions: [expect.objectContaining({ name: 'Rebels' })],
        lore: [expect.objectContaining({ title: 'Rune system' })],
      },
      totalEntities: 5,
    });
  });

  test('returns empty codex when no entities', async () => {
    mockPrisma.story.findFirst.mockResolvedValue({ id: 1 });
    mockPrisma.storyEntity.findMany.mockResolvedValue([]);
    mockPrisma.storyLore.findMany.mockResolvedValue([]);

    const req = { params: { id: '1' }, userId: 10 };
    const res = mockRes();
    await apiController.getStoryCodex(req, res, jest.fn());

    expect(res.json).toHaveBeenCalledWith({
      codex: { characters: [], locations: [], items: [], factions: [], lore: [] },
      totalEntities: 0,
    });
  });

  test('calls next on database error', async () => {
    mockPrisma.story.findFirst.mockRejectedValue(new Error('DB fail'));
    const req = { params: { id: '1' }, userId: 10 };
    const next = jest.fn();
    await apiController.getStoryCodex(req, mockRes(), next);
    expect(next).toHaveBeenCalledWith(expect.any(Error));
  });
});

// ===================== getStoryTimeline =====================
describe('getStoryTimeline', () => {
  test('returns 404 when story not found', async () => {
    mockPrisma.story.findFirst.mockResolvedValue(null);
    const req = { params: { id: '5' }, userId: 10 };
    const res = mockRes();
    await apiController.getStoryTimeline(req, res, jest.fn());
    expect(res.status).toHaveBeenCalledWith(404);
  });

  test('returns events grouped by chapter', async () => {
    mockPrisma.story.findFirst.mockResolvedValue({ id: 5 });
    mockPrisma.storyEvent.findMany.mockResolvedValue([
      { id: 1, chapterNum: 1, description: 'Battle starts', impact: 'major', entities: ['Arin'], isResolved: false },
      { id: 2, chapterNum: 1, description: 'Ally appears', impact: 'minor', entities: ['Kira'], isResolved: true },
      { id: 3, chapterNum: 2, description: 'Castle falls', impact: 'critical', entities: ['Castle'], isResolved: false },
    ]);

    const req = { params: { id: '5' }, userId: 10 };
    const res = mockRes();
    await apiController.getStoryTimeline(req, res, jest.fn());

    const result = res.json.mock.calls[0][0];
    expect(result.events).toHaveLength(3);
    expect(result.totalEvents).toBe(3);
    expect(result.byChapter[1]).toHaveLength(2);
    expect(result.byChapter[2]).toHaveLength(1);
  });

  test('returns empty timeline', async () => {
    mockPrisma.story.findFirst.mockResolvedValue({ id: 5 });
    mockPrisma.storyEvent.findMany.mockResolvedValue([]);

    const req = { params: { id: '5' }, userId: 10 };
    const res = mockRes();
    await apiController.getStoryTimeline(req, res, jest.fn());

    expect(res.json).toHaveBeenCalledWith({ events: [], byChapter: {}, totalEvents: 0 });
  });

  test('calls next on error', async () => {
    mockPrisma.story.findFirst.mockRejectedValue(new Error('timeout'));
    const next = jest.fn();
    await apiController.getStoryTimeline({ params: { id: '1' }, userId: 1 }, mockRes(), next);
    expect(next).toHaveBeenCalledWith(expect.any(Error));
  });
});

// ===================== getReadingStats =====================
describe('getReadingStats', () => {
  test('returns full reading stats', async () => {
    mockPrisma.story.count.mockResolvedValue(5);
    mockPrisma.chapter.count.mockResolvedValue(23);
    mockPrisma.story.groupBy.mockResolvedValue([
      { genre: 'fantastik', _count: { genre: 3 } },
      { genre: 'korku', _count: { genre: 2 } },
    ]);
    mockPrisma.userStats.findUnique.mockResolvedValue({
      storiesCompleted: 2,
      dailyStreak: 5,
      longestStreak: 12,
    });

    const req = { userId: 10 };
    const res = mockRes();
    await apiController.getReadingStats(req, res, jest.fn());

    expect(res.json).toHaveBeenCalledWith({
      totalStories: 5,
      totalChapters: 23,
      estimatedWords: 23000,
      favoriteGenre: 'fantastik',
      genreBreakdown: [
        { genre: 'fantastik', count: 3 },
        { genre: 'korku', count: 2 },
      ],
      completedStories: 2,
      dailyStreak: 5,
      longestStreak: 12,
    });
  });

  test('returns zeros when user has no stats', async () => {
    mockPrisma.story.count.mockResolvedValue(0);
    mockPrisma.chapter.count.mockResolvedValue(0);
    mockPrisma.story.groupBy.mockResolvedValue([]);
    mockPrisma.userStats.findUnique.mockResolvedValue(null);

    const req = { userId: 10 };
    const res = mockRes();
    await apiController.getReadingStats(req, res, jest.fn());

    const result = res.json.mock.calls[0][0];
    expect(result.totalStories).toBe(0);
    expect(result.totalChapters).toBe(0);
    expect(result.estimatedWords).toBe(0);
    expect(result.favoriteGenre).toBeNull();
    expect(result.completedStories).toBe(0);
    expect(result.dailyStreak).toBe(0);
  });

  test('calls next on error', async () => {
    mockPrisma.story.count.mockRejectedValue(new Error('fail'));
    const next = jest.fn();
    await apiController.getReadingStats({ userId: 1 }, mockRes(), next);
    expect(next).toHaveBeenCalledWith(expect.any(Error));
  });
});
