const jwt = require('jsonwebtoken');
const prisma = require('../config/database');

// Web session auth
function requireAuth(req, res, next) {
  if (req.session && req.session.userId) {
    return next();
  }
  res.redirect('/login');
}

// API token auth (for mobile)
async function requireApiAuth(req, res, next) {
  // Check session first (web)
  if (req.session && req.session.userId) {
    req.userId = req.session.userId;
    return next();
  }

  // Check JWT token (mobile)
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Yetkilendirme gerekli' });
  }

  try {
    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] });
    const user = await prisma.user.findUnique({ where: { id: decoded.userId } });
    if (!user) {
      return res.status(401).json({ error: 'Geçersiz token' });
    }
    req.userId = user.id;
    next();
  } catch {
    return res.status(401).json({ error: 'Geçersiz veya süresi dolmuş token' });
  }
}

module.exports = { requireAuth, requireApiAuth };
