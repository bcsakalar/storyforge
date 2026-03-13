const prisma = require('../config/database');
const { emitToUser } = require('../config/socket');

async function sendRequest(senderId, receiverUsername) {
  const receiver = await prisma.user.findUnique({
    where: { username: receiverUsername },
    select: { id: true },
  });
  if (!receiver) {
    throw Object.assign(new Error('Kullanıcı bulunamadı'), { status: 404 });
  }
  if (receiver.id === senderId) {
    throw Object.assign(new Error('Kendinize istek gönderemezsiniz'), { status: 400 });
  }

  // Check if friendship already exists in either direction
  const existing = await prisma.friendship.findFirst({
    where: {
      OR: [
        { senderId, receiverId: receiver.id },
        { senderId: receiver.id, receiverId: senderId },
      ],
    },
  });
  if (existing) {
    if (existing.status === 'ACCEPTED') {
      throw Object.assign(new Error('Zaten arkadaşsınız'), { status: 400 });
    }
    if (existing.status === 'PENDING') {
      throw Object.assign(new Error('Zaten bekleyen bir istek var'), { status: 400 });
    }
    // REJECTED — allow re-sending by updating status only (keep original direction)
    if (existing.status === 'REJECTED') {
      const updated = await prisma.friendship.update({
        where: { id: existing.id },
        data: { status: 'PENDING', senderId, receiverId: receiver.id },
        include: {
          sender: { select: { id: true, username: true } },
          receiver: { select: { id: true, username: true } },
        },
      });

      emitToUser(receiver.id, 'friend:request', {
        friendshipId: updated.id,
        sender: updated.sender,
      });

      return updated;
    }
  }

  const friendship = await prisma.friendship.create({
    data: { senderId, receiverId: receiver.id },
    include: {
      sender: { select: { id: true, username: true } },
      receiver: { select: { id: true, username: true } },
    },
  });

  emitToUser(receiver.id, 'friend:request', {
    friendshipId: friendship.id,
    sender: friendship.sender,
  });

  return friendship;
}

async function acceptRequest(friendshipId, userId) {
  const friendship = await prisma.friendship.findUnique({ where: { id: friendshipId } });
  if (!friendship) {
    throw Object.assign(new Error('İstek bulunamadı'), { status: 404 });
  }
  if (friendship.receiverId !== userId) {
    throw Object.assign(new Error('Bu isteği kabul etme yetkiniz yok'), { status: 403 });
  }
  if (friendship.status !== 'PENDING') {
    throw Object.assign(new Error('Bu istek zaten işlenmiş'), { status: 400 });
  }
  const updated = await prisma.friendship.update({
    where: { id: friendshipId },
    data: { status: 'ACCEPTED' },
    include: {
      sender: { select: { id: true, username: true } },
      receiver: { select: { id: true, username: true } },
    },
  });

  emitToUser(updated.senderId, 'friend:accepted', {
    friendshipId: updated.id,
    friend: updated.receiver,
  });

  return updated;
}

async function rejectRequest(friendshipId, userId) {
  const friendship = await prisma.friendship.findUnique({ where: { id: friendshipId } });
  if (!friendship) {
    throw Object.assign(new Error('İstek bulunamadı'), { status: 404 });
  }
  if (friendship.receiverId !== userId) {
    throw Object.assign(new Error('Bu isteği reddetme yetkiniz yok'), { status: 403 });
  }
  if (friendship.status !== 'PENDING') {
    throw Object.assign(new Error('Bu istek zaten işlenmiş'), { status: 400 });
  }
  return prisma.friendship.update({
    where: { id: friendshipId },
    data: { status: 'REJECTED' },
  });
}

async function removeFriend(friendshipId, userId) {
  const friendship = await prisma.friendship.findUnique({ where: { id: friendshipId } });
  if (!friendship) {
    throw Object.assign(new Error('Arkadaşlık bulunamadı'), { status: 404 });
  }
  if (friendship.senderId !== userId && friendship.receiverId !== userId) {
    throw Object.assign(new Error('Bu arkadaşlığı silme yetkiniz yok'), { status: 403 });
  }
  return prisma.friendship.delete({ where: { id: friendshipId } });
}

async function getFriends(userId) {
  const friendships = await prisma.friendship.findMany({
    where: {
      status: 'ACCEPTED',
      OR: [{ senderId: userId }, { receiverId: userId }],
    },
    include: {
      sender: { select: { id: true, username: true, profileImage: true } },
      receiver: { select: { id: true, username: true, profileImage: true } },
    },
    orderBy: { updatedAt: 'desc' },
  });

  return friendships.map((f) => ({
    friendshipId: f.id,
    friend: f.senderId === userId ? f.receiver : f.sender,
  }));
}

async function getPendingRequests(userId) {
  return prisma.friendship.findMany({
    where: { receiverId: userId, status: 'PENDING' },
    include: {
      sender: { select: { id: true, username: true, profileImage: true } },
    },
    orderBy: { createdAt: 'desc' },
  });
}

async function searchUsers(query, currentUserId) {
  if (!query || query.length < 2) return [];
  return prisma.user.findMany({
    where: {
      id: { not: currentUserId },
      username: { contains: query, mode: 'insensitive' },
    },
    select: { id: true, username: true, profileImage: true },
    take: 20,
  });
}

module.exports = {
  sendRequest,
  acceptRequest,
  rejectRequest,
  removeFriend,
  getFriends,
  getPendingRequests,
  searchUsers,
};
