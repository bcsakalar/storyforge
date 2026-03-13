const bcrypt = require('bcryptjs');
const prisma = require('../config/database');

const SALT_ROUNDS = 12;

function validatePassword(password) {
  if (!password || password.length < 8) {
    return 'Şifre en az 8 karakter olmalı';
  }
  if (!/[A-Z]/.test(password)) {
    return 'Şifre en az bir büyük harf içermeli';
  }
  if (!/[a-z]/.test(password)) {
    return 'Şifre en az bir küçük harf içermeli';
  }
  if (!/[0-9]/.test(password)) {
    return 'Şifre en az bir rakam içermeli';
  }
  return null;
}

async function createUser(email, username, password) {
  const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);
  return prisma.user.create({
    data: { email, username, password: hashedPassword },
    select: { id: true, email: true, username: true, createdAt: true },
  });
}

async function findUserByEmail(email) {
  return prisma.user.findUnique({ where: { email } });
}

async function findUserById(id) {
  return prisma.user.findUnique({
    where: { id },
    select: { id: true, email: true, username: true, createdAt: true },
  });
}

async function verifyPassword(plainPassword, hashedPassword) {
  return bcrypt.compare(plainPassword, hashedPassword);
}

async function emailExists(email) {
  const user = await prisma.user.findUnique({ where: { email } });
  return !!user;
}

async function usernameExists(username) {
  const user = await prisma.user.findUnique({ where: { username } });
  return !!user;
}

module.exports = {
  createUser,
  findUserByEmail,
  findUserById,
  verifyPassword,
  emailExists,
  usernameExists,
  validatePassword,
};
