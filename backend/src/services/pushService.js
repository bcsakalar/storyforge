const prisma = require('../config/database');
const { getMessaging } = require('../config/firebase');

// Register or update device token
async function registerToken(userId, token, platform = 'android') {
  return prisma.deviceToken.upsert({
    where: { token },
    create: { userId, token, platform },
    update: { userId, platform },
  });
}

// Remove device token (e.g. on logout)
async function removeToken(token) {
  try {
    await prisma.deviceToken.delete({ where: { token } });
  } catch (_) {
    // Token may not exist
  }
}

// Remove all tokens for a user
async function removeUserTokens(userId) {
  await prisma.deviceToken.deleteMany({ where: { userId } });
}

// Send push notification to a user
async function sendToUser(userId, { title, body, data = {} }) {
  const messaging = getMessaging();
  if (!messaging) return;

  const tokens = await prisma.deviceToken.findMany({
    where: { userId },
    select: { token: true },
  });
  if (tokens.length === 0) return;

  const message = {
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)])
    ),
    android: {
      priority: 'high',
      notification: {
        channelId: 'storyforge_default',
        sound: 'default',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
  };

  const tokenStrings = tokens.map(t => t.token);

  try {
    const response = await messaging.sendEachForMulticast({
      ...message,
      tokens: tokenStrings,
    });

    // Clean up invalid tokens
    if (response.failureCount > 0) {
      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const code = resp.error?.code;
          if (code === 'messaging/invalid-registration-token' ||
              code === 'messaging/registration-token-not-registered') {
            invalidTokens.push(tokenStrings[idx]);
          }
        }
      });
      if (invalidTokens.length > 0) {
        await prisma.deviceToken.deleteMany({
          where: { token: { in: invalidTokens } },
        });
      }
    }
  } catch (err) {
    console.error('FCM send error:', err.message);
  }
}

// Send push to multiple users
async function sendToUsers(userIds, { title, body, data = {} }) {
  await Promise.allSettled(
    userIds.map(id => sendToUser(id, { title, body, data }))
  );
}

module.exports = {
  registerToken,
  removeToken,
  removeUserTokens,
  sendToUser,
  sendToUsers,
};
