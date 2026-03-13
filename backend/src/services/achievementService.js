const prisma = require('../config/database');

// ─── Achievement Definitions (Seed Data) ─────────────────

const ACHIEVEMENT_DEFS = [
  { key: 'first_story', title: 'İlk Adım', description: 'İlk hikayeni başlat', icon: '📖', category: 'story', threshold: 1 },
  { key: 'story_5', title: 'Hikaye Sever', description: '5 hikaye tamamla', icon: '📚', category: 'story', threshold: 5 },
  { key: 'story_10', title: 'Kıdemli Yazar', description: '10 hikaye tamamla', icon: '✍️', category: 'story', threshold: 10 },
  { key: 'story_25', title: 'Efsane Anlatıcı', description: '25 hikaye tamamla', icon: '🏆', category: 'story', threshold: 25 },
  { key: 'chapter_50', title: 'Bölüm Avcısı', description: '50 bölüm tamamla', icon: '📄', category: 'story', threshold: 50 },
  { key: 'chapter_200', title: 'Sayfa Kurdu', description: '200 bölüm tamamla', icon: '📕', category: 'story', threshold: 200 },
  { key: 'genre_fantastik', title: 'Fantastik Usta', description: 'Fantastik türde 3 hikaye tamamla', icon: '🐉', category: 'genre', threshold: 3 },
  { key: 'genre_korku', title: 'Korku Ustası', description: 'Korku türünde 3 hikaye tamamla', icon: '👻', category: 'genre', threshold: 3 },
  { key: 'genre_bilim_kurgu', title: 'Bilim Kurgu Fanatiği', description: 'Bilim kurgu türünde 3 hikaye tamamla', icon: '🚀', category: 'genre', threshold: 3 },
  { key: 'genre_romantik', title: 'Romantik Ruh', description: 'Romantik türde 3 hikaye tamamla', icon: '💕', category: 'genre', threshold: 3 },
  { key: 'genre_macera', title: 'Maceraperest', description: 'Macera türünde 3 hikaye tamamla', icon: '⚔️', category: 'genre', threshold: 3 },
  { key: 'genre_gizem', title: 'Dedektif', description: 'Gizem türünde 3 hikaye tamamla', icon: '🔍', category: 'genre', threshold: 3 },
  { key: 'all_genres', title: 'Her Şeyin Ustası', description: 'Her türde en az 1 hikaye tamamla', icon: '🌟', category: 'genre', threshold: 6 },
  { key: 'social_first_friend', title: 'Sosyal Kelebek', description: 'İlk arkadaşını ekle', icon: '🤝', category: 'social', threshold: 1 },
  { key: 'social_share', title: 'Paylaşımcı', description: 'İlk hikayeni paylaş', icon: '📤', category: 'social', threshold: 1 },
  { key: 'social_10_likes', title: 'Beğeni Yağmuru', description: '10 beğeni al', icon: '❤️', category: 'social', threshold: 10 },
  { key: 'coop_first', title: 'Takım Oyuncusu', description: 'İlk co-op hikayeni tamamla', icon: '🎮', category: 'coop', threshold: 1 },
  { key: 'streak_7', title: 'Haftalık Seri', description: '7 günlük giriş serisi yap', icon: '🔥', category: 'streak', threshold: 7 },
  { key: 'streak_30', title: 'Aylık Seri', description: '30 günlük giriş serisi yap', icon: '💎', category: 'streak', threshold: 30 },
  { key: 'level_5', title: 'Çırak', description: 'Seviye 5\'e ulaş', icon: '⭐', category: 'level', threshold: 5 },
  { key: 'level_10', title: 'Usta', description: 'Seviye 10\'a ulaş', icon: '🌙', category: 'level', threshold: 10 },
  { key: 'level_25', title: 'Efsane', description: 'Seviye 25\'e ulaş', icon: '👑', category: 'level', threshold: 25 },
];

async function seedAchievements() {
  for (const def of ACHIEVEMENT_DEFS) {
    await prisma.achievement.upsert({
      where: { key: def.key },
      update: { title: def.title, description: def.description, icon: def.icon, category: def.category, threshold: def.threshold },
      create: def,
    });
  }
}

async function checkAndUnlock(userId, event, value = 1) {
  const unlocked = [];

  const stats = await getOrCreateStats(userId);
  const achievements = await prisma.achievement.findMany();
  const userAchievements = await prisma.userAchievement.findMany({
    where: { userId },
    select: { achievementId: true },
  });
  const unlockedIds = new Set(userAchievements.map((ua) => ua.achievementId));

  for (const ach of achievements) {
    if (unlockedIds.has(ach.id)) continue;

    let shouldUnlock = false;

    switch (ach.key) {
      case 'first_story':
      case 'story_5':
      case 'story_10':
      case 'story_25':
        shouldUnlock = stats.storiesCompleted >= ach.threshold;
        break;
      case 'chapter_50':
      case 'chapter_200': {
        const totalChapters = await prisma.chapter.count({
          where: { story: { userId } },
        });
        shouldUnlock = totalChapters >= ach.threshold;
        break;
      }
      case 'genre_fantastik':
      case 'genre_korku':
      case 'genre_bilim_kurgu':
      case 'genre_romantik':
      case 'genre_macera':
      case 'genre_gizem': {
        const genreKey = ach.key.replace('genre_', '');
        const counts = stats.genreCounts || {};
        shouldUnlock = (counts[genreKey] || 0) >= ach.threshold;
        break;
      }
      case 'all_genres': {
        const counts = stats.genreCounts || {};
        const genres = ['fantastik', 'korku', 'bilim_kurgu', 'romantik', 'macera', 'gizem'];
        const completedGenres = genres.filter((g) => (counts[g] || 0) >= 1).length;
        shouldUnlock = completedGenres >= ach.threshold;
        break;
      }
      case 'social_first_friend': {
        const friendCount = await prisma.friendship.count({
          where: { OR: [{ senderId: userId }, { receiverId: userId }], status: 'ACCEPTED' },
        });
        shouldUnlock = friendCount >= ach.threshold;
        break;
      }
      case 'social_share': {
        const shareCount = await prisma.sharedStory.count({ where: { userId } });
        shouldUnlock = shareCount >= ach.threshold;
        break;
      }
      case 'social_10_likes': {
        const likeCount = await prisma.like.count({
          where: { sharedStory: { userId } },
        });
        shouldUnlock = likeCount >= ach.threshold;
        break;
      }
      case 'coop_first': {
        const coopCount = await prisma.coopSession.count({
          where: {
            OR: [{ hostUserId: userId }, { guestUserId: userId }],
            status: 'COMPLETED',
          },
        });
        shouldUnlock = coopCount >= ach.threshold;
        break;
      }
      case 'streak_7':
      case 'streak_30':
        shouldUnlock = stats.dailyStreak >= ach.threshold;
        break;
      case 'level_5':
      case 'level_10':
      case 'level_25':
        shouldUnlock = stats.level >= ach.threshold;
        break;
    }

    if (shouldUnlock) {
      await prisma.userAchievement.create({
        data: { userId, achievementId: ach.id },
      });
      unlocked.push(ach);
    }
  }

  return unlocked;
}

async function getUserAchievements(userId) {
  return prisma.userAchievement.findMany({
    where: { userId },
    include: { achievement: true },
    orderBy: { unlockedAt: 'desc' },
  });
}

async function getAvailableAchievements() {
  return prisma.achievement.findMany({ orderBy: { category: 'asc' } });
}

async function getOrCreateStats(userId) {
  return prisma.userStats.upsert({
    where: { userId },
    update: {},
    create: { userId },
  });
}

module.exports = {
  seedAchievements,
  checkAndUnlock,
  getUserAchievements,
  getAvailableAchievements,
  getOrCreateStats,
  ACHIEVEMENT_DEFS,
};
