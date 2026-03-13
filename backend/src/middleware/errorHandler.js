const multer = require('multer');

function errorHandler(err, req, res, _next) {
  // Multer errors (file upload)
  if (err instanceof multer.MulterError) {
    const msg = err.code === 'LIMIT_FILE_SIZE' ? 'Dosya çok büyük' : 'Dosya yükleme hatası';
    return res.status(400).json({ error: msg });
  }

  console.error('Error:', err.message);
  console.error(err.stack);

  const statusCode = err.statusCode || 500;
  const message = process.env.NODE_ENV === 'production'
    ? 'Sunucu hatası oluştu'
    : err.message;

  // API request → JSON response
  if (req.path.startsWith('/api/')) {
    return res.status(statusCode).json({ error: message });
  }

  // Web request → EJS error page
  res.status(statusCode).render('pages/error', {
    title: 'Hata',
    message,
    user: req.session?.userId ? req.session : null,
  });
}

module.exports = errorHandler;
