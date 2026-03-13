const prisma = require('../config/database');
const pushService = require('./pushService');

async function createNotification(userId, type, title, body, data = {}) {
  const notification = await prisma.notification.create({
    data: { userId, type, title, body, data },
  });

  // Emit via Socket.io
  const { emitToUser } = require('../config/socket');
  emitToUser(userId, 'notification:new', notification);

  // Send push notification
  pushService.sendToUser(userId, { title, body, data: { type, notificationId: notification.id, ...data } });

  return notification;
}

async function getUserNotifications(userId, page = 1, limit = 30) {
  const skip = (page - 1) * limit;
  const [items, total, unreadCount] = await Promise.all([
    prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.notification.count({ where: { userId } }),
    prisma.notification.count({ where: { userId, isRead: false } }),
  ]);

  return { notifications: items, total, unreadCount, page };
}

async function markAsRead(notificationId, userId) {
  const notification = await prisma.notification.findUnique({ where: { id: notificationId } });
  if (!notification || notification.userId !== userId) {
    throw Object.assign(new Error('Bildirim bulunamadı'), { status: 404 });
  }
  const updated = await prisma.notification.update({
    where: { id: notificationId },
    data: { isRead: true },
  });

  const { emitToUser } = require('../config/socket');
  const unreadCount = await prisma.notification.count({ where: { userId, isRead: false } });
  emitToUser(userId, 'notification:read', { unreadCount });

  return updated;
}

async function markAllAsRead(userId) {
  const result = await prisma.notification.updateMany({
    where: { userId, isRead: false },
    data: { isRead: true },
  });

  const { emitToUser } = require('../config/socket');
  emitToUser(userId, 'notification:read', { unreadCount: 0 });

  return result;
}

module.exports = {
  createNotification,
  getUserNotifications,
  markAsRead,
  markAllAsRead,
};
