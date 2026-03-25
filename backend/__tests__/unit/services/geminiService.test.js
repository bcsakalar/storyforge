jest.mock('../../../src/config/gemini', () => ({
  models: {
    generateContent: jest.fn(),
  },
}));

const ai = require('../../../src/config/gemini');
const geminiService = require('../../../src/services/geminiService');

describe('geminiService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    ai.models.generateContent.mockResolvedValue({
      text: JSON.stringify({
        storyText: 'Paragraf 1\n\nParagraf 2',
        choices: [{ id: 1, text: 'Devam et' }],
        mood: 'gizem',
        chapterSummary: 'Kisa ozet',
      }),
    });
  });

  describe('startNewStory', () => {
    it('should request explicit paragraph breaks in story text instructions', async () => {
      await geminiService.startNewStory('gizem');

      const args = ai.models.generateContent.mock.calls[0][0];
      expect(args.config.systemInstruction).toContain('JSON storyText alanında paragrafları MUTLAKA \\n\\n');
      expect(args.config.systemInstruction).toContain('Sahne geçişlerini \\n***\\n şeklinde yaz');
    });
  });

  describe('continueStory', () => {
    it('should preserve paragraph formatting instructions for continuation chapters', async () => {
      await geminiService.continueStory('gizem', 'Onceki ozet', [], 'Kapiyi ac');

      const args = ai.models.generateContent.mock.calls[0][0];
      expect(args.config.systemInstruction).toContain('JSON storyText alanında paragrafları MUTLAKA \\n\\n');
      expect(args.config.systemInstruction).toContain('Düz metin bloğu oluşturma, okunabilir paragraflar halinde yaz');
    });
  });
});