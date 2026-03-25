const consistencyAgentService = require('../../../src/services/consistencyAgentService');
const ai = require('../../../src/config/gemini');

jest.mock('../../../src/config/gemini', () => ({
  models: {
    generateContent: jest.fn(),
  },
}));

describe('ConsistencyAgentService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('shouldCheckConsistency', () => {
    it('should return false for chapters <= 2', () => {
      expect(consistencyAgentService.shouldCheckConsistency(1, 0)).toBe(false);
      expect(consistencyAgentService.shouldCheckConsistency(2, 5)).toBe(false);
    });

    it('should return true for chapters > 2', () => {
      expect(consistencyAgentService.shouldCheckConsistency(3, 1)).toBe(true);
      expect(consistencyAgentService.shouldCheckConsistency(10, 5)).toBe(true);
      expect(consistencyAgentService.shouldCheckConsistency(50, 20)).toBe(true);
    });
  });

  describe('buildCorrectionPrompt', () => {
    it('should return empty string for no issues', () => {
      expect(consistencyAgentService.buildCorrectionPrompt([])).toBe('');
      expect(consistencyAgentService.buildCorrectionPrompt(null)).toBe('');
    });

    it('should return empty string for non-critical issues only', () => {
      const issues = [
        { type: 'groundedness', severity: 'warning', description: 'Minor typo' },
        { type: 'relevance', severity: 'info', description: 'Tangential scene' },
      ];
      expect(consistencyAgentService.buildCorrectionPrompt(issues)).toBe('');
    });

    it('should build correction prompt for critical issues', () => {
      const issues = [
        {
          type: 'temporal',
          severity: 'critical',
          description: 'Dead character is speaking',
          suggestedFix: 'Remove dialogue from dead character',
        },
        {
          type: 'groundedness',
          severity: 'warning',
          description: 'Minor name variation',
        },
      ];
      const prompt = consistencyAgentService.buildCorrectionPrompt(issues);
      expect(prompt).toContain('DÜZELTİLMESİ GEREKEN SORUNLAR');
      expect(prompt).toContain('Dead character is speaking');
      expect(prompt).toContain('Remove dialogue from dead character');
      // Should NOT include warning-level issues
      expect(prompt).not.toContain('Minor name variation');
    });
  });

  describe('validateConsistency', () => {
    it('should return consistent result when Gemini returns clean check', async () => {
      ai.models.generateContent.mockResolvedValue({
        text: JSON.stringify({ isConsistent: true, score: 95, issues: [] }),
      });

      const result = await consistencyAgentService.validateConsistency(
        'Test story text',
        { entities: [], events: [], lore: [], worldState: null },
        'Go left',
      );

      expect(result.isConsistent).toBe(true);
      expect(result.score).toBe(95);
      expect(result.issues).toEqual([]);
    });

    it('should return inconsistent result with issues', async () => {
      const issues = [
        {
          type: 'temporal',
          severity: 'critical',
          description: 'Dead character Ahmet is speaking',
          suggestedFix: 'Remove Ahmet dialogue',
        },
      ];

      ai.models.generateContent.mockResolvedValue({
        text: JSON.stringify({ isConsistent: false, score: 40, issues }),
      });

      const result = await consistencyAgentService.validateConsistency(
        'Ahmet said hello',
        {
          entities: [
            { type: 'character', name: 'Ahmet', description: 'A warrior', status: 'dead', relationships: [] },
          ],
          events: [],
          lore: [],
          worldState: null,
        },
        'Go to the tavern',
      );

      expect(result.isConsistent).toBe(false);
      expect(result.score).toBe(40);
      expect(result.issues).toHaveLength(1);
      expect(result.issues[0].type).toBe('temporal');
    });

    it('should handle JSON parse errors gracefully', async () => {
      ai.models.generateContent.mockResolvedValue({
        text: 'invalid json response',
      });

      const result = await consistencyAgentService.validateConsistency(
        'Test text',
        { entities: [], events: [], lore: [], worldState: null },
        'Choice',
      );

      // Safe fallback
      expect(result.isConsistent).toBe(true);
      expect(result.score).toBe(80);
    });

    it('should include entities, events, lore in prompt', async () => {
      ai.models.generateContent.mockResolvedValue({
        text: JSON.stringify({ isConsistent: true, score: 100, issues: [] }),
      });

      await consistencyAgentService.validateConsistency(
        'Test text',
        {
          entities: [
            { type: 'character', name: 'Hero', description: 'The protagonist', status: 'active', relationships: [] },
          ],
          events: [
            { chapterNumber: 1, description: 'Hero found a sword', impact: 'major', isResolved: false },
          ],
          lore: [
            { category: 'magic', title: 'Fire spells', content: 'Fire spells require focus' },
          ],
          worldState: { location: 'Forest' },
        },
        'Attack the dragon',
      );

      const callArgs = ai.models.generateContent.mock.calls[0][0];
      expect(callArgs.contents).toContain('Hero');
      expect(callArgs.contents).toContain('found a sword');
      expect(callArgs.contents).toContain('Fire spells');
      expect(callArgs.contents).toContain('Attack the dragon');
    });
  });
});
