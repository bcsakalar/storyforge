const express = require('express');
const path = require('path');
const crypto = require('crypto');
const cors = require('cors');
const helmet = require('helmet');
const hpp = require('hpp');
const rateLimit = require('express-rate-limit');
const cron = require('node-cron');
const { createSessionMiddleware } = require('./config/session');
const errorHandler = require('./middleware/errorHandler');
const authRoutes = require('./routes/authRoutes');
const storyRoutes = require('./routes/storyRoutes');
const apiRoutes = require('./routes/apiRoutes');
const achievementService = require('./services/achievementService');

const app = express();

// Trust proxy (Nginx / Cloudflare arkasında)
if (process.env.NODE_ENV === 'production') {
  app.set('trust proxy', 1);
}

// Generate CSP nonce per request
app.use((req, res, next) => {
  res.locals.cspNonce = crypto.randomBytes(16).toString('base64');
  next();
});

// Security headers with CSP
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", (req, res) => `'nonce-${res.locals.cspNonce}'`],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      fontSrc: ["'self'", "https://fonts.gstatic.com"],
      imgSrc: ["'self'", "data:", "blob:"],
      connectSrc: ["'self'", "wss:", "ws:"],
      mediaSrc: ["'self'", "blob:"],
      objectSrc: ["'none'"],
      frameAncestors: ["'none'"],
    },
  },
  crossOriginEmbedderPolicy: false,
}));

// HTTP Parameter Pollution koruması
app.use(hpp());

// Genel rate limit — tüm istekler
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 dakika
  max: 200,                  // IP başına 200 istek
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Çok fazla istek. Lütfen biraz bekle.' },
});
app.use(generalLimiter);

// Auth rate limit — login/register brute force koruması
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 15,                   // 15 dakikada max 15 giriş denemesi
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Çok fazla giriş denemesi. 15 dakika sonra tekrar dene.' },
});

// TTS rate limit — Gemini API koruması
const ttsLimiter = rateLimit({
  windowMs: 60 * 1000,       // 1 dakika
  max: 5,                    // dakikada max 5 TTS isteği
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Çok fazla ses isteği. Biraz bekle.' },
});

// AI story rate limit
const aiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,                   // dakikada max 10 AI isteği
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Çok fazla hikaye isteği. Biraz bekle.' },
});

// Mesaj gönderme rate limit
const messageLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,                   // dakikada max 30 mesaj
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Çok fazla mesaj. Biraz bekle.' },
});

// Report/moderation rate limit
const reportLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,                   // 15 dakikada max 10 bildirim
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Çok fazla bildirim. Lütfen bekle.' },
});

// Social etkileşim rate limit (like, comment, bookmark, block)
const socialLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 40,                   // dakikada max 40 sosyal etkileşim
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Çok fazla istek. Biraz bekle.' },
});

// View engine
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Static files
app.use(express.static(path.join(__dirname, 'public')));
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

// Body parsers
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true, limit: '5mb' }));

// CORS
app.use(cors({
  origin: process.env.NODE_ENV === 'production'
    ? ['https://storyforge.berkecansakalar.com']
    : true,
  credentials: true,
}));

// Session
app.use(createSessionMiddleware());

// Inject user settings into locals for EJS templates
app.use(async (req, res, next) => {
  if (req.session?.userId) {
    // Cache fontSize in session to avoid DB calls on every page
    if (req.session.userFontSize === undefined) {
      try {
        const prisma = require('./config/database');
        const u = await prisma.user.findUnique({ where: { id: req.session.userId }, select: { fontSize: true } });
        req.session.userFontSize = u?.fontSize || 16;
      } catch { req.session.userFontSize = 16; }
    }
    res.locals.userFontSize = req.session.userFontSize;
  } else {
    res.locals.userFontSize = 16;
  }
  next();
});

// Auth rate limiting
app.use('/login', authLimiter);
app.use('/register', authLimiter);
app.use('/api/auth', authLimiter);

// TTS rate limiting
app.use('/story/:id/chapter/:num/tts', ttsLimiter);
app.use('/api/stories/:id/chapters/:num/tts', ttsLimiter);

// AI story rate limiting (only POST/creation endpoints)
app.post('/story/new', aiLimiter);
app.post('/story/:id/choose', aiLimiter);
app.post('/api/stories', aiLimiter);
app.post('/api/stories/:id/choose', aiLimiter);
app.post('/api/stories/:id/branch/:chapterId', aiLimiter);

// Message rate limiting
app.post('/api/messages', messageLimiter);
app.post('/api/messages/:id', messageLimiter);

// Report rate limiting
app.post('/api/reports', reportLimiter);

// Social interaction rate limiting (like, comment, bookmark, block)
app.use('/api/shared/:id/like', socialLimiter);
app.use('/api/shared/:id/comments', socialLimiter);
app.use('/api/bookmarks', socialLimiter);
app.use('/api/users/:userId/block', socialLimiter);

// Routes — API first (storyRoutes has requireAuth that would catch /api/* otherwise)
app.use('/api', apiRoutes);    // /api/auth/*, /api/stories/*
app.use('/', authRoutes);      // /login, /register, /logout
app.use('/', storyRoutes);     // /dashboard, /story/*

// Home redirect
app.get('/', (req, res) => {
  if (req.session?.userId) {
    return res.redirect('/dashboard');
  }
  res.redirect('/login');
});

// Seed achievements on startup
achievementService.seedAchievements().catch((err) => {
  console.error('Başarım seed hatası:', err.message);
});

// Daily quest reset cron — every day at midnight (UTC+3)
cron.schedule('0 21 * * *', async () => {
  // UTC 21:00 = TR 00:00
  console.log('Günlük görevler sıfırlanıyor...');
  // Quests are generated on-demand when getUserQuests is called
});

// Error handler
app.use(errorHandler);

module.exports = app;
