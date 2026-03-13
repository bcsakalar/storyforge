const prisma = require('../config/database');

/**
 * Kullanıcıyı engeller.
 */
async function blockUser(blockerId, blockedId) {
  if (blockerId === blockedId) throw new Error('Kendini engelleyemezsin');

  await prisma.block.create({
    data: { blockerId, blockedId },
  });

  // Arkadaşlığı da kaldır
  await prisma.friendship.deleteMany({
    where: {
      OR: [
        { senderId: blockerId, receiverId: blockedId },
        { senderId: blockedId, receiverId: blockerId },
      ],
    },
  });

  return true;
}

/**
 * Engeli kaldırır.
 */
async function unblockUser(blockerId, blockedId) {
  await prisma.block.deleteMany({
    where: { blockerId, blockedId },
  });
  return true;
}

/**
 * Engellenen kullanıcıları listeler.
 */
async function getBlockedUsers(userId) {
  const blocks = await prisma.block.findMany({
    where: { blockerId: userId },
    include: {
      blocked: {
        select: { id: true, username: true, profileImage: true },
      },
    },
    orderBy: { createdAt: 'desc' },
  });
  return blocks.map((b) => b.blocked);
}

/**
 * Kullanıcının engellenip engellenmediğini kontrol eder.
 */
async function isBlocked(userId1, userId2) {
  const block = await prisma.block.findFirst({
    where: {
      OR: [
        { blockerId: userId1, blockedId: userId2 },
        { blockerId: userId2, blockedId: userId1 },
      ],
    },
  });
  return !!block;
}

/**
 * Belirli bir yöndeki engellemeyi kontrol eder.
 */
async function hasBlocked(blockerId, blockedId) {
  const block = await prisma.block.findUnique({
    where: {
      blockerId_blockedId: { blockerId, blockedId },
    },
  });
  return !!block;
}

/**
 * Rapor oluşturur.
 */
async function createReport(reporterId, targetType, targetId, reason, description) {
  return prisma.report.create({
    data: {
      reporterId,
      targetType,
      targetId,
      reason,
      description: description || null,
    },
  });
}

module.exports = {
  blockUser,
  unblockUser,
  getBlockedUsers,
  isBlocked,
  hasBlocked,
  createReport,
};
