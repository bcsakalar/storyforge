const prisma = require('../config/database');

async function shareStory(storyId, userId, isPublic = false) {
  const story = await prisma.story.findFirst({
    where: { id: storyId, userId, isActive: true },
  });
  if (!story) {
    throw Object.assign(new Error('Hikaye bulunamadı'), { status: 404 });
  }

  // Check if already shared
  const existing = await prisma.sharedStory.findUnique({
    where: { storyId_userId: { storyId, userId } },
  });
  if (existing) {
    return { alreadyShared: true, shared: existing };
  }

  const shared = await prisma.sharedStory.create({
    data: { storyId, userId, isPublic },
    include: {
      story: { select: { id: true, title: true, genre: true, mood: true } },
      user: { select: { id: true, username: true } },
      _count: { select: { likes: true, comments: true } },
    },
  });
  return { alreadyShared: false, shared };
}

async function unshareStory(sharedStoryId, userId) {
  const shared = await prisma.sharedStory.findUnique({ where: { id: sharedStoryId } });
  if (!shared || shared.userId !== userId) {
    throw Object.assign(new Error('Paylaşım bulunamadı'), { status: 404 });
  }
  return prisma.sharedStory.delete({ where: { id: sharedStoryId } });
}

async function getPublicStories(page = 1, limit = 20, sort = 'popular', { search, genre, requesterId } = {}) {
  const skip = (page - 1) * limit;
  const orderBy = sort === 'popular'
    ? { likes: { _count: 'desc' } }
    : { createdAt: 'desc' };

  const where = { isPublic: true };
  if (search || genre) {
    where.story = {};
    if (search) {
      where.story.title = { contains: search, mode: 'insensitive' };
    }
    if (genre) {
      where.story.genre = genre;
    }
  }

  // Filter out blocked users' stories
  if (requesterId) {
    const blocks = await prisma.block.findMany({
      where: { OR: [{ blockerId: requesterId }, { blockedId: requesterId }] },
      select: { blockerId: true, blockedId: true },
    });
    const blockedIds = [...new Set(blocks.map(b => b.blockerId === requesterId ? b.blockedId : b.blockerId))];
    if (blockedIds.length > 0) {
      where.userId = { notIn: blockedIds };
    }
  }

  const [items, total] = await Promise.all([
    prisma.sharedStory.findMany({
      where,
      include: {
        story: {
          select: {
            id: true, title: true, genre: true, mood: true,
            summary: true, isActive: true, isCompleted: true,
            userId: true, createdAt: true, updatedAt: true,
            chapters: { select: { id: true }, orderBy: { chapterNumber: 'asc' } },
          },
        },
        user: { select: { id: true, username: true, profileImage: true } },
        _count: { select: { likes: true, comments: true } },
      },
      orderBy,
      skip,
      take: limit,
    }),
    prisma.sharedStory.count({ where }),
  ]);

  return {
    stories: items.map((s) => {
      const { chapters, ...storyRest } = s.story;
      return {
        ...s,
        story: { ...storyRest, chapterCount: chapters.length },
      };
    }),
    total,
    page,
    totalPages: Math.ceil(total / limit),
  };
}

async function getFeed(userId, page = 1, limit = 20) {
  // Get friend IDs
  const friendships = await prisma.friendship.findMany({
    where: {
      status: 'ACCEPTED',
      OR: [{ senderId: userId }, { receiverId: userId }],
    },
    select: { senderId: true, receiverId: true },
  });
  const friendIds = friendships.map((f) =>
    f.senderId === userId ? f.receiverId : f.senderId
  );

  const skip = (page - 1) * limit;

  const [items, total] = await Promise.all([
    prisma.sharedStory.findMany({
      where: { userId: { in: friendIds } },
      include: {
        story: { select: { id: true, title: true, genre: true, mood: true } },
        user: { select: { id: true, username: true, profileImage: true } },
        _count: { select: { likes: true, comments: true } },
      },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.sharedStory.count({ where: { userId: { in: friendIds } } }),
  ]);

  return { stories: items, total, page, totalPages: Math.ceil(total / limit) };
}

async function likeStory(sharedStoryId, userId) {
  const shared = await prisma.sharedStory.findUnique({ where: { id: sharedStoryId } });
  if (!shared) {
    throw Object.assign(new Error('Paylaşım bulunamadı'), { status: 404 });
  }
  return prisma.like.upsert({
    where: { userId_sharedStoryId: { userId, sharedStoryId } },
    update: {},
    create: { userId, sharedStoryId },
  });
}

async function unlikeStory(sharedStoryId, userId) {
  return prisma.like.delete({
    where: { userId_sharedStoryId: { userId, sharedStoryId } },
  });
}

async function hasLiked(sharedStoryId, userId) {
  const like = await prisma.like.findUnique({
    where: { userId_sharedStoryId: { userId, sharedStoryId } },
  });
  return !!like;
}

async function getComments(sharedStoryId, page = 1, limit = 30) {
  const skip = (page - 1) * limit;
  return prisma.comment.findMany({
    where: { sharedStoryId },
    include: {
      user: { select: { id: true, username: true, profileImage: true } },
    },
    orderBy: { createdAt: 'asc' },
    skip,
    take: limit,
  });
}

async function addComment(sharedStoryId, userId, content) {
  if (!content || content.trim().length === 0) {
    throw Object.assign(new Error('Yorum boş olamaz'), { status: 400 });
  }
  if (content.length > 1000) {
    throw Object.assign(new Error('Yorum çok uzun (max 1000 karakter)'), { status: 400 });
  }
  const shared = await prisma.sharedStory.findUnique({ where: { id: sharedStoryId } });
  if (!shared) {
    throw Object.assign(new Error('Paylaşım bulunamadı'), { status: 404 });
  }
  return prisma.comment.create({
    data: { userId, sharedStoryId, content: content.trim() },
    include: {
      user: { select: { id: true, username: true, profileImage: true } },
    },
  });
}

async function deleteComment(commentId, userId) {
  const comment = await prisma.comment.findUnique({ where: { id: commentId } });
  if (!comment || comment.userId !== userId) {
    throw Object.assign(new Error('Yorum bulunamadı veya yetkiniz yok'), { status: 403 });
  }
  return prisma.comment.delete({ where: { id: commentId } });
}

async function getSharedStoryDetail(sharedStoryId, viewerUserId) {
  const shared = await prisma.sharedStory.findUnique({
    where: { id: sharedStoryId },
    include: {
      story: {
        include: {
          chapters: { orderBy: { chapterNumber: 'asc' } },
        },
      },
      user: { select: { id: true, username: true, profileImage: true } },
      _count: { select: { likes: true, comments: true } },
    },
  });
  if (!shared) {
    throw Object.assign(new Error('Paylaşım bulunamadı'), { status: 404 });
  }
  const liked = viewerUserId ? await hasLiked(sharedStoryId, viewerUserId) : false;
  return { ...shared, liked };
}

module.exports = {
  shareStory,
  unshareStory,
  getPublicStories,
  getFeed,
  likeStory,
  unlikeStory,
  hasLiked,
  getComments,
  addComment,
  deleteComment,
  getSharedStoryDetail,
};
