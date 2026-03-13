const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const cookie = require('cookie');
const signature = require('cookie-signature');
const storyService = require('../services/storyService');
const levelService = require('../services/levelService');
const questService = require('../services/questService');
const achievementService = require('../services/achievementService');

let io = null;
const onlineUsers = new Map(); // userId → Set<socketId>

function initSocket(httpServer, sessionStore) {
  io = new Server(httpServer, {
    cors: {
      origin: process.env.NODE_ENV === 'production'
        ? ['https://storyforge.berkecansakalar.com']
        : '*',
      methods: ['GET', 'POST'],
      credentials: true,
    },
    pingTimeout: 60000,
    pingInterval: 25000,
  });

  // Auth middleware: support both JWT (mobile) and session cookie (web)
  io.use((socket, next) => {
    // 1) Try JWT token first (mobile)
    const token = socket.handshake.auth?.token;
    if (token) {
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] });
        socket.userId = decoded.userId;
        return next();
      } catch {
        // fall through to session auth
      }
    }

    // 2) Try session cookie (web)
    const cookieHeader = socket.handshake.headers.cookie;
    if (cookieHeader && sessionStore) {
      const cookies = cookie.parse(cookieHeader);
      let sid = cookies['connect.sid'];
      if (sid) {
        // Unsigned the cookie value
        if (sid.startsWith('s:')) {
          sid = signature.unsign(sid.slice(2), process.env.SESSION_SECRET);
          if (sid === false) {
            return next(new Error('Geçersiz session'));
          }
        }
        sessionStore.get(sid, (err, session) => {
          if (err || !session || !session.userId) {
            return next(new Error('Yetkilendirme gerekli'));
          }
          socket.userId = session.userId;
          next();
        });
        return;
      }
    }

    return next(new Error('Yetkilendirme gerekli'));
  });

  io.on('connection', (socket) => {
    const userId = socket.userId;

    // Join user's personal room
    socket.join(`user:${userId}`);

    // Track online status
    if (!onlineUsers.has(userId)) {
      onlineUsers.set(userId, new Set());
    }
    onlineUsers.get(userId).add(socket.id);
    // Broadcast online status to all (first connection only)
    if (onlineUsers.get(userId).size === 1) {
      socket.broadcast.emit('user:online', { userId });
    }
    // Send current online user list to this socket
    socket.emit('user:onlineList', { userIds: Array.from(onlineUsers.keys()) });

    socket.on('coop:join', (sessionId) => {
      socket.join(`coop:${sessionId}`);
    });

    socket.on('coop:leave', (sessionId) => {
      socket.leave(`coop:${sessionId}`);
    });

    // Chat: join a chat room with a partner
    socket.on('chat:join', (partnerId) => {
      const roomId = getChatRoom(userId, partnerId);
      socket.join(roomId);
    });

    socket.on('chat:leave', (partnerId) => {
      const roomId = getChatRoom(userId, partnerId);
      socket.leave(roomId);
    });

    // Typing indicators
    socket.on('typing:start', (partnerId) => {
      const roomId = getChatRoom(userId, partnerId);
      socket.to(roomId).emit('typing:start', { userId });
    });

    socket.on('typing:stop', (partnerId) => {
      const roomId = getChatRoom(userId, partnerId);
      socket.to(roomId).emit('typing:stop', { userId });
    });

    // Story streaming
    socket.on('story:createStream', async (data) => {
      try {
        const { genre, mood, language } = data;
        const story = await storyService.createStoryStream(
          userId, genre, { mood, language },
          (chunk) => socket.emit('story:chunk', { text: chunk }),
        );

        levelService.addXp(userId, 'story').catch(() => {});
        questService.checkQuestCompletion(userId, 'create_story').catch(() => {});
        achievementService.checkAndUnlock(userId, 'story_created').catch(() => {});

        socket.emit('story:complete', { story });
      } catch (err) {
        socket.emit('story:error', { error: err.message || 'Hikaye oluşturulamadı' });
      }
    });

    socket.on('story:chooseStream', async (data) => {
      try {
        const { storyId, choiceId, imageBase64 } = data;
        const story = await storyService.makeChoiceStream(
          storyId, userId, parseInt(choiceId, 10), imageBase64 || null,
          (chunk) => socket.emit('story:chunk', { text: chunk, storyId }),
        );

        levelService.addXp(userId, 'chapter').catch(() => {});
        questService.checkQuestCompletion(userId, 'complete_chapter').catch(() => {});
        achievementService.checkAndUnlock(userId, 'chapter_completed').catch(() => {});

        socket.emit('story:complete', { story, storyId });
      } catch (err) {
        socket.emit('story:error', { error: err.message || 'Devam ettirilemedi', storyId: data?.storyId });
      }
    });

    socket.on('disconnect', () => {
      // Remove from online tracking
      const sockets = onlineUsers.get(userId);
      if (sockets) {
        sockets.delete(socket.id);
        if (sockets.size === 0) {
          onlineUsers.delete(userId);
          io.emit('user:offline', { userId });
        }
      }
    });
  });

  return io;
}

function getChatRoom(userId1, userId2) {
  const sorted = [userId1, userId2].sort((a, b) => a - b);
  return `chat:${sorted[0]}:${sorted[1]}`;
}

function getIO() {
  if (!io) {
    throw new Error('Socket.io henüz başlatılmadı');
  }
  return io;
}

function emitToUser(userId, event, data) {
  try {
    const s = getIO();
    s.to(`user:${userId}`).emit(event, data);
  } catch {
    // Socket not initialized yet
  }
}

function emitToRoom(room, event, data) {
  try {
    const s = getIO();
    s.to(room).emit(event, data);
  } catch {
    // Socket not initialized yet
  }
}

function emitToAll(event, data) {
  try {
    const s = getIO();
    s.emit(event, data);
  } catch {
    // Socket not initialized yet
  }
}

function isUserOnline(userId) {
  return onlineUsers.has(userId);
}

function getOnlineUserIds() {
  return Array.from(onlineUsers.keys());
}

module.exports = { initSocket, getIO, emitToUser, emitToRoom, emitToAll, getChatRoom, isUserOnline, getOnlineUserIds };
