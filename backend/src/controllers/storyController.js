const storyService = require('../services/storyService');
const friendService = require('../services/friendService');
const messageService = require('../services/messageService');
const socialService = require('../services/socialService');
const coopService = require('../services/coopService');
const characterService = require('../services/characterService');
const achievementService = require('../services/achievementService');
const levelService = require('../services/levelService');
const questService = require('../services/questService');
const notificationService = require('../services/notificationService');
const exportService = require('../services/exportService');
const { emitToAll } = require('../config/socket');
const prisma = require('../config/database');

const GENRES = [
  { value: 'fantastik', label: 'Fantastik', icon: '🐉', description: 'Büyü, ejderhalar ve destansı maceralar' },
  { value: 'korku', label: 'Korku', icon: '👻', description: 'Gerilim, karanlık ve doğaüstü tehditler' },
  { value: 'bilim_kurgu', label: 'Bilim Kurgu', icon: '🚀', description: 'Uzay, teknoloji ve gelecek senaryoları' },
  { value: 'romantik', label: 'Romantik', icon: '💕', description: 'Aşk, ilişkiler ve duygusal yolculuklar' },
  { value: 'macera', label: 'Macera', icon: '⚔️', description: 'Aksiyon, keşif ve kahramanlık' },
  { value: 'gizem', label: 'Gizem', icon: '🔍', description: 'Sırlar, dedektiflik ve beklenmedik sonlar' },
];

// ============ WEB (EJS) ============

async function showDashboard(req, res, next) {
  try {
    const stories = await storyService.getUserStories(req.session.userId);
    res.render('pages/dashboard', {
      title: 'Hikayelerim',
      user: req.session,
      stories,
    });
  } catch (err) {
    next(err);
  }
}

async function showNewStory(req, res) {
  res.render('pages/newStory', {
    title: 'Yeni Hikaye',
    user: req.session,
    genres: GENRES,
  });
}

async function createStoryWeb(req, res, next) {
  const { genre, mood, language } = req.body;
  try {
    const validGenres = GENRES.map((g) => g.value);
    if (!validGenres.includes(genre)) {
      return res.render('pages/newStory', {
        title: 'Yeni Hikaye',
        user: req.session,
        genres: GENRES,
        error: 'Geçersiz tür seçimi',
      });
    }
    const story = await storyService.createStory(req.session.userId, genre, { mood: mood || undefined, language: language || undefined });
    res.redirect(`/story/${story.id}`);
  } catch (err) {
    next(err);
  }
}

async function showStory(req, res, next) {
  try {
    const storyId = parseInt(req.params.id, 10);
    const story = await storyService.getStoryWithChapters(storyId, req.session.userId);
    if (!story) {
      return res.status(404).render('pages/error', {
        title: 'Bulunamadı',
        message: 'Hikaye bulunamadı',
        user: req.session,
      });
    }
    const characters = await characterService.getCharacters(storyId);
    const shared = await prisma.sharedStory.findFirst({ where: { storyId, userId: req.session.userId } });
    const flashMessage = req.session.flashMessage || null;
    if (flashMessage) delete req.session.flashMessage;
    res.render('pages/story', {
      title: story.title,
      user: req.session,
      story,
      characters,
      isShared: !!shared,
      flashMessage,
    });
  } catch (err) {
    next(err);
  }
}

async function makeChoiceWeb(req, res, next) {
  try {
    const storyId = parseInt(req.params.id, 10);
    const { choiceId } = req.body;
    await storyService.makeChoice(storyId, req.session.userId, parseInt(choiceId, 10));
    res.redirect(`/story/${storyId}`);
  } catch (err) {
    next(err);
  }
}

async function deleteStoryWeb(req, res, next) {
  try {
    const storyId = parseInt(req.params.id, 10);
    await storyService.deleteStory(storyId, req.session.userId);
    res.redirect('/dashboard');
  } catch (err) {
    next(err);
  }
}

async function chapterTtsWeb(req, res, next) {
  try {
    const storyId = parseInt(req.params.id, 10);
    const chapterNum = parseInt(req.params.chapterNum, 10);

    const story = await storyService.getStoryWithChapters(storyId, req.session.userId);
    if (!story) {
      return res.status(404).json({ error: 'Hikaye bulunamadı' });
    }

    const chapter = story.chapters.find((ch) => ch.chapterNumber === chapterNum);
    if (!chapter) {
      return res.status(404).json({ error: 'Bölüm bulunamadı' });
    }

    const geminiService = require('../services/geminiService');
    const pcmBase64 = await geminiService.generateSpeech(chapter.content);
    const wavBase64 = geminiService.pcmToWavBase64(pcmBase64);

    res.json({ audio: wavBase64 });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  showDashboard,
  showNewStory,
  createStoryWeb,
  showStory,
  makeChoiceWeb,
  deleteStoryWeb,
  chapterTtsWeb,
  GENRES,

  // ===== Profile & Settings =====
  async showProfile(req, res, next) {
    try {
      const user = await prisma.user.findUnique({
        where: { id: req.session.userId },
        select: { id: true, username: true, email: true, profileImage: true, theme: true, fontSize: true, language: true, createdAt: true },
      });
      const stats = await levelService.getLevelInfo(req.session.userId);
      const storyCount = await prisma.story.count({ where: { userId: req.session.userId } });
      const completedCount = await prisma.story.count({ where: { userId: req.session.userId, isCompleted: true } });
      const achievements = await achievementService.getUserAchievements(req.session.userId);
      res.render('pages/profile', { title: 'Profil', user: req.session, profile: user, stats, storyCount, completedCount, achievements });
    } catch (err) { next(err); }
  },

  async updateSettingsWeb(req, res, next) {
    try {
      const { theme, fontSize, language } = req.body;
      const data = {};
      if (theme) data.theme = theme;
      if (fontSize) data.fontSize = parseInt(fontSize, 10);
      if (language) data.language = language;
      await prisma.user.update({ where: { id: req.session.userId }, data });
      // Sync to session cache for layout CSS variable
      if (fontSize) req.session.userFontSize = parseInt(fontSize, 10);
      res.redirect('/profile');
    } catch (err) { next(err); }
  },

  // ===== Explore =====
  async showExplore(req, res, next) {
    try {
      const sort = req.query.sort || 'popular';
      const page = parseInt(req.query.page, 10) || 1;
      const result = await socialService.getPublicStories(page, 20, sort);
      // Add hasLiked info  
      for (const s of result.stories) {
        s.hasLiked = await socialService.hasLiked(s.id, req.session.userId);
      }
      res.render('pages/explore', { title: 'Keşfet', user: req.session, stories: result.stories, total: result.total, page: result.page, totalPages: result.totalPages, sort });
    } catch (err) { next(err); }
  },

  async showSharedStory(req, res, next) {
    try {
      const detail = await socialService.getSharedStoryDetail(parseInt(req.params.id, 10), req.session.userId);
      if (!detail) return res.status(404).render('pages/error', { title: 'Bulunamadı', message: 'Paylaşım bulunamadı', user: req.session });
      const comments = await socialService.getComments(detail.id);
      res.render('pages/sharedStory', { title: detail.story.title, user: req.session, shared: detail, comments });
    } catch (err) { next(err); }
  },

  async likeStoryWeb(req, res, next) {
    try {
      const id = parseInt(req.params.id, 10);
      const hasLiked = await socialService.hasLiked(id, req.session.userId);
      if (hasLiked) {
        await socialService.unlikeStory(id, req.session.userId);
      } else {
        await socialService.likeStory(id, req.session.userId);
        const shared = await prisma.sharedStory.findUnique({ where: { id } });
        if (shared && shared.userId !== req.session.userId) {
          notificationService.createNotification(shared.userId, 'like', 'Beğeni', 'Hikayeni birisi beğendi', { sharedStoryId: id }).catch(() => {});
        }
      }
      const likeCount = await prisma.like.count({ where: { sharedStoryId: id } });
      emitToAll('social:like', { sharedStoryId: id, likeCount, userId: req.session.userId });
      res.redirect(`/shared/${id}`);
    } catch (err) { next(err); }
  },

  async addCommentWeb(req, res, next) {
    try {
      const id = parseInt(req.params.id, 10);
      const comment = await socialService.addComment(id, req.session.userId, req.body.content);
      const shared = await prisma.sharedStory.findUnique({ where: { id } });
      if (shared && shared.userId !== req.session.userId) {
        notificationService.createNotification(shared.userId, 'comment', 'Yorum', 'Hikayene yeni bir yorum yapıldı', { sharedStoryId: id }).catch(() => {});
      }
      const commentCount = await prisma.comment.count({ where: { sharedStoryId: id } });
      const user = await prisma.user.findUnique({ where: { id: req.session.userId }, select: { username: true } });
      emitToAll('social:comment', { sharedStoryId: id, commentCount, comment: { ...comment, user: { id: req.session.userId, username: user?.username } } });
      res.redirect(`/shared/${id}`);
    } catch (err) { next(err); }
  },

  async deleteCommentWeb(req, res, next) {
    try {
      await socialService.deleteComment(parseInt(req.params.commentId, 10), req.session.userId);
      res.redirect(`/shared/${req.params.sharedId}`);
    } catch (err) { next(err); }
  },

  async shareStoryWeb(req, res, next) {
    try {
      const result = await socialService.shareStory(parseInt(req.params.id, 10), req.session.userId, true);
      if (result.alreadyShared) {
        // Store flash message in session
        req.session.flashMessage = 'Bu hikaye zaten paylaşılmış.';
        return res.redirect(`/story/${req.params.id}`);
      }
      levelService.addXp(req.session.userId, 'share').catch(() => {});
      questService.checkQuestCompletion(req.session.userId, 'share_story').catch(() => {});
      achievementService.checkAndUnlock(req.session.userId, 'story_shared').catch(() => {});
      res.redirect(`/story/${req.params.id}`);
    } catch (err) { next(err); }
  },

  async unshareStoryWeb(req, res, next) {
    try {
      await socialService.unshareStory(parseInt(req.params.id, 10), req.session.userId);
      res.redirect(`/story/${req.params.id}`);
    } catch (err) { next(err); }
  },

  // ===== Friends =====
  async showFriends(req, res, next) {
    try {
      const friends = await friendService.getFriends(req.session.userId);
      const pending = await friendService.getPendingRequests(req.session.userId);
      const q = req.query.q || '';
      let searchResults = [];
      if (q.length >= 2) {
        searchResults = await friendService.searchUsers(q, req.session.userId);
      }
      res.render('pages/friends', { title: 'Arkadaşlar', user: req.session, friends, pending, searchResults, q });
    } catch (err) { next(err); }
  },

  async sendFriendRequestWeb(req, res, next) {
    try {
      const friendship = await friendService.sendRequest(req.session.userId, req.body.username);
      notificationService.createNotification(friendship.receiverId, 'friend_request', 'Arkadaşlık İsteği', 'Yeni bir arkadaşlık isteği aldın', { senderId: req.session.userId }).catch(() => {});
      res.redirect('/friends');
    } catch (err) { next(err); }
  },

  async acceptFriendWeb(req, res, next) {
    try {
      const friendship = await friendService.acceptRequest(parseInt(req.params.id, 10), req.session.userId);
      achievementService.checkAndUnlock(req.session.userId, 'friend_added').catch(() => {});
      notificationService.createNotification(friendship.senderId, 'friend_accepted', 'Arkadaşlık Kabul Edildi', 'Arkadaşlık isteğin kabul edildi', { friendId: req.session.userId }).catch(() => {});
      res.redirect('/friends');
    } catch (err) { next(err); }
  },

  async rejectFriendWeb(req, res, next) {
    try {
      await friendService.rejectRequest(parseInt(req.params.id, 10), req.session.userId);
      res.redirect('/friends');
    } catch (err) { next(err); }
  },

  async removeFriendWeb(req, res, next) {
    try {
      await friendService.removeFriend(parseInt(req.params.id, 10), req.session.userId);
      res.redirect('/friends');
    } catch (err) { next(err); }
  },

  // ===== Messages =====
  async showConversations(req, res, next) {
    try {
      const conversations = await messageService.getConversations(req.session.userId);
      res.render('pages/conversations', { title: 'Mesajlar', user: req.session, conversations });
    } catch (err) { next(err); }
  },

  async showChat(req, res, next) {
    try {
      const partnerId = parseInt(req.params.userId, 10);
      const messages = await messageService.getMessages(req.session.userId, partnerId);
      await messageService.markAsRead(req.session.userId, partnerId);
      const partner = await prisma.user.findUnique({ where: { id: partnerId }, select: { id: true, username: true } });
      if (!partner) return res.status(404).render('pages/error', { title: 'Bulunamadı', message: 'Kullanıcı bulunamadı', user: req.session });
      res.render('pages/chat', { title: `${partner.username}`, user: req.session, messages, partner, currentUserId: req.session.userId });
    } catch (err) { next(err); }
  },

  async sendMessageWeb(req, res, next) {
    try {
      const partnerId = parseInt(req.params.userId, 10);
      await messageService.sendMessage(req.session.userId, partnerId, req.body.content);
      questService.checkQuestCompletion(req.session.userId, 'send_message').catch(() => {});
      res.redirect(`/messages/${partnerId}`);
    } catch (err) { next(err); }
  },

  // ===== Co-op =====
  async showCoop(req, res, next) {
    try {
      const sessions = await coopService.getUserCoopSessions(req.session.userId);
      const invites = await coopService.getCoopInvites(req.session.userId);
      const friends = await friendService.getFriends(req.session.userId);
      res.render('pages/coop', { title: 'Co-op', user: req.session, sessions, invites, friends, genres: GENRES });
    } catch (err) { next(err); }
  },

  async createCoopWeb(req, res, next) {
    try {
      const session = await coopService.createCoopSession(req.session.userId, req.body.genre, req.body.mood || null, parseInt(req.body.guestUserId, 10));
      notificationService.createNotification(parseInt(req.body.guestUserId, 10), 'coop_invite', 'Co-op Daveti', 'Bir arkadaşın seni hikaye yazmaya davet etti', { sessionId: session.id }).catch(() => {});
      res.redirect(`/coop/${session.id}`);
    } catch (err) { next(err); }
  },

  async joinCoopWeb(req, res, next) {
    try {
      await coopService.joinCoopSession(parseInt(req.params.id, 10), req.session.userId);
      res.redirect(`/coop/${req.params.id}`);
    } catch (err) { next(err); }
  },

  async showCoopSession(req, res, next) {
    try {
      const session = await coopService.getCoopSession(parseInt(req.params.id, 10), req.session.userId);
      if (!session) return res.status(404).render('pages/error', { title: 'Bulunamadı', message: 'Oturum bulunamadı', user: req.session });
      const flashMessage = req.session.flashMessage || null;
      req.session.flashMessage = null;
      res.render('pages/coopSession', { title: 'Co-op Hikaye', user: req.session, session, currentUserId: req.session.userId, flashMessage });
    } catch (err) { next(err); }
  },

  async makeCoopChoiceWeb(req, res, next) {
    try {
      await coopService.makeCoopChoice(parseInt(req.params.id, 10), req.session.userId, parseInt(req.body.choiceId, 10));
      levelService.addXp(req.session.userId, 'coop').catch(() => {});
      res.redirect(`/coop/${req.params.id}`);
    } catch (err) { next(err); }
  },

  async rejectCoopWeb(req, res, next) {
    try {
      await coopService.rejectCoopSession(parseInt(req.params.id, 10), req.session.userId);
      res.redirect('/coop');
    } catch (err) { next(err); }
  },

  async completeCoopWeb(req, res, next) {
    try {
      await coopService.completeCoopStory(parseInt(req.params.id, 10), req.session.userId);
      res.redirect(`/coop/${req.params.id}`);
    } catch (err) { next(err); }
  },

  async shareCoopWeb(req, res, next) {
    try {
      const result = await coopService.shareCoopStory(parseInt(req.params.id, 10), req.session.userId);
      if (result.alreadyShared) {
        req.session.flashMessage = 'Bu hikaye zaten paylaşılmış.';
      } else {
        req.session.flashMessage = 'Hikaye başarıyla paylaşıldı!';
      }
      res.redirect(`/coop/${req.params.id}`);
    } catch (err) { next(err); }
  },

  async exportCoopPdfWeb(req, res, next) {
    try {
      const pdfBuffer = await exportService.generateCoopPdf(parseInt(req.params.id, 10), req.session.userId);
      res.set({ 'Content-Type': 'application/pdf', 'Content-Disposition': 'attachment; filename="coop-story.pdf"' });
      res.send(pdfBuffer);
    } catch (err) { next(err); }
  },

  async getCoopRecapWeb(req, res, next) {
    try {
      const { recap } = await coopService.getCoopRecap(parseInt(req.params.id, 10), req.session.userId);
      res.json({ recap });
    } catch (err) { next(err); }
  },

  async getCoopTreeWeb(req, res, next) {
    try {
      const tree = await coopService.getCoopStoryTree(parseInt(req.params.id, 10), req.session.userId);
      res.json(tree);
    } catch (err) { next(err); }
  },

  async createCoopCharacterWeb(req, res, next) {
    try {
      await coopService.addCoopCharacter(parseInt(req.params.id, 10), req.session.userId, {
        name: req.body.name,
        personality: req.body.personality || '',
        appearance: req.body.appearance || '',
      });
      res.redirect(`/coop/${req.params.id}`);
    } catch (err) { next(err); }
  },

  async deleteCoopCharacterWeb(req, res, next) {
    try {
      await coopService.deleteCoopCharacter(parseInt(req.params.id, 10), parseInt(req.params.charId, 10), req.session.userId);
      res.redirect(`/coop/${req.params.id}`);
    } catch (err) { next(err); }
  },

  // ===== Achievements =====
  async showAchievements(req, res, next) {
    try {
      const unlocked = await achievementService.getUserAchievements(req.session.userId);
      const all = await achievementService.getAvailableAchievements();
      const unlockedKeys = unlocked.map(a => a.achievement ? a.achievement.key : a.key);
      res.render('pages/achievements', { title: 'Başarımlar', user: req.session, all, unlockedKeys });
    } catch (err) { next(err); }
  },

  // ===== Daily Quests =====
  async showQuests(req, res, next) {
    try {
      const quests = await questService.getUserQuests(req.session.userId);
      const stats = await levelService.getLevelInfo(req.session.userId);
      res.render('pages/quests', { title: 'Günlük Görevler', user: req.session, quests, stats });
    } catch (err) { next(err); }
  },

  async claimQuestWeb(req, res, next) {
    try {
      await questService.claimQuestReward(parseInt(req.params.id, 10), req.session.userId);
      res.redirect('/quests');
    } catch (err) { next(err); }
  },

  // ===== Notifications =====
  async showNotifications(req, res, next) {
    try {
      const result = await notificationService.getUserNotifications(req.session.userId);
      res.render('pages/notifications', { title: 'Bildirimler', user: req.session, notifications: result.notifications });
    } catch (err) { next(err); }
  },

  async markNotificationReadWeb(req, res, next) {
    try {
      await notificationService.markAsRead(parseInt(req.params.id, 10), req.session.userId);
      res.redirect('/notifications');
    } catch (err) { next(err); }
  },

  async markAllNotificationsReadWeb(req, res, next) {
    try {
      await notificationService.markAllAsRead(req.session.userId);
      res.redirect('/notifications');
    } catch (err) { next(err); }
  },

  // ===== Story extras =====
  async completeStoryWeb(req, res, next) {
    try {
      const storyId = parseInt(req.params.id, 10);
      const story = await storyService.completeStory(storyId, req.session.userId);
      levelService.addXp(req.session.userId, 'story').catch(() => {});
      levelService.incrementStoriesCompleted(req.session.userId, story.genre).catch(() => {});
      questService.checkQuestCompletion(req.session.userId, 'complete_story').catch(() => {});
      achievementService.checkAndUnlock(req.session.userId, 'story_completed').catch(() => {});
      res.redirect(`/story/${storyId}`);
    } catch (err) { next(err); }
  },

  async exportPdfWeb(req, res, next) {
    try {
      const pdfBuffer = await exportService.generatePdf(parseInt(req.params.id, 10), req.session.userId);
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', 'attachment; filename="story.pdf"');
      res.send(pdfBuffer);
    } catch (err) { next(err); }
  },

  async getRecapWeb(req, res, next) {
    try {
      const recap = await storyService.getRecap(parseInt(req.params.id, 10), req.session.userId);
      res.json({ recap });
    } catch (err) { next(err); }
  },

  // ===== Characters =====
  async createCharacterWeb(req, res, next) {
    try {
      const { name, personality, appearance } = req.body;
      if (!name) return res.redirect(`/story/${req.params.id}`);
      await characterService.createCharacter(parseInt(req.params.id, 10), req.session.userId, { name, personality, appearance });
      res.redirect(`/story/${req.params.id}`);
    } catch (err) { next(err); }
  },

  async deleteCharacterWeb(req, res, next) {
    try {
      await characterService.deleteCharacter(parseInt(req.params.charId, 10), req.session.userId);
      res.redirect(`/story/${req.params.id}`);
    } catch (err) { next(err); }
  },
};
