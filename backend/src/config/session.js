const session = require('express-session');
const pgSession = require('connect-pg-simple')(session);

let sessionStore = null;

function createSessionMiddleware() {
  sessionStore = new pgSession({
    conString: process.env.DATABASE_URL,
    tableName: 'user_sessions',
    createTableIfMissing: true,
  });

  return session({
    store: sessionStore,
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
      maxAge: 30 * 24 * 60 * 60 * 1000, // 30 gün
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
    },
  });
}

module.exports = { createSessionMiddleware, getSessionStore: () => sessionStore };
