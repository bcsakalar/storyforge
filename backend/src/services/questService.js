const prisma = require('../config/database');

const QUEST_TYPES = [
  { type: 'write_chapter', title: 'Bir bölüm yaz', description: 'Bugün bir hikaye bölümü tamamla', rewardXp: 25 },
  { type: 'complete_story', title: 'Hikaye bitir', description: 'Bir hikayeyi tamamla', rewardXp: 50 },
  { type: 'share_story', title: 'Hikaye paylaş', description: 'Bir hikayeni paylaş', rewardXp: 20 },
  { type: 'add_friend', title: 'Arkadaş ekle', description: 'Yeni bir arkadaş ekle', rewardXp: 15 },
  { type: 'send_message', title: 'Mesaj gönder', description: 'Bir arkadaşına mesaj gönder', rewardXp: 10 },
  { type: 'like_story', title: 'Hikaye beğen', description: 'Bir paylaşılan hikayeyi beğen', rewardXp: 10 },
  { type: 'start_story', title: 'Yeni hikaye başlat', description: 'Yeni bir hikaye başlat', rewardXp: 15 },
];

async function generateDailyQuests(userId) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // Check if quests already exist for today
  const existing = await prisma.dailyQuest.findMany({
    where: { userId, date: today },
  });
  if (existing.length > 0) return existing;

  // Pick 3 random quests
  const shuffled = [...QUEST_TYPES].sort(() => Math.random() - 0.5);
  const selected = shuffled.slice(0, 3);

  const quests = await Promise.all(
    selected.map((q) =>
      prisma.dailyQuest.create({
        data: {
          userId,
          questType: q.type,
          rewardXp: q.rewardXp,
          date: today,
        },
      })
    )
  );

  return quests;
}

async function getUserQuests(userId) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  let quests = await prisma.dailyQuest.findMany({
    where: { userId, date: today },
  });

  // Auto-generate if none exist
  if (quests.length === 0) {
    quests = await generateDailyQuests(userId);
  }

  // Enrich with quest info
  return quests.map((q) => {
    const def = QUEST_TYPES.find((qt) => qt.type === q.questType) || {};
    return {
      ...q,
      title: def.title || q.questType,
      description: def.description || '',
    };
  });
}

async function checkQuestCompletion(userId, eventType) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const quests = await prisma.dailyQuest.findMany({
    where: { userId, date: today, isCompleted: false },
  });

  const completed = [];
  for (const quest of quests) {
    let match = false;
    switch (quest.questType) {
      case 'write_chapter':
        match = eventType === 'chapter_complete';
        break;
      case 'complete_story':
        match = eventType === 'story_complete';
        break;
      case 'share_story':
        match = eventType === 'share_story';
        break;
      case 'add_friend':
        match = eventType === 'friend_added';
        break;
      case 'send_message':
        match = eventType === 'message_sent';
        break;
      case 'like_story':
        match = eventType === 'like_story';
        break;
      case 'start_story':
        match = eventType === 'story_created';
        break;
    }
    if (match) {
      await prisma.dailyQuest.update({
        where: { id: quest.id },
        data: { isCompleted: true },
      });
      completed.push(quest);
    }
  }

  return completed;
}

async function claimQuestReward(questId, userId) {
  const quest = await prisma.dailyQuest.findUnique({ where: { id: questId } });
  if (!quest || quest.userId !== userId) {
    throw Object.assign(new Error('Görev bulunamadı'), { status: 404 });
  }
  if (!quest.isCompleted) {
    throw Object.assign(new Error('Görev henüz tamamlanmadı'), { status: 400 });
  }

  // Award XP and delete quest to prevent double-claim
  const levelService = require('./levelService');
  await levelService.addXp(userId, quest.rewardXp, `quest:${quest.questType}`);

  await prisma.dailyQuest.delete({ where: { id: questId } });

  return { ...quest, claimed: true, rewardXp: quest.rewardXp };
}

module.exports = {
  QUEST_TYPES,
  generateDailyQuests,
  getUserQuests,
  checkQuestCompletion,
  claimQuestReward,
};
