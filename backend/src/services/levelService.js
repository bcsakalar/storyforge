const prisma = require('../config/database');

const XP_REWARDS = {
  chapter_complete: 10,
  story_complete: 100,
  daily_quest: 25,
  achievement: 50,
  share_story: 15,
  coop_chapter: 15,
  first_story: 50,
};

function calculateLevel(xp) {
  return Math.max(1, Math.floor(Math.sqrt(xp / 100)));
}

function xpForNextLevel(level) {
  return (level + 1) * (level + 1) * 100;
}

async function addXp(userId, actionOrAmount, reason) {
  // Support both addXp(userId, 'chapter') and addXp(userId, 50, 'some reason')
  let amount;
  if (typeof actionOrAmount === 'string') {
    const actionMap = {
      chapter: XP_REWARDS.chapter_complete,
      story: XP_REWARDS.story_complete,
      share: XP_REWARDS.share_story,
      coop: XP_REWARDS.coop_chapter,
      daily_quest: XP_REWARDS.daily_quest,
      achievement: XP_REWARDS.achievement,
      first_story: XP_REWARDS.first_story,
    };
    amount = actionMap[actionOrAmount] || XP_REWARDS.chapter_complete;
    reason = actionOrAmount;
  } else {
    amount = actionOrAmount;
  }

  const stats = await prisma.userStats.upsert({
    where: { userId },
    update: {},
    create: { userId },
  });

  const newXp = stats.xp + amount;
  const newLevel = calculateLevel(newXp);

  const updated = await prisma.userStats.update({
    where: { userId },
    data: { xp: newXp, level: newLevel },
  });

  const leveledUp = newLevel > stats.level;

  return { ...updated, leveledUp, xpGained: amount, reason };
}

async function getLevelInfo(userId) {
  const stats = await prisma.userStats.upsert({
    where: { userId },
    update: {},
    create: { userId },
  });

  const nextLevelXp = xpForNextLevel(stats.level);
  const currentLevelXp = stats.level * stats.level * 100;
  const progress = stats.xp - currentLevelXp;
  const needed = nextLevelXp - currentLevelXp;

  return {
    level: stats.level,
    xp: stats.xp,
    nextLevelXp,
    progress,
    needed,
    percentage: Math.min(100, Math.round((progress / needed) * 100)),
  };
}

async function incrementStoriesCompleted(userId, genre) {
  const stats = await prisma.userStats.upsert({
    where: { userId },
    update: {},
    create: { userId },
  });

  const genreCounts = stats.genreCounts || {};
  genreCounts[genre] = (genreCounts[genre] || 0) + 1;

  return prisma.userStats.update({
    where: { userId },
    data: {
      storiesCompleted: { increment: 1 },
      genreCounts,
    },
  });
}

async function updateStreak(userId) {
  const stats = await prisma.userStats.upsert({
    where: { userId },
    update: {},
    create: { userId },
  });

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const lastActive = stats.lastActiveDate ? new Date(stats.lastActiveDate) : null;
  if (lastActive) {
    lastActive.setHours(0, 0, 0, 0);
  }

  let newStreak = stats.dailyStreak;

  if (!lastActive || today.getTime() !== lastActive.getTime()) {
    if (lastActive) {
      const diffDays = Math.floor((today - lastActive) / (1000 * 60 * 60 * 24));
      if (diffDays === 1) {
        newStreak += 1;
      } else if (diffDays > 1) {
        newStreak = 1;
      }
    } else {
      newStreak = 1;
    }

    await prisma.userStats.update({
      where: { userId },
      data: { dailyStreak: newStreak, lastActiveDate: today },
    });
  }

  return newStreak;
}

module.exports = {
  XP_REWARDS,
  calculateLevel,
  xpForNextLevel,
  addXp,
  getLevelInfo,
  incrementStoriesCompleted,
  updateStreak,
};
