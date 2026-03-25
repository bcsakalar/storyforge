const prisma = require('../../../src/config/database');

jest.mock('../../../src/config/database', () => require('../../helpers/mockPrisma'));
jest.mock('../../../src/config/gemini', () => ({
  models: {
    generateContent: jest.fn(),
  },
}));

const relationshipGraphService = require('../../../src/services/relationshipGraphService');
const ai = require('../../../src/config/gemini');

describe('RelationshipGraphService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('extractRelationshipsFromChapter', () => {
    it('should extract relationships using function calling', async () => {
      ai.models.generateContent.mockResolvedValue({
        candidates: [
          {
            content: {
              parts: [
                {
                  functionCall: {
                    name: 'extractRelationshipsAndStatus',
                    args: {
                      relationships: [
                        { sourceName: 'Kael', targetName: 'Lyra', type: 'ally', description: 'Trusted companion' },
                      ],
                      statusChanges: [
                        { entityName: 'Dragon', newStatus: 'dead', reason: 'Slain by Kael' },
                      ],
                    },
                  },
                },
              ],
            },
          },
        ],
      });

      const result = await relationshipGraphService.extractRelationshipsFromChapter(
        'Kael defeated the dragon with Lyra by his side.',
        [{ type: 'character', name: 'Kael', status: 'active' }],
      );

      expect(result.relationships).toHaveLength(1);
      expect(result.relationships[0].type).toBe('ally');
      expect(result.statusChanges).toHaveLength(1);
      expect(result.statusChanges[0].newStatus).toBe('dead');
    });

    it('should return empty arrays when AI returns no function call', async () => {
      ai.models.generateContent.mockResolvedValue({
        candidates: [{ content: { parts: [{ text: 'No relationships found.' }] } }],
      });

      const result = await relationshipGraphService.extractRelationshipsFromChapter('Nothing happened.', []);

      expect(result).toEqual({ relationships: [], statusChanges: [] });
    });
  });

  describe('applyRelationships', () => {
    it('should add new relationship to entity', async () => {
      prisma.storyEntity.findFirst.mockResolvedValue({
        id: 10,
        name: 'Kael',
        relationships: [],
      });
      prisma.storyEntity.update.mockResolvedValue({});

      await relationshipGraphService.applyRelationships(1, 5, [
        { sourceName: 'Kael', targetName: 'Lyra', type: 'ally', description: 'Fighting together' },
      ]);

      expect(prisma.storyEntity.update).toHaveBeenCalledWith({
        where: { id: 10 },
        data: {
          relationships: [
            {
              targetName: 'Lyra',
              type: 'ally',
              since: 5,
              description: 'Fighting together',
              lastUpdated: 5,
            },
          ],
        },
      });
    });

    it('should update existing relationship', async () => {
      prisma.storyEntity.findFirst.mockResolvedValue({
        id: 10,
        name: 'Kael',
        relationships: [
          { targetName: 'Lyra', type: 'stranger', since: 1, description: 'Met briefly', lastUpdated: 1 },
        ],
      });
      prisma.storyEntity.update.mockResolvedValue({});

      await relationshipGraphService.applyRelationships(1, 5, [
        { sourceName: 'Kael', targetName: 'Lyra', type: 'ally', description: 'Now allies' },
      ]);

      const updateCall = prisma.storyEntity.update.mock.calls[0][0];
      expect(updateCall.data.relationships[0].type).toBe('ally');
      expect(updateCall.data.relationships[0].since).toBe(1); // Keeps original since
      expect(updateCall.data.relationships[0].lastUpdated).toBe(5);
    });

    it('should skip if source entity not found', async () => {
      prisma.storyEntity.findFirst.mockResolvedValue(null);

      await relationshipGraphService.applyRelationships(1, 5, [
        { sourceName: 'Unknown', targetName: 'Lyra', type: 'ally' },
      ]);

      expect(prisma.storyEntity.update).not.toHaveBeenCalled();
    });
  });

  describe('applyStatusChanges', () => {
    it('should update entity status and append history', async () => {
      prisma.storyEntity.findFirst.mockResolvedValue({
        id: 20,
        name: 'Dragon',
        status: 'active',
        statusHistory: [],
      });
      prisma.storyEntity.update.mockResolvedValue({});

      await relationshipGraphService.applyStatusChanges(1, 8, [
        { entityName: 'Dragon', newStatus: 'dead', reason: 'Slain by hero' },
      ]);

      expect(prisma.storyEntity.update).toHaveBeenCalledWith({
        where: { id: 20 },
        data: {
          status: 'dead',
          statusHistory: [{ chapter: 8, from: 'active', to: 'dead', reason: 'Slain by hero' }],
        },
      });
    });

    it('should skip if status unchanged', async () => {
      prisma.storyEntity.findFirst.mockResolvedValue({
        id: 20,
        name: 'Dragon',
        status: 'dead',
        statusHistory: [],
      });

      await relationshipGraphService.applyStatusChanges(1, 10, [
        { entityName: 'Dragon', newStatus: 'dead', reason: 'Already dead' },
      ]);

      expect(prisma.storyEntity.update).not.toHaveBeenCalled();
    });

    it('should skip if entity not found', async () => {
      prisma.storyEntity.findFirst.mockResolvedValue(null);

      await relationshipGraphService.applyStatusChanges(1, 10, [
        { entityName: 'Ghost', newStatus: 'dead', reason: 'Vanished' },
      ]);

      expect(prisma.storyEntity.update).not.toHaveBeenCalled();
    });
  });

  describe('getRelationshipGraph', () => {
    it('should return formatted character data', async () => {
      prisma.storyEntity.findMany.mockResolvedValue([
        {
          name: 'Kael',
          description: 'Warrior',
          status: 'active',
          relationships: [{ targetName: 'Lyra', type: 'ally' }],
          importance: 10,
        },
      ]);

      const result = await relationshipGraphService.getRelationshipGraph(1);

      expect(result).toEqual([
        {
          name: 'Kael',
          description: 'Warrior',
          status: 'active',
          importance: 10,
          relationships: [{ targetName: 'Lyra', type: 'ally' }],
        },
      ]);
    });
  });

  describe('buildRelationshipContext', () => {
    it('should format relationship context string', () => {
      const entities = [
        {
          type: 'character',
          name: 'Kael',
          relationships: [
            { targetName: 'Lyra', type: 'ally', since: 3, description: 'Battle companions' },
          ],
        },
      ];

      const context = relationshipGraphService.buildRelationshipContext(entities);

      expect(context).toContain('KARAKTER İLİŞKİLERİ');
      expect(context).toContain('Kael → Lyra: ally');
      expect(context).toContain('bölüm 3');
      expect(context).toContain('Battle companions');
    });

    it('should return empty string for empty entities', () => {
      expect(relationshipGraphService.buildRelationshipContext([])).toBe('');
      expect(relationshipGraphService.buildRelationshipContext(null)).toBe('');
    });

    it('should return empty when no character has relationships', () => {
      const entities = [{ type: 'character', name: 'Solo', relationships: [] }];
      const context = relationshipGraphService.buildRelationshipContext(entities);
      expect(context).toBe('');
    });
  });
});
