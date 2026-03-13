const jwt = require('jsonwebtoken');
const authService = require('../services/authService');

// ============ WEB (EJS) ============

async function showLoginPage(req, res) {
  if (req.session?.userId) return res.redirect('/dashboard');
  res.render('pages/login', { title: 'Giriş Yap', error: null, user: null });
}

async function showRegisterPage(req, res) {
  if (req.session?.userId) return res.redirect('/dashboard');
  res.render('pages/register', { title: 'Kayıt Ol', error: null, user: null });
}

async function webLogin(req, res) {
  const { email, password } = req.body;
  try {
    const user = await authService.findUserByEmail(email);
    if (!user) {
      return res.render('pages/login', { title: 'Giriş Yap', error: 'E-posta veya şifre hatalı', user: null });
    }
    const isValid = await authService.verifyPassword(password, user.password);
    if (!isValid) {
      return res.render('pages/login', { title: 'Giriş Yap', error: 'E-posta veya şifre hatalı', user: null });
    }
    // Regenerate session to prevent session fixation
    const oldSession = req.session;
    req.session.regenerate((err) => {
      if (err) {
        return res.render('pages/login', { title: 'Giriş Yap', error: 'Bir hata oluştu', user: null });
      }
      req.session.userId = user.id;
      req.session.username = user.username;
      res.redirect('/dashboard');
    });
  } catch (err) {
    res.render('pages/login', { title: 'Giriş Yap', error: 'Bir hata oluştu', user: null });
  }
}

async function webRegister(req, res) {
  const { email, username, password, confirmPassword } = req.body;
  try {
    if (!email || !username || !password) {
      return res.render('pages/register', { title: 'Kayıt Ol', error: 'Tüm alanlar zorunludur', user: null });
    }
    if (password.length < 8) {
      return res.render('pages/register', { title: 'Kayıt Ol', error: authService.validatePassword(password) || 'Şifre en az 8 karakter olmalı', user: null });
    }
    const pwError = authService.validatePassword(password);
    if (pwError) {
      return res.render('pages/register', { title: 'Kayıt Ol', error: pwError, user: null });
    }
    if (password !== confirmPassword) {
      return res.render('pages/register', { title: 'Kayıt Ol', error: 'Şifreler eşleşmiyor', user: null });
    }
    if (await authService.emailExists(email)) {
      return res.render('pages/register', { title: 'Kayıt Ol', error: 'Bu e-posta zaten kullanılıyor', user: null });
    }
    if (await authService.usernameExists(username)) {
      return res.render('pages/register', { title: 'Kayıt Ol', error: 'Bu kullanıcı adı zaten alınmış', user: null });
    }
    const user = await authService.createUser(email, username, password);
    req.session.regenerate((err) => {
      if (err) {
        return res.render('pages/register', { title: 'Kayıt Ol', error: 'Bir hata oluştu', user: null });
      }
      req.session.userId = user.id;
      req.session.username = user.username;
      res.redirect('/dashboard');
    });
  } catch (err) {
    res.render('pages/register', { title: 'Kayıt Ol', error: 'Kayıt sırasında bir hata oluştu', user: null });
  }
}

function webLogout(req, res) {
  req.session.destroy(() => {
    res.redirect('/login');
  });
}

// ============ API (Mobile) ============

async function apiRegister(req, res, next) {
  const { email, username, password } = req.body;
  try {
    if (!email || !username || !password) {
      return res.status(400).json({ error: 'Tüm alanlar zorunludur' });
    }
    if (password.length < 8) {
      return res.status(400).json({ error: authService.validatePassword(password) || 'Şifre en az 8 karakter olmalı' });
    }
    const pwError = authService.validatePassword(password);
    if (pwError) {
      return res.status(400).json({ error: pwError });
    }
    if (await authService.emailExists(email)) {
      return res.status(409).json({ error: 'Bu e-posta zaten kullanılıyor' });
    }
    if (await authService.usernameExists(username)) {
      return res.status(409).json({ error: 'Bu kullanıcı adı zaten alınmış' });
    }
    const user = await authService.createUser(email, username, password);
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: '30d' });
    res.status(201).json({ user, token });
  } catch (err) {
    next(err);
  }
}

async function apiLogin(req, res, next) {
  const { email, password } = req.body;
  try {
    const user = await authService.findUserByEmail(email);
    if (!user) {
      return res.status(401).json({ error: 'E-posta veya şifre hatalı' });
    }
    const isValid = await authService.verifyPassword(password, user.password);
    if (!isValid) {
      return res.status(401).json({ error: 'E-posta veya şifre hatalı' });
    }
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: '30d' });
    res.json({
      user: { id: user.id, email: user.email, username: user.username, createdAt: user.createdAt },
      token,
    });
  } catch (err) {
    next(err);
  }
}

async function apiGetMe(req, res, next) {
  try {
    const user = await authService.findUserById(req.userId);
    if (!user) {
      return res.status(404).json({ error: 'Kullanıcı bulunamadı' });
    }
    res.json({ user });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  showLoginPage,
  showRegisterPage,
  webLogin,
  webRegister,
  webLogout,
  apiRegister,
  apiLogin,
  apiGetMe,
};
