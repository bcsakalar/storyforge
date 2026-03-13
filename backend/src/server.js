require('dotenv').config();

const http = require('http');
const app = require('./app');
const { initSocket } = require('./config/socket');
const { getSessionStore } = require('./config/session');

const PORT = process.env.PORT || 3000;

const server = http.createServer(app);
initSocket(server, getSessionStore());

server.listen(PORT, () => {
  console.log(`🚀 StoryForge backend running on http://localhost:${PORT}`);
  console.log(`📖 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔌 Socket.io ready`);
});
