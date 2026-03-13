require('dotenv').config();

const http = require('http');
const app = require('./app');
const { initSocket } = require('./config/socket');
const { getSessionStore } = require('./config/session');
const { connectRedis, disconnectRedis } = require('./config/redis');

const PORT = process.env.PORT || 3000;

const server = http.createServer(app);
initSocket(server, getSessionStore());

// Redis bağlantısını başlat (opsiyonel — yoksa hafıza sistemi cache'siz çalışır)
connectRedis().catch((err) => {
  console.warn('⚠️ Redis bağlantısı kurulamadı, cache devre dışı:', err.message);
});

server.listen(PORT, () => {
  console.log(`🚀 StoryForge backend running on http://localhost:${PORT}`);
  console.log(`📖 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔌 Socket.io ready`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  await disconnectRedis();
  server.close(() => process.exit(0));
});
