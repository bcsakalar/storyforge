const storyService = require('../services/storyService');
const geminiService = require('../services/geminiService');
const friendService = require('../services/friendService');
const messageService = require('../services/messageService');
const socialService = require('../services/socialService');
const coopService = require('../services/coopService');
const characterService = require('../services/characterService');
const achievementService = require('../services/achievementService');
const levelService = require('../services/levelService');
const questService = require('../services/questService');
const blockService = require('../services/blockService');
const pushService = require('../services/pushService');
const notificationService = require('../services/notificationService');
const exportService = require('../services/exportService');
const { emitToUser, emitToAll } = require('../config/socket');
const { getPublicUrl, deleteFile } = require('../config/upload');
const prisma = require('../config/database');
const { GENRES } = require('./storyController');

// ============ API (Mobile REST) ============

async function getStories(req, res, next) {
  try {
    const stories = await storyService.getUserStories(req.userId);
    res.json({ stories });
  } catch (err) {
    next(err);
  }
}

async function getStory(req, res, next) {
  try {
    const storyId = parseInt(req.params.id, 10);
    const story = await storyService.getStoryWithChapters(storyId, req.userId);
    if (!story) {
      return res.status(404).json({ error: 'Hikaye bulunamadı' });
    }
    res.json({ story });
  } catch (err) {
    next(err);
  }
}

async function createStory(req, res, next) {
  const { genre, mood, language } = req.body;
  try {
    const validGenres = GENRES.map((g) => g.value);
    if (!validGenres.includes(genre)) {
      return res.status(400).json({ error: 'Geçersiz tür seçimi' });
    }
    const story = await storyService.createStory(req.userId, genre, { mood, language });

    // Gamification: XP + quest + achievement check
    levelService.addXp(req.userId, 'story').catch(() => {});
    questService.checkQuestCompletion(req.userId, 'create_story').catch(() => {});
    achievementService.checkAndUnlock(req.userId, 'story_created').catch(() => {});

    res.status(201).json({ story });
  } catch (err) {
    next(err);
  }
}

async function makeChoice(req, res, next) {
  try {
    const storyId = parseInt(req.params.id, 10);
    const { choiceId, imageBase64 } = req.body;

    if (choiceId === undefined || choiceId === null) {
      return res.status(400).json({ error: 'choiceId gerekli' });
    }

    const story = await storyService.makeChoice(
      storyId,
      req.userId,
      parseInt(choiceId, 10),
      imageBase64 || null,
    );

    // Gamification: XP + quest
    levelService.addXp(req.userId, 'chapter').catch(() => {});
    questService.checkQuestCompletion(req.userId, 'complete_chapter').catch(() => {});
    achievementService.checkAndUnlock(req.userId, 'chapter_completed').catch(() => {});

    res.json({ story });
  } catch (err) {
    next(err);
  }
}

async function deleteStory(req, res, next) {
  try {
    const storyId = parseInt(req.params.id, 10);
    await storyService.deleteStory(storyId, req.userId);
    res.json({ message: 'Hikaye silindi' });
  } catch (err) {
    next(err);
  }
}

function getGenres(req, res) {
  res.json({ genres: GENRES });
}

async function chapterTts(req, res, next) {
  try {
    const storyId = parseInt(req.params.id, 10);
    const chapterNum = parseInt(req.params.chapterNum, 10);

    const story = await storyService.getStoryWithChapters(storyId, req.userId);
    if (!story) {
      return res.status(404).json({ error: 'Hikaye bulunamadı' });
    }

    const chapter = story.chapters.find((ch) => ch.chapterNumber === chapterNum);
    if (!chapter) {
      return res.status(404).json({ error: 'Bölüm bulunamadı' });
    }

    const pcmBase64 = await geminiService.generateSpeech(chapter.content);
    const wavBase64 = geminiService.pcmToWavBase64(pcmBase64);

    res.json({ audio: wavBase64 });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getStories,
  getStory,
  createStory,
  makeChoice,
  deleteStory,
  getGenres,
  chapterTts,

  // Story extras
  async getStoryTree(req, res, next) {
    try {
      const tree = await storyService.getStoryTree(parseInt(req.params.id, 10), req.userId);
      res.json({ tree });
    } catch (err) { next(err); }
  },
  async branchFromChapter(req, res, next) {
    try {
      const story = await storyService.branchFromChapter(
        parseInt(req.params.id, 10), req.userId,
        parseInt(req.params.chapterId, 10), parseInt(req.body.choiceId, 10),
      );
      res.status(201).json({ story });
    } catch (err) { next(err); }
  },
  async getRecap(req, res, next) {
    try {
      const recap = await storyService.getRecap(parseInt(req.params.id, 10), req.userId);
      res.json({ recap });
    } catch (err) { next(err); }
  },
  async completeStory(req, res, next) {
    try {
      const story = await storyService.completeStory(parseInt(req.params.id, 10), req.userId);
      levelService.addXp(req.userId, 'story').catch(() => {});
      levelService.incrementStoriesCompleted(req.userId, story.genre).catch(() => {});
      questService.checkQuestCompletion(req.userId, 'complete_story').catch(() => {});
      achievementService.checkAndUnlock(req.userId, 'story_completed').catch(() => {});
      res.json({ story });
    } catch (err) { next(err); }
  },
  async downloadStory(req, res, next) {
    try {
      const story = await storyService.downloadStory(parseInt(req.params.id, 10), req.userId);
      res.json({ story });
    } catch (err) { next(err); }
  },

  // Characters
  async createCharacter(req, res, next) {
    try {
      const { name, personality, appearance, role, traits, backstory } = req.body;
      if (!name) return res.status(400).json({ error: 'Karakter adı gerekli' });

      // Map mobile fields (role, traits, backstory) to DB columns (personality, appearance)
      const mappedPersonality = personality || [role, Array.isArray(traits) ? traits.join(', ') : ''].filter(Boolean).join(' — ') || '';
      const mappedAppearance = appearance || backstory || '';

      const character = await characterService.createCharacter(parseInt(req.params.id, 10), req.userId, { name, personality: mappedPersonality, appearance: mappedAppearance });
      res.status(201).json({ character });
    } catch (err) { next(err); }
  },
  async getCharacters(req, res, next) {
    try {
      const characters = await characterService.getCharacters(parseInt(req.params.id, 10), req.userId);
      res.json({ characters });
    } catch (err) { next(err); }
  },
  async updateCharacter(req, res, next) {
    try {
      const character = await characterService.updateCharacter(parseInt(req.params.charId, 10), req.userId, req.body);
      res.json({ character });
    } catch (err) { next(err); }
  },
  async deleteCharacter(req, res, next) {
    try {
      await characterService.deleteCharacter(parseInt(req.params.charId, 10), req.userId);
      res.json({ message: 'Karakter silindi' });
    } catch (err) { next(err); }
  },

  // Friends
  async searchUsers(req, res, next) {
    try {
      const users = await friendService.searchUsers(req.query.q || '', req.userId);
      res.json({ users });
    } catch (err) { next(err); }
  },
  async sendFriendRequest(req, res, next) {
    try {
      const friendship = await friendService.sendRequest(req.userId, req.body.username);
      notificationService.createNotification(friendship.receiverId, 'friend_request', 'Arkadaşlık İsteği', `Yeni bir arkadaşlık isteği aldın`, { senderId: req.userId }).catch(() => {});
      res.status(201).json({ friendship });
    } catch (err) { next(err); }
  },
  async acceptFriendRequest(req, res, next) {
    try {
      const friendship = await friendService.acceptRequest(parseInt(req.params.id, 10), req.userId);
      achievementService.checkAndUnlock(req.userId, 'friend_added').catch(() => {});
      // Notify original sender that their request was accepted
      notificationService.createNotification(friendship.senderId, 'friend_accepted', 'Arkadaşlık Kabul Edildi', `Arkadaşlık isteğin kabul edildi`, { friendId: req.userId }).catch(() => {});
      res.json({ friendship });
    } catch (err) { next(err); }
  },
  async rejectFriendRequest(req, res, next) {
    try {
      const friendship = await friendService.rejectRequest(parseInt(req.params.id, 10), req.userId);
      res.json({ friendship });
    } catch (err) { next(err); }
  },
  async removeFriend(req, res, next) {
    try {
      await friendService.removeFriend(parseInt(req.params.id, 10), req.userId);
      res.json({ message: 'Arkadaş çıkarıldı' });
    } catch (err) { next(err); }
  },
  async getFriends(req, res, next) {
    try {
      const friends = await friendService.getFriends(req.userId);
      res.json({ friends });
    } catch (err) { next(err); }
  },
  async getPendingRequests(req, res, next) {
    try {
      const requests = await friendService.getPendingRequests(req.userId);
      res.json({ requests });
    } catch (err) { next(err); }
  },

  // Messages
  async getConversations(req, res, next) {
    try {
      const conversations = await messageService.getConversations(req.userId);
      res.json({ conversations });
    } catch (err) { next(err); }
  },
  async getMessages(req, res, next) {
    try {
      const messages = await messageService.getMessages(req.userId, parseInt(req.params.userId, 10), req.query.cursor ? parseInt(req.query.cursor, 10) : undefined);
      res.json({ messages });
    } catch (err) { next(err); }
  },
  async sendMessage(req, res, next) {
    try {
      const { content, messageType, imageUrl } = req.body;
      const message = await messageService.sendMessage(req.userId, parseInt(req.params.userId, 10), content, { messageType, imageUrl });
      res.status(201).json({ message });
    } catch (err) { next(err); }
  },
  async markMessagesRead(req, res, next) {
    try {
      await messageService.markAsRead(req.userId, parseInt(req.params.userId, 10));
      res.json({ message: 'Okundu' });
    } catch (err) { next(err); }
  },

  // Social (sharing, likes, comments)
  async shareStory(req, res, next) {
    try {
      const result = await socialService.shareStory(parseInt(req.params.id, 10), req.userId, req.body.isPublic !== false);
      if (result.alreadyShared) {
        return res.status(409).json({ error: 'Bu hikaye zaten paylaşılmış.', alreadyShared: true });
      }
      levelService.addXp(req.userId, 'share').catch(() => {});
      questService.checkQuestCompletion(req.userId, 'share_story').catch(() => {});
      achievementService.checkAndUnlock(req.userId, 'story_shared').catch(() => {});
      res.status(201).json({ shared: result.shared });
    } catch (err) { next(err); }
  },
  async unshareStory(req, res, next) {
    try {
      await socialService.unshareStory(parseInt(req.params.id, 10), req.userId);
      res.json({ message: 'Paylaşım kaldırıldı' });
    } catch (err) { next(err); }
  },
  async getPublicStories(req, res, next) {
    try {
      const { sort, page, search, genre } = req.query;
      const stories = await socialService.getPublicStories(parseInt(page, 10) || 1, 20, sort || 'popular', { search, genre, requesterId: req.userId });
      res.json(stories);
    } catch (err) { next(err); }
  },
  async getFeed(req, res, next) {
    try {
      const feed = await socialService.getFeed(req.userId, parseInt(req.query.page, 10) || 1);
      res.json(feed);
    } catch (err) { next(err); }
  },
  async likeStory(req, res, next) {
    try {
      const sharedId = parseInt(req.params.id, 10);
      const alreadyLiked = await socialService.hasLiked(sharedId, req.userId);
      if (alreadyLiked) {
        await socialService.unlikeStory(sharedId, req.userId);
      } else {
        await socialService.likeStory(sharedId, req.userId);
      }
      const likeCount = await prisma.like.count({ where: { sharedStoryId: sharedId } });
      const shared = await prisma.sharedStory.findUnique({ where: { id: sharedId } });
      if (shared && !alreadyLiked) {
        notificationService.createNotification(shared.userId, 'like', 'Beğeni', 'Hikayeni birisi beğendi', { sharedStoryId: shared.id }).catch(() => {});
      }
      // Broadcast to all connected clients
      emitToAll('social:like', { sharedStoryId: sharedId, likeCount, userId: req.userId });
      res.json({ liked: !alreadyLiked, likeCount });
    } catch (err) { next(err); }
  },
  async unlikeStory(req, res, next) {
    try {
      const sharedId = parseInt(req.params.id, 10);
      await socialService.unlikeStory(sharedId, req.userId);
      const likeCount = await prisma.like.count({ where: { sharedStoryId: sharedId } });
      emitToAll('social:like', { sharedStoryId: sharedId, likeCount, userId: req.userId });
      res.json({ liked: false, likeCount });
    } catch (err) { next(err); }
  },
  async getComments(req, res, next) {
    try {
      const comments = await socialService.getComments(parseInt(req.params.id, 10));
      res.json({ comments });
    } catch (err) { next(err); }
  },
  async addComment(req, res, next) {
    try {
      const sharedId = parseInt(req.params.id, 10);
      const comment = await socialService.addComment(sharedId, req.userId, req.body.content);
      const shared = await prisma.sharedStory.findUnique({ where: { id: sharedId } });
      if (shared && shared.userId !== req.userId) {
        notificationService.createNotification(shared.userId, 'comment', 'Yorum', 'Hikayene yeni bir yorum yapıldı', { sharedStoryId: shared.id }).catch(() => {});
      }
      // Broadcast new comment to all connected clients
      const user = await prisma.user.findUnique({ where: { id: req.userId }, select: { username: true } });
      const commentCount = await prisma.comment.count({ where: { sharedStoryId: sharedId } });
      emitToAll('social:comment', { sharedStoryId: sharedId, commentCount, comment: { ...comment, user: { id: req.userId, username: user?.username } } });
      res.status(201).json({ comment });
    } catch (err) { next(err); }
  },
  async deleteComment(req, res, next) {
    try {
      await socialService.deleteComment(parseInt(req.params.commentId, 10), req.userId);
      res.json({ message: 'Yorum silindi' });
    } catch (err) { next(err); }
  },
  async getSharedStoryDetail(req, res, next) {
    try {
      const story = await socialService.getSharedStoryDetail(parseInt(req.params.id, 10), req.userId);
      res.json({ story });
    } catch (err) { next(err); }
  },

  // Co-op
  async createCoopSession(req, res, next) {
    try {
      const session = await coopService.createCoopSession(req.userId, req.body.genre, req.body.mood || null, req.body.guestUserId);
      notificationService.createNotification(req.body.guestUserId, 'coop_invite', 'Co-op Daveti', 'Bir arkadaşın seni hikaye yazmaya davet etti', { sessionId: session.id }).catch(() => {});
      res.status(201).json({ session });
    } catch (err) { next(err); }
  },
  async joinCoopSession(req, res, next) {
    try {
      const session = await coopService.joinCoopSession(parseInt(req.params.id, 10), req.userId);
      res.json({ session });
    } catch (err) { next(err); }
  },
  async getCoopSession(req, res, next) {
    try {
      const session = await coopService.getCoopSession(parseInt(req.params.id, 10), req.userId);
      res.json({ session });
    } catch (err) { next(err); }
  },
  async makeCoopChoice(req, res, next) {
    try {
      const session = await coopService.makeCoopChoice(parseInt(req.params.id, 10), req.userId, parseInt(req.body.choiceId, 10));
      levelService.addXp(req.userId, 'coop').catch(() => {});
      res.json({ session });
    } catch (err) { next(err); }
  },
  async getCoopInvites(req, res, next) {
    try {
      const invites = await coopService.getCoopInvites(req.userId);
      res.json({ invites });
    } catch (err) { next(err); }
  },
  async getUserCoopSessions(req, res, next) {
    try {
      const sessions = await coopService.getUserCoopSessions(req.userId);
      res.json({ sessions });
    } catch (err) { next(err); }
  },
  async rejectCoopSession(req, res, next) {
    try {
      await coopService.rejectCoopSession(parseInt(req.params.id, 10), req.userId);
      res.json({ success: true });
    } catch (err) { next(err); }
  },
  async completeCoopStory(req, res, next) {
    try {
      const session = await coopService.completeCoopStory(parseInt(req.params.id, 10), req.userId);
      res.json({ session });
    } catch (err) { next(err); }
  },
  async shareCoopStory(req, res, next) {
    try {
      const result = await coopService.shareCoopStory(parseInt(req.params.id, 10), req.userId);
      if (result.alreadyShared) {
        return res.status(409).json({ error: 'Bu hikaye zaten paylaşılmış.', alreadyShared: true });
      }
      res.json({ shared: result.shared });
    } catch (err) { next(err); }
  },
  async exportCoopPdf(req, res, next) {
    try {
      const pdfBuffer = await exportService.generateCoopPdf(parseInt(req.params.id, 10), req.userId);
      res.set({ 'Content-Type': 'application/pdf', 'Content-Disposition': 'attachment; filename="coop-story.pdf"' });
      res.send(pdfBuffer);
    } catch (err) { next(err); }
  },
  async getCoopRecap(req, res, next) {
    try {
      const result = await coopService.getCoopRecap(parseInt(req.params.id, 10), req.userId);
      res.json(result);
    } catch (err) { next(err); }
  },
  async getCoopStoryTree(req, res, next) {
    try {
      const tree = await coopService.getCoopStoryTree(parseInt(req.params.id, 10), req.userId);
      res.json(tree);
    } catch (err) { next(err); }
  },
  async createCoopCharacter(req, res, next) {
    try {
      const character = await coopService.addCoopCharacter(parseInt(req.params.id, 10), req.userId, {
        name: req.body.name,
        personality: req.body.personality || '',
        appearance: req.body.appearance || '',
      });
      res.status(201).json({ character });
    } catch (err) { next(err); }
  },
  async getCoopCharacters(req, res, next) {
    try {
      const characters = await coopService.getCoopCharacters(parseInt(req.params.id, 10), req.userId);
      res.json({ characters });
    } catch (err) { next(err); }
  },
  async deleteCoopCharacter(req, res, next) {
    try {
      await coopService.deleteCoopCharacter(parseInt(req.params.id, 10), parseInt(req.params.charId, 10), req.userId);
      res.json({ success: true });
    } catch (err) { next(err); }
  },

  // Achievements
  async getAchievements(req, res, next) {
    try {
      const achievements = await achievementService.getUserAchievements(req.userId);
      res.json({ achievements });
    } catch (err) { next(err); }
  },
  async getAvailableAchievements(req, res, next) {
    try {
      const achievements = await achievementService.getAvailableAchievements();
      res.json({ achievements });
    } catch (err) { next(err); }
  },

  // Level & XP
  async getLevelInfo(req, res, next) {
    try {
      const info = await levelService.getLevelInfo(req.userId);
      res.json(info);
    } catch (err) { next(err); }
  },

  // Quests
  async getDailyQuests(req, res, next) {
    try {
      const quests = await questService.getUserQuests(req.userId);
      res.json({ quests });
    } catch (err) { next(err); }
  },
  async claimQuestReward(req, res, next) {
    try {
      const result = await questService.claimQuestReward(parseInt(req.params.id, 10), req.userId);
      res.json(result);
    } catch (err) { next(err); }
  },

  // Notifications
  async getNotifications(req, res, next) {
    try {
      const result = await notificationService.getUserNotifications(req.userId);
      res.json(result);
    } catch (err) { next(err); }
  },
  async markNotificationRead(req, res, next) {
    try {
      await notificationService.markAsRead(parseInt(req.params.id, 10), req.userId);
      res.json({ message: 'Okundu' });
    } catch (err) { next(err); }
  },
  async markAllNotificationsRead(req, res, next) {
    try {
      await notificationService.markAllAsRead(req.userId);
      res.json({ message: 'Tümü okundu' });
    } catch (err) { next(err); }
  },

  // User settings
  async updateSettings(req, res, next) {
    try {
      const { theme, fontSize, language, profileImage } = req.body;
      const data = {};
      if (theme && ['dark', 'light'].includes(theme)) data.theme = theme;
      if (fontSize) data.fontSize = Math.min(Math.max(parseInt(fontSize, 10) || 16, 12), 24);
      if (language && ['tr', 'en'].includes(language)) data.language = language;
      if (profileImage !== undefined) {
        // Only allow relative /uploads/ paths or empty string
        if (profileImage === '' || profileImage === null || (typeof profileImage === 'string' && profileImage.startsWith('/uploads/'))) {
          data.profileImage = profileImage;
        }
      }

      const user = await prisma.user.update({
        where: { id: req.userId },
        data,
        select: { id: true, username: true, email: true, theme: true, fontSize: true, language: true, profileImage: true },
      });
      res.json({ user });
    } catch (err) { next(err); }
  },
  async registerPushToken(req, res, next) {
    try {
      await prisma.user.update({ where: { id: req.userId }, data: { pushToken: req.body.token } });
      res.json({ message: 'Token kaydedildi' });
    } catch (err) { next(err); }
  },
  async getUserProfile(req, res, next) {
    try {
      const user = await prisma.user.findUnique({
        where: { id: req.userId },
        select: {
          id: true, username: true, email: true, profileImage: true,
          theme: true, fontSize: true, language: true, createdAt: true,
          _count: { select: { stories: true } },
        },
      });
      const stats = await levelService.getLevelInfo(req.userId);
      const userStats = await prisma.userStats.findUnique({ where: { userId: req.userId } });
      res.json({
        user: {
          ...user,
          stats: {
            storiesCompleted: userStats?.storiesCompleted ?? 0,
            dailyStreak: userStats?.dailyStreak ?? 0,
          },
        },
        stats,
      });
    } catch (err) { next(err); }
  },

  // Export
  async exportPdf(req, res, next) {
    try {
      const pdfBuffer = await exportService.generatePdf(parseInt(req.params.id, 10), req.userId);
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', 'attachment; filename="story.pdf"');
      res.send(pdfBuffer);
    } catch (err) { next(err); }
  },

  // Streak
  async updateStreak(req, res, next) {
    try {
      const stats = await levelService.updateStreak(req.userId);
      questService.checkQuestCompletion(req.userId, 'daily_login').catch(() => {});
      achievementService.checkAndUnlock(req.userId, 'streak_updated').catch(() => {});
      res.json({ stats });
    } catch (err) { next(err); }
  },

  // Block
  async blockUser(req, res, next) {
    try {
      await blockService.blockUser(req.userId, parseInt(req.params.userId, 10));
      res.json({ message: 'Kullanıcı engellendi' });
    } catch (err) { next(err); }
  },
  async unblockUser(req, res, next) {
    try {
      await blockService.unblockUser(req.userId, parseInt(req.params.userId, 10));
      res.json({ message: 'Engel kaldırıldı' });
    } catch (err) { next(err); }
  },
  async getBlockedUsers(req, res, next) {
    try {
      const users = await blockService.getBlockedUsers(req.userId);
      res.json({ users });
    } catch (err) { next(err); }
  },

  // Report
  async createReport(req, res, next) {
    try {
      const { targetType, targetId, reason, description } = req.body;
      if (!targetType || !targetId || !reason) {
        return res.status(400).json({ error: 'targetType, targetId ve reason gerekli' });
      }
      const report = await blockService.createReport(req.userId, targetType, parseInt(targetId, 10), reason, description);
      res.status(201).json({ report });
    } catch (err) { next(err); }
  },

  // Bookmarks
  async addBookmark(req, res, next) {
    try {
      const bookmark = await prisma.bookmark.create({
        data: { userId: req.userId, sharedStoryId: parseInt(req.params.id, 10) },
      });
      res.status(201).json({ bookmark });
    } catch (err) { next(err); }
  },
  async removeBookmark(req, res, next) {
    try {
      await prisma.bookmark.deleteMany({
        where: { userId: req.userId, sharedStoryId: parseInt(req.params.id, 10) },
      });
      res.json({ message: 'Yer imi kaldırıldı' });
    } catch (err) { next(err); }
  },
  async getBookmarks(req, res, next) {
    try {
      const bookmarks = await prisma.bookmark.findMany({
        where: { userId: req.userId },
        include: {
          sharedStory: {
            include: {
              story: { select: { id: true, title: true, genre: true } },
              user: { select: { id: true, username: true } },
              _count: { select: { likes: true, comments: true } },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      });
      res.json({ bookmarks });
    } catch (err) { next(err); }
  },

  // === Uploads ===
  async uploadAvatar(req, res, next) {
    try {
      if (!req.file) {
        return res.status(400).json({ error: 'Dosya yüklenmedi' });
      }
      const url = getPublicUrl('avatars', req.file.filename);

      // Delete old avatar if exists
      const user = await prisma.user.findUnique({ where: { id: req.userId }, select: { profileImage: true } });
      if (user?.profileImage && user.profileImage.startsWith('/uploads/')) {
        deleteFile(user.profileImage.replace('/uploads/', ''));
      }

      await prisma.user.update({
        where: { id: req.userId },
        data: { profileImage: url },
      });
      res.json({ url });
    } catch (err) { next(err); }
  },

  async uploadMessageImage(req, res, next) {
    try {
      if (!req.file) {
        return res.status(400).json({ error: 'Dosya yüklenmedi' });
      }
      const url = getPublicUrl('messages', req.file.filename);
      res.json({ url });
    } catch (err) { next(err); }
  },

  // === Device Tokens (FCM) ===
  async registerDeviceToken(req, res, next) {
    try {
      const { token, platform } = req.body;
      if (!token) return res.status(400).json({ error: 'Token gerekli' });
      await pushService.registerToken(req.userId, token, platform || 'android');
      res.json({ message: 'Token kaydedildi' });
    } catch (err) { next(err); }
  },

  async removeDeviceToken(req, res, next) {
    try {
      const { token } = req.body;
      if (!token) return res.status(400).json({ error: 'Token gerekli' });
      await pushService.removeToken(token);
      res.json({ message: 'Token silindi' });
    } catch (err) { next(err); }
  },
};
