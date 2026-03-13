const express = require('express');
const router = express.Router();
const { requireApiAuth } = require('../middleware/auth');
const { sanitizeBody } = require('../middleware/sanitize');
const authController = require('../controllers/authController');
const apiController = require('../controllers/apiController');
const { avatarUpload, messageUpload } = require('../config/upload');

// Auth endpoints (public)
router.post('/auth/register', sanitizeBody(['username', 'email']), authController.apiRegister);
router.post('/auth/login', authController.apiLogin);

// Protected endpoints
router.use(requireApiAuth);

// Auth
router.get('/auth/me', authController.apiGetMe);

// Genres
router.get('/genres', apiController.getGenres);

// Stories
router.get('/stories', apiController.getStories);
router.post('/stories', apiController.createStory);
router.get('/stories/public', apiController.getPublicStories);
router.get('/stories/feed', apiController.getFeed);
router.get('/stories/:id', apiController.getStory);
router.post('/stories/:id/choose', apiController.makeChoice);
router.delete('/stories/:id', apiController.deleteStory);
router.post('/stories/:id/chapters/:chapterNum/tts', apiController.chapterTts);
router.get('/stories/:id/tree', apiController.getStoryTree);
router.post('/stories/:id/branch/:chapterId', apiController.branchFromChapter);
router.get('/stories/:id/recap', apiController.getRecap);
router.post('/stories/:id/complete', apiController.completeStory);
router.get('/stories/:id/download', apiController.downloadStory);
router.post('/stories/:id/share', apiController.shareStory);
router.delete('/stories/:id/share', apiController.unshareStory);
router.post('/stories/:id/export/pdf', apiController.exportPdf);

// Characters
router.post('/stories/:id/characters', sanitizeBody(['name', 'personality', 'appearance', 'role', 'backstory']), apiController.createCharacter);
router.get('/stories/:id/characters', apiController.getCharacters);
router.put('/characters/:charId', sanitizeBody(['name', 'personality', 'appearance', 'role', 'backstory']), apiController.updateCharacter);
router.delete('/characters/:charId', apiController.deleteCharacter);

// Shared story interactions
router.get('/shared/:id', apiController.getSharedStoryDetail);
router.post('/shared/:id/like', apiController.likeStory);
router.delete('/shared/:id/like', apiController.unlikeStory);
router.get('/shared/:id/comments', apiController.getComments);
router.post('/shared/:id/comments', sanitizeBody(['content']), apiController.addComment);
router.delete('/comments/:commentId', apiController.deleteComment);

// Friends
router.get('/users/search', apiController.searchUsers);
router.get('/friends', apiController.getFriends);
router.get('/friends/pending', apiController.getPendingRequests);
router.post('/friends/request', apiController.sendFriendRequest);
router.post('/friends/accept/:id', apiController.acceptFriendRequest);
router.post('/friends/reject/:id', apiController.rejectFriendRequest);
router.delete('/friends/:id', apiController.removeFriend);

// Messages
router.get('/messages/conversations', apiController.getConversations);
router.get('/messages/:userId', apiController.getMessages);
router.post('/messages/:userId', sanitizeBody(['content']), apiController.sendMessage);
router.put('/messages/:userId/read', apiController.markMessagesRead);

// Co-op
router.post('/coop/create', apiController.createCoopSession);
router.get('/coop/invites', apiController.getCoopInvites);
router.get('/coop/sessions', apiController.getUserCoopSessions);
router.post('/coop/:id/join', apiController.joinCoopSession);
router.post('/coop/:id/reject', apiController.rejectCoopSession);
router.get('/coop/:id', apiController.getCoopSession);
router.post('/coop/:id/choose', apiController.makeCoopChoice);
router.post('/coop/:id/share', apiController.shareCoopStory);
router.post('/coop/:id/export/pdf', apiController.exportCoopPdf);
router.get('/coop/:id/recap', apiController.getCoopRecap);
router.get('/coop/:id/tree', apiController.getCoopStoryTree);
router.post('/coop/:id/characters', apiController.createCoopCharacter);
router.get('/coop/:id/characters', apiController.getCoopCharacters);
router.delete('/coop/:id/characters/:charId', apiController.deleteCoopCharacter);

// Achievements
router.get('/achievements', apiController.getAchievements);
router.get('/achievements/all', apiController.getAvailableAchievements);

// Level & XP
router.get('/level', apiController.getLevelInfo);

// Quests
router.get('/quests/daily', apiController.getDailyQuests);
router.post('/quests/:id/claim', apiController.claimQuestReward);

// Notifications
router.get('/notifications', apiController.getNotifications);
router.put('/notifications/:id/read', apiController.markNotificationRead);
router.put('/notifications/read-all', apiController.markAllNotificationsRead);

// User
router.get('/profile', apiController.getUserProfile);
router.get('/user/profile', apiController.getUserProfile);
router.put('/user/settings', sanitizeBody(['theme', 'language']), apiController.updateSettings);
router.post('/user/push-token', apiController.registerPushToken);
router.post('/user/streak', apiController.updateStreak);

// Block
router.post('/users/:userId/block', apiController.blockUser);
router.delete('/users/:userId/block', apiController.unblockUser);
router.get('/users/blocked', apiController.getBlockedUsers);

// Report
router.post('/reports', sanitizeBody(['description']), apiController.createReport);

// Bookmarks
router.post('/bookmarks/:id', apiController.addBookmark);
router.delete('/bookmarks/:id', apiController.removeBookmark);
router.get('/bookmarks', apiController.getBookmarks);

// Uploads
router.post('/upload/avatar', avatarUpload.single('avatar'), apiController.uploadAvatar);
router.post('/upload/message-image', messageUpload.single('image'), apiController.uploadMessageImage);

// Device Tokens (FCM)
router.post('/device-token', apiController.registerDeviceToken);
router.delete('/device-token', apiController.removeDeviceToken);

module.exports = router;
