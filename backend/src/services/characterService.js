const prisma = require('../config/database');

async function createCharacter(storyId, userId, { name, personality, appearance }) {
  const story = await prisma.story.findFirst({
    where: { id: storyId, userId, isActive: true },
  });
  if (!story) {
    throw Object.assign(new Error('Hikaye bulunamadı'), { status: 404 });
  }

  return prisma.character.create({
    data: { storyId, userId, name, personality: personality || '', appearance: appearance || '' },
  });
}

async function getCharacters(storyId, userId) {
  // Verify the user owns the story or it's shared
  const story = await prisma.story.findFirst({
    where: { id: storyId, userId },
  });
  if (!story) {
    throw Object.assign(new Error('Hikaye bulunamadı'), { status: 404 });
  }
  return prisma.character.findMany({
    where: { storyId },
    orderBy: { createdAt: 'asc' },
  });
}

async function updateCharacter(characterId, userId, data) {
  const character = await prisma.character.findUnique({ where: { id: characterId } });
  if (!character || character.userId !== userId) {
    throw Object.assign(new Error('Karakter bulunamadı'), { status: 404 });
  }

  const updateData = {};
  if (data.name) updateData.name = data.name;
  if (data.personality !== undefined) updateData.personality = data.personality;
  if (data.appearance !== undefined) updateData.appearance = data.appearance;
  // Map mobile fields
  if (data.role || data.traits) {
    updateData.personality = [data.role, Array.isArray(data.traits) ? data.traits.join(', ') : ''].filter(Boolean).join(' — ') || data.personality || '';
  }
  if (data.backstory !== undefined && data.appearance === undefined) {
    updateData.appearance = data.backstory || '';
  }

  return prisma.character.update({
    where: { id: characterId },
    data: updateData,
  });
}

async function deleteCharacter(characterId, userId) {
  const character = await prisma.character.findUnique({ where: { id: characterId } });
  if (!character || character.userId !== userId) {
    throw Object.assign(new Error('Karakter bulunamadı'), { status: 404 });
  }
  return prisma.character.delete({ where: { id: characterId } });
}

module.exports = {
  createCharacter,
  getCharacters,
  updateCharacter,
  deleteCharacter,
};
