const prisma = require('../config/database');
const geminiService = require('./geminiService');
const { emitToUser, emitToRoom } = require('../config/socket');

const MAX_CHARACTERS_PER_USER = 5;

const SESSION_INCLUDE = {
  story: {
    include: {
      chapters: { orderBy: { chapterNumber: 'asc' } },
      characters: { include: { user: { select: { id: true, username: true } } } },
    },
  },
  host: { select: { id: true, username: true } },
  guest: { select: { id: true, username: true } },
};

function assertAccess(session, userId) {
  if (session.hostUserId !== userId && session.guestUserId !== userId) {
    throw Object.assign(new Error('Bu oturuma erişiminiz yok'), { status: 403 });
  }
}

async function createCoopSession(hostUserId, genre, mood, guestUserId) {
  const friendship = await prisma.friendship.findFirst({
    where: {
      status: 'ACCEPTED',
      OR: [
        { senderId: hostUserId, receiverId: guestUserId },
        { senderId: guestUserId, receiverId: hostUserId },
      ],
    },
  });
  if (!friendship) {
    throw Object.assign(new Error('Bu kullanıcıyla arkadaş değilsiniz'), { status: 400 });
  }

  const result = await geminiService.startNewStory(genre, { mood });
  const parsed = result.storyData;

  const story = await prisma.story.create({
    data: {
      userId: hostUserId,
      title: parsed.storyText.substring(0, 80),
      genre,
      mood: mood || null,
      summary: parsed.chapterSummary || '',
      interactionId: result.interactionId,
      chapters: {
        create: {
          chapterNumber: 1,
          content: parsed.storyText,
          choices: parsed.choices,
          interactionId: result.interactionId || 'coop-init',
          summary: parsed.chapterSummary || null,
        },
      },
    },
    include: { chapters: true },
  });

  const session = await prisma.coopSession.create({
    data: {
      storyId: story.id,
      hostUserId,
      guestUserId,
      status: 'WAITING',
    },
    include: SESSION_INCLUDE,
  });

  emitToUser(guestUserId, 'coop:invite', {
    sessionId: session.id,
    host: session.host,
    genre,
  });

  return session;
}

async function joinCoopSession(sessionId, userId) {
  const session = await prisma.coopSession.findUnique({
    where: { id: sessionId },
    include: SESSION_INCLUDE,
  });
  if (!session) {
    throw Object.assign(new Error('Oturum bulunamadı'), { status: 404 });
  }
  if (session.guestUserId !== userId) {
    throw Object.assign(new Error('Bu oturuma katılma yetkiniz yok'), { status: 403 });
  }
  if (session.status !== 'WAITING') {
    throw Object.assign(new Error('Bu oturum zaten başlamış'), { status: 400 });
  }

  const updated = await prisma.coopSession.update({
    where: { id: sessionId },
    data: { status: 'ACTIVE' },
    include: SESSION_INCLUDE,
  });

  // Notify host that guest accepted
  emitToUser(session.hostUserId, 'coop:accepted', {
    sessionId,
    guest: updated.guest,
  });
  emitToRoom(`coop:${sessionId}`, 'coop:statusChange', {
    sessionId,
    status: 'ACTIVE',
  });

  return updated;
}

async function rejectCoopSession(sessionId, userId) {
  const session = await prisma.coopSession.findUnique({
    where: { id: sessionId },
  });
  if (!session) {
    throw Object.assign(new Error('Oturum bulunamadı'), { status: 404 });
  }
  if (session.guestUserId !== userId) {
    throw Object.assign(new Error('Bu daveti reddetme yetkiniz yok'), { status: 403 });
  }
  if (session.status !== 'WAITING') {
    throw Object.assign(new Error('Bu davet artık geçerli değil'), { status: 400 });
  }

  await prisma.coopSession.update({
    where: { id: sessionId },
    data: { status: 'REJECTED' },
  });

  emitToUser(session.hostUserId, 'coop:rejected', {
    sessionId,
    guestUserId: userId,
  });

  return { success: true };
}

async function makeCoopChoice(sessionId, userId, choiceId) {
  // Use interactive transaction for turn validation to prevent race conditions
  return prisma.$transaction(async (tx) => {
    const session = await tx.coopSession.findUnique({
      where: { id: sessionId },
      include: SESSION_INCLUDE,
    });

    if (!session) {
      throw Object.assign(new Error('Oturum bulunamadı'), { status: 404 });
    }
    if (session.status !== 'ACTIVE') {
      throw Object.assign(new Error('Oturum aktif değil'), { status: 400 });
    }

    const isHost = session.hostUserId === userId;
    const isGuest = session.guestUserId === userId;
    if (!isHost && !isGuest) {
      throw Object.assign(new Error('Bu oturumda değilsiniz'), { status: 403 });
    }
    const expectedTurn = session.currentTurn;
    if ((expectedTurn === 1 && !isHost) || (expectedTurn === 2 && !isGuest)) {
      throw Object.assign(new Error('Sıra sizde değil'), { status: 400 });
    }

    const chapters = session.story.chapters;
    const lastChapter = chapters[chapters.length - 1];
    const choices = lastChapter.choices;
    const selectedChoice = choices.find((c) => c.id === choiceId);
    if (!selectedChoice) {
      throw Object.assign(new Error('Geçersiz seçim'), { status: 400 });
    }

    const recentChapters = chapters.slice(-5);
    const characters = session.story.characters || [];

    const nextChapter = await geminiService.continueStory(
      session.story.genre,
      session.story.summary,
      recentChapters,
      selectedChoice.text,
      null,
      { mood: session.story.mood, characters },
    );
    const parsed = nextChapter.storyData;

    const nextTurn = expectedTurn === 1 ? 2 : 1;
    const newChapterNumber = lastChapter.chapterNumber + 1;

    await tx.chapter.update({
      where: { id: lastChapter.id },
      data: { selectedChoice: choiceId },
    });

    await tx.chapter.create({
      data: {
        storyId: session.storyId,
        chapterNumber: newChapterNumber,
        content: parsed.storyText,
        choices: parsed.choices,
        interactionId: `coop-${newChapterNumber}`,
        summary: parsed.chapterSummary || null,
      },
    });

    const updatedSession = await tx.coopSession.update({
      where: { id: sessionId },
      data: { currentTurn: nextTurn },
      include: SESSION_INCLUDE,
    });

    emitToRoom(`coop:${sessionId}`, 'coop:newChapter', {
      sessionId,
      currentTurn: nextTurn,
      chapter: {
        chapterNumber: newChapterNumber,
        content: parsed.storyText,
        choices: parsed.choices,
      },
    });

    return updatedSession;
  });
}

async function completeCoopStory(sessionId, userId) {
  const session = await prisma.coopSession.findUnique({
    where: { id: sessionId },
    include: SESSION_INCLUDE,
  });
  if (!session) {
    throw Object.assign(new Error('Oturum bulunamadı'), { status: 404 });
  }
  assertAccess(session, userId);
  if (session.status !== 'ACTIVE') {
    throw Object.assign(new Error('Oturum aktif değil'), { status: 400 });
  }

  const [, updatedSession] = await prisma.$transaction([
    prisma.story.update({
      where: { id: session.storyId },
      data: { isActive: false },
    }),
    prisma.coopSession.update({
      where: { id: sessionId },
      data: { status: 'COMPLETED' },
      include: SESSION_INCLUDE,
    }),
  ]);

  emitToRoom(`coop:${sessionId}`, 'coop:statusChange', {
    sessionId,
    status: 'COMPLETED',
  });

  return updatedSession;
}

async function getCoopSession(sessionId, userId) {
  const session = await prisma.coopSession.findUnique({
    where: { id: sessionId },
    include: SESSION_INCLUDE,
  });
  if (!session) {
    throw Object.assign(new Error('Oturum bulunamadı'), { status: 404 });
  }
  assertAccess(session, userId);
  return session;
}

async function getCoopInvites(userId) {
  return prisma.coopSession.findMany({
    where: { guestUserId: userId, status: 'WAITING' },
    include: {
      story: { select: { id: true, title: true, genre: true, mood: true } },
      host: { select: { id: true, username: true } },
      guest: { select: { id: true, username: true } },
    },
    orderBy: { createdAt: 'desc' },
  });
}

async function getUserCoopSessions(userId) {
  return prisma.coopSession.findMany({
    where: {
      OR: [{ hostUserId: userId }, { guestUserId: userId }],
      status: { in: ['WAITING', 'ACTIVE', 'COMPLETED'] },
    },
    include: {
      story: { select: { id: true, title: true, genre: true, mood: true } },
      host: { select: { id: true, username: true } },
      guest: { select: { id: true, username: true } },
    },
    orderBy: { updatedAt: 'desc' },
  });
}

async function addCoopCharacter(sessionId, userId, { name, personality, appearance }) {
  const session = await prisma.coopSession.findUnique({
    where: { id: sessionId },
  });
  if (!session) {
    throw Object.assign(new Error('Oturum bulunamadı'), { status: 404 });
  }
  assertAccess(session, userId);

  const count = await prisma.character.count({
    where: { storyId: session.storyId, userId },
  });
  if (count >= MAX_CHARACTERS_PER_USER) {
    throw Object.assign(new Error(`En fazla ${MAX_CHARACTERS_PER_USER} karakter ekleyebilirsiniz`), { status: 400 });
  }

  const character = await prisma.character.create({
    data: {
      storyId: session.storyId,
      userId,
      name,
      personality: personality || '',
      appearance: appearance || '',
    },
    include: { user: { select: { id: true, username: true } } },
  });

  emitToRoom(`coop:${sessionId}`, 'coop:characterAdded', {
    sessionId,
    character,
  });

  return character;
}

async function getCoopCharacters(sessionId, userId) {
  const session = await prisma.coopSession.findUnique({
    where: { id: sessionId },
  });
  if (!session) {
    throw Object.assign(new Error('Oturum bulunamadı'), { status: 404 });
  }
  assertAccess(session, userId);

  return prisma.character.findMany({
    where: { storyId: session.storyId },
    include: { user: { select: { id: true, username: true } } },
    orderBy: { createdAt: 'asc' },
  });
}

async function deleteCoopCharacter(sessionId, characterId, userId) {
  const session = await prisma.coopSession.findUnique({
    where: { id: sessionId },
  });
  if (!session) {
    throw Object.assign(new Error('Oturum bulunamadı'), { status: 404 });
  }
  assertAccess(session, userId);

  const character = await prisma.character.findUnique({ where: { id: characterId } });
  if (!character || character.userId !== userId) {
    throw Object.assign(new Error('Bu karakteri silme yetkiniz yok'), { status: 403 });
  }

  await prisma.character.delete({ where: { id: characterId } });

  emitToRoom(`coop:${sessionId}`, 'coop:characterRemoved', {
    sessionId,
    characterId,
  });

  return { success: true };
}

async function getCoopStoryTree(sessionId, userId) {
  const session = await prisma.coopSession.findUnique({
    where: { id: sessionId },
    include: {
      story: {
        include: {
          chapters: {
            orderBy: { chapterNumber: 'asc' },
            select: {
              id: true,
              chapterNumber: true,
              summary: true,
              selectedChoice: true,
              choices: true,
              createdAt: true,
            },
          },
        },
      },
      host: { select: { id: true, username: true } },
      guest: { select: { id: true, username: true } },
    },
  });
  if (!session) {
    throw Object.assign(new Error('Oturum bulunamadı'), { status: 404 });
  }
  assertAccess(session, userId);

  return {
    sessionId: session.id,
    title: session.story.title,
    genre: session.story.genre,
    host: session.host,
    guest: session.guest,
    nodes: session.story.chapters.map((ch) => ({
      id: ch.id,
      chapterNumber: ch.chapterNumber,
      summary: ch.summary || `Bölüm ${ch.chapterNumber}`,
      selectedChoice: ch.selectedChoice,
      choices: ch.choices,
      createdAt: ch.createdAt,
    })),
  };
}

async function getCoopRecap(sessionId, userId) {
  const session = await prisma.coopSession.findUnique({
    where: { id: sessionId },
    include: {
      story: { include: { chapters: { orderBy: { chapterNumber: 'asc' } } } },
    },
  });
  if (!session) {
    throw Object.assign(new Error('Oturum bulunamadı'), { status: 404 });
  }
  assertAccess(session, userId);

  const recap = await geminiService.generateRecap(
    session.story.chapters,
  );

  return { recap };
}

async function shareCoopStory(sessionId, userId) {
  const session = await prisma.coopSession.findUnique({
    where: { id: sessionId },
    include: { story: true },
  });
  if (!session) {
    throw Object.assign(new Error('Oturum bulunamadı'), { status: 404 });
  }
  assertAccess(session, userId);

  const existing = await prisma.sharedStory.findFirst({
    where: { storyId: session.storyId },
  });
  if (existing) {
    return { alreadyShared: true, shared: existing };
  }

  const shared = await prisma.sharedStory.create({
    data: {
      storyId: session.storyId,
      userId,
      isPublic: true,
    },
  });

  return { alreadyShared: false, shared };
}

module.exports = {
  createCoopSession,
  joinCoopSession,
  rejectCoopSession,
  makeCoopChoice,
  completeCoopStory,
  getCoopSession,
  getCoopInvites,
  getUserCoopSessions,
  addCoopCharacter,
  getCoopCharacters,
  deleteCoopCharacter,
  getCoopStoryTree,
  getCoopRecap,
  shareCoopStory,
};
