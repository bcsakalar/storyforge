const agentOrchestratorService = require('../../../src/services/agentOrchestratorService');
const geminiService = require('../../../src/services/geminiService');
const consistencyAgentService = require('../../../src/services/consistencyAgentService');
const prisma = require('../../../src/config/database');

jest.mock('../../../src/services/geminiService');
jest.mock('../../../src/services/consistencyAgentService');
jest.mock('../../../src/services/storyMemoryService');
jest.mock('../../../src/services/cacheService');
jest.mock('../../../src/config/database', () => require('../../helpers/mockPrisma'));

describe('AgentOrchestratorService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  const baseContext = {
    storyId: 1,
    genre: 'fantastik',
    summary: 'A hero goes on an adventure',
    recentChapters: [{ chapterNumber: 1, content: 'Once upon a time...', choices: [] }],
    choiceText: 'Enter the cave',
    imageBase64: null,
    mood: 'epik',
    characters: [],
    language: 'tr',
    memoryContext: 'Hero is active',
    chapterCount: 5,
  };

  describe('orchestrateContinuation', () => {
    it('should return writer result when consistency check passes', async () => {
      const writerResult = {
        storyData: { storyText: 'Hero entered the cave...', choices: [{ id: 1, text: 'Go deeper' }] },
        rawResponse: 'raw',
        usageMetadata: { inputTokens: 100, outputTokens: 200 },
      };

      geminiService.continueStory.mockResolvedValue(writerResult);

      // Mock full memory for consistency
      prisma.storyEntity.findMany.mockResolvedValue([
        { type: 'character', name: 'Hero', description: 'Protagonist', status: 'active', relationships: [], importance: 10 },
      ]);
      prisma.storyEvent.findMany.mockResolvedValue([]);
      prisma.storyLore.findMany.mockResolvedValue([]);
      prisma.storyWorldState.findFirst.mockResolvedValue(null);

      consistencyAgentService.shouldCheckConsistency.mockReturnValue(true);
      consistencyAgentService.validateConsistency.mockResolvedValue({
        isConsistent: true,
        score: 95,
        issues: [],
      });

      const result = await agentOrchestratorService.orchestrateContinuation(baseContext);

      expect(result.storyData.storyText).toBe('Hero entered the cave...');
      expect(result.consistencyScore).toBe(95);
      expect(geminiService.continueStory).toHaveBeenCalledTimes(1);
    });

    it('should retry when critical inconsistency found', async () => {
      const firstResult = {
        storyData: { storyText: 'Dead hero spoke...', choices: [] },
        rawResponse: 'raw1',
        usageMetadata: { inputTokens: 100, outputTokens: 200 },
      };
      const retryResult = {
        storyData: { storyText: 'The spirit of the hero appeared...', choices: [] },
        rawResponse: 'raw2',
        usageMetadata: { inputTokens: 120, outputTokens: 250 },
      };

      geminiService.continueStory
        .mockResolvedValueOnce(firstResult)
        .mockResolvedValueOnce(retryResult);

      prisma.storyEntity.findMany.mockResolvedValue([
        { type: 'character', name: 'Hero', description: 'Dead warrior', status: 'dead', relationships: [], importance: 10 },
      ]);
      prisma.storyEvent.findMany.mockResolvedValue([]);
      prisma.storyLore.findMany.mockResolvedValue([]);
      prisma.storyWorldState.findFirst.mockResolvedValue(null);

      consistencyAgentService.shouldCheckConsistency.mockReturnValue(true);
      consistencyAgentService.validateConsistency.mockResolvedValue({
        isConsistent: false,
        score: 30,
        issues: [
          { type: 'temporal', severity: 'critical', description: 'Dead hero is speaking', suggestedFix: 'Remove' },
        ],
      });
      consistencyAgentService.buildCorrectionPrompt.mockReturnValue('\n\nFix: Dead hero should not speak');

      const result = await agentOrchestratorService.orchestrateContinuation(baseContext);

      // Writer called twice (initial + retry)
      expect(geminiService.continueStory).toHaveBeenCalledTimes(2);
      // Result should be the retry result
      expect(result.storyData.storyText).toBe('The spirit of the hero appeared...');
      // Score should be improved
      expect(result.consistencyScore).toBe(50); // 30 + 20, capped at 95
    });

    it('should skip consistency check for early chapters', async () => {
      const earlyContext = { ...baseContext, chapterCount: 1 };
      const writerResult = {
        storyData: { storyText: 'Chapter 1 text', choices: [] },
        rawResponse: 'raw',
        usageMetadata: {},
      };

      geminiService.continueStory.mockResolvedValue(writerResult);
      prisma.storyEntity.findMany.mockResolvedValue([]);
      prisma.storyEvent.findMany.mockResolvedValue([]);
      prisma.storyLore.findMany.mockResolvedValue([]);
      prisma.storyWorldState.findFirst.mockResolvedValue(null);

      consistencyAgentService.shouldCheckConsistency.mockReturnValue(false);

      const result = await agentOrchestratorService.orchestrateContinuation(earlyContext);

      expect(consistencyAgentService.validateConsistency).not.toHaveBeenCalled();
      expect(result.consistencyScore).toBe(100);
    });

    it('should handle consistency check errors gracefully', async () => {
      const writerResult = {
        storyData: { storyText: 'Normal text', choices: [] },
        rawResponse: 'raw',
        usageMetadata: {},
      };

      geminiService.continueStory.mockResolvedValue(writerResult);
      prisma.storyEntity.findMany.mockResolvedValue([]);
      prisma.storyEvent.findMany.mockResolvedValue([]);
      prisma.storyLore.findMany.mockResolvedValue([]);
      prisma.storyWorldState.findFirst.mockResolvedValue(null);

      consistencyAgentService.shouldCheckConsistency.mockReturnValue(true);
      consistencyAgentService.validateConsistency.mockRejectedValue(new Error('API Error'));

      const result = await agentOrchestratorService.orchestrateContinuation(baseContext);

      // Should still return the writer result
      expect(result.storyData.storyText).toBe('Normal text');
      expect(result.consistencyScore).toBe(100); // Default when error
    });
  });

  describe('getFullMemoryForConsistency', () => {
    it('should collect entities, events, lore, and world state', async () => {
      prisma.storyEntity.findMany.mockResolvedValue([
        { type: 'character', name: 'Hero', description: 'Warrior', status: 'active', relationships: [], importance: 10 },
      ]);
      prisma.storyEvent.findMany.mockResolvedValue([
        { chapterNum: 3, description: 'Found sword', impact: 'major', isResolved: false },
      ]);
      prisma.storyLore.findMany.mockResolvedValue([
        { category: 'magic', title: 'Fire', content: 'Fire burns' },
      ]);
      prisma.storyWorldState.findFirst.mockResolvedValue({
        state: { location: 'Forest' },
      });

      const memory = await agentOrchestratorService.getFullMemoryForConsistency(1, 'test');

      expect(memory.entities).toHaveLength(1);
      expect(memory.entities[0].name).toBe('Hero');
      expect(memory.events).toHaveLength(1);
      expect(memory.lore).toHaveLength(1);
      expect(memory.worldState).toEqual({ location: 'Forest' });
    });
  });

  describe('generateAndSaveQuickSummary', () => {
    it('should generate quick summary and save to DB', async () => {
      geminiService.generateSummary.mockResolvedValue('Hero entered the cave and found a treasure.');
      prisma.chapter.update.mockResolvedValue({});

      await agentOrchestratorService.generateAndSaveQuickSummary(1, 10, 'Long chapter content...', 5);

      expect(geminiService.generateSummary).toHaveBeenCalledWith(
        [{ chapterNumber: 5, content: 'Long chapter content...' }],
        '',
        'quick',
      );
      expect(prisma.chapter.update).toHaveBeenCalledWith({
        where: { id: 10 },
        data: { quickSummary: 'Hero entered the cave and found a treasure.' },
      });
    });

    it('should handle errors without throwing', async () => {
      geminiService.generateSummary.mockRejectedValue(new Error('API Error'));

      // Should not throw
      await expect(
        agentOrchestratorService.generateAndSaveQuickSummary(1, 10, 'text', 5),
      ).resolves.toBeUndefined();
    });
  });
});
