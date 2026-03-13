const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const storyController = require('../controllers/storyController');

// All story web routes require auth
router.use(requireAuth);

// Dashboard
router.get('/dashboard', storyController.showDashboard);

// Story CRUD
router.get('/story/new', storyController.showNewStory);
router.post('/story/new', storyController.createStoryWeb);
router.get('/story/:id', storyController.showStory);
router.post('/story/:id/choose', storyController.makeChoiceWeb);
router.post('/story/:id/delete', storyController.deleteStoryWeb);
router.post('/story/:id/chapter/:chapterNum/tts', storyController.chapterTtsWeb);

// Story extras
router.post('/story/:id/complete', storyController.completeStoryWeb);
router.post('/story/:id/share', storyController.shareStoryWeb);
router.post('/story/:id/unshare', storyController.unshareStoryWeb);
router.get('/story/:id/export/pdf', storyController.exportPdfWeb);
router.get('/story/:id/recap', storyController.getRecapWeb);

// Characters
router.post('/story/:id/characters', storyController.createCharacterWeb);
router.post('/story/:id/characters/:charId/delete', storyController.deleteCharacterWeb);

// Profile & Settings
router.get('/profile', storyController.showProfile);
router.post('/profile/settings', storyController.updateSettingsWeb);

// Explore
router.get('/explore', storyController.showExplore);
router.get('/shared/:id', storyController.showSharedStory);
router.post('/shared/:id/like', storyController.likeStoryWeb);
router.post('/shared/:id/comments', storyController.addCommentWeb);
router.post('/shared/:sharedId/comments/:commentId/delete', storyController.deleteCommentWeb);

// Friends
router.get('/friends', storyController.showFriends);
router.post('/friends/request', storyController.sendFriendRequestWeb);
router.post('/friends/accept/:id', storyController.acceptFriendWeb);
router.post('/friends/reject/:id', storyController.rejectFriendWeb);
router.post('/friends/:id/remove', storyController.removeFriendWeb);

// Messages
router.get('/messages', storyController.showConversations);
router.get('/messages/:userId', storyController.showChat);
router.post('/messages/:userId', storyController.sendMessageWeb);

// Co-op
router.get('/coop', storyController.showCoop);
router.post('/coop/create', storyController.createCoopWeb);
router.post('/coop/:id/join', storyController.joinCoopWeb);
router.post('/coop/:id/reject', storyController.rejectCoopWeb);
router.get('/coop/:id', storyController.showCoopSession);
router.post('/coop/:id/choose', storyController.makeCoopChoiceWeb);
router.post('/coop/:id/share', storyController.shareCoopWeb);
router.get('/coop/:id/export/pdf', storyController.exportCoopPdfWeb);
router.get('/coop/:id/recap', storyController.getCoopRecapWeb);
router.get('/coop/:id/tree', storyController.getCoopTreeWeb);
router.post('/coop/:id/characters', storyController.createCoopCharacterWeb);
router.post('/coop/:id/characters/:charId/delete', storyController.deleteCoopCharacterWeb);

// Achievements & Quests
router.get('/achievements', storyController.showAchievements);
router.get('/quests', storyController.showQuests);
router.post('/quests/:id/claim', storyController.claimQuestWeb);

// Notifications
router.get('/notifications', storyController.showNotifications);
router.post('/notifications/:id/read', storyController.markNotificationReadWeb);
router.post('/notifications/read-all', storyController.markAllNotificationsReadWeb);

module.exports = router;
