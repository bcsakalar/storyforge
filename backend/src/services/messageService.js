const prisma = require('../config/database');
const { emitToUser, emitToRoom, getChatRoom } = require('../config/socket');

async function getConversations(userId) {
  // Get blocked user IDs
  const blocks = await prisma.block.findMany({
    where: { OR: [{ blockerId: userId }, { blockedId: userId }] },
    select: { blockerId: true, blockedId: true },
  });
  const blockedIds = new Set(blocks.map(b => b.blockerId === userId ? b.blockedId : b.blockerId));

  // Get latest message per conversation partner
  const messages = await prisma.message.findMany({
    where: { OR: [{ senderId: userId }, { receiverId: userId }] },
    orderBy: { createdAt: 'desc' },
    include: {
      sender: { select: { id: true, username: true, profileImage: true } },
      receiver: { select: { id: true, username: true, profileImage: true } },
    },
  });

  // Group by conversation partner, take latest
  const convMap = new Map();
  for (const msg of messages) {
    const partnerId = msg.senderId === userId ? msg.receiverId : msg.senderId;
    if (blockedIds.has(partnerId)) continue;
    if (!convMap.has(partnerId)) {
      const partner = msg.senderId === userId ? msg.receiver : msg.sender;
      const unreadCount = await prisma.message.count({
        where: { senderId: partnerId, receiverId: userId, isRead: false },
      });
      convMap.set(partnerId, {
        partner,
        lastMessage: { id: msg.id, content: msg.content, createdAt: msg.createdAt, isOwn: msg.senderId === userId },
        unreadCount,
      });
    }
  }

  return Array.from(convMap.values());
}

async function getMessages(userId, partnerId, cursor, limit = 30) {
  const where = {
    OR: [
      { senderId: userId, receiverId: partnerId },
      { senderId: partnerId, receiverId: userId },
    ],
  };
  if (cursor) {
    where.id = { lt: cursor };
  }

  return prisma.message.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    take: limit,
    include: {
      sender: { select: { id: true, username: true } },
    },
  });
}

async function sendMessage(senderId, receiverId, content, { messageType = 'text', imageUrl } = {}) {
  if (messageType === 'text') {
    if (!content || content.trim().length === 0) {
      throw Object.assign(new Error('Mesaj boş olamaz'), { status: 400 });
    }
    if (content.length > 2000) {
      throw Object.assign(new Error('Mesaj çok uzun (max 2000 karakter)'), { status: 400 });
    }
  }

  // Check block relationship
  const block = await prisma.block.findFirst({
    where: { OR: [{ blockerId: senderId, blockedId: receiverId }, { blockerId: receiverId, blockedId: senderId }] },
  });
  if (block) {
    throw Object.assign(new Error('Bu kullanıcıya mesaj gönderemezsiniz'), { status: 403 });
  }

  const data = {
    senderId,
    receiverId,
    content: messageType === 'image' ? (content || '📷 Fotoğraf') : content.trim(),
    messageType,
  };
  if (imageUrl) data.imageUrl = imageUrl;

  const message = await prisma.message.create({
    data,
    include: {
      sender: { select: { id: true, username: true } },
    },
  });

  // Real-time: emit to chat room and receiver
  const roomId = getChatRoom(senderId, receiverId);
  emitToRoom(roomId, 'message:new', message);
  emitToUser(receiverId, 'message:notification', {
    senderId,
    senderUsername: message.sender.username,
    content: content.trim().substring(0, 60),
  });

  return message;
}

async function markAsRead(userId, partnerId) {
  const result = await prisma.message.updateMany({
    where: { senderId: partnerId, receiverId: userId, isRead: false },
    data: { isRead: true },
  });

  // Notify the partner that their messages were read
  if (result.count > 0) {
    const roomId = getChatRoom(userId, partnerId);
    emitToRoom(roomId, 'message:read', {
      readBy: userId,
      partnerId,
    });
  }

  return result;
}

module.exports = {
  getConversations,
  getMessages,
  sendMessage,
  markAsRead,
};
