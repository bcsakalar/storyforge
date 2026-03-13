const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

// Upload directories
const UPLOAD_DIR = path.join(__dirname, '..', 'uploads');
const AVATAR_DIR = path.join(UPLOAD_DIR, 'avatars');
const MESSAGE_DIR = path.join(UPLOAD_DIR, 'messages');

// Ensure directories exist
[UPLOAD_DIR, AVATAR_DIR, MESSAGE_DIR].forEach(dir => {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

// Allowed image types
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
const MAX_AVATAR_SIZE = 2 * 1024 * 1024;   // 2MB
const MAX_MESSAGE_SIZE = 5 * 1024 * 1024;  // 5MB

function generateFilename(originalname) {
  const ext = path.extname(originalname).toLowerCase();
  const hash = crypto.randomBytes(16).toString('hex');
  return `${Date.now()}-${hash}${ext}`;
}

const fileFilter = (req, file, cb) => {
  if (ALLOWED_TYPES.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Desteklenmeyen dosya türü. JPEG, PNG, WebP veya GIF yükleyin.'), false);
  }
};

// Avatar upload
const avatarStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, AVATAR_DIR),
  filename: (req, file, cb) => cb(null, generateFilename(file.originalname)),
});

const avatarUpload = multer({
  storage: avatarStorage,
  limits: { fileSize: MAX_AVATAR_SIZE },
  fileFilter,
});

// Message image upload
const messageStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, MESSAGE_DIR),
  filename: (req, file, cb) => cb(null, generateFilename(file.originalname)),
});

const messageUpload = multer({
  storage: messageStorage,
  limits: { fileSize: MAX_MESSAGE_SIZE },
  fileFilter,
});

// Delete file helper
function deleteFile(filePath) {
  const fullPath = path.join(UPLOAD_DIR, filePath);
  if (fs.existsSync(fullPath)) {
    fs.unlink(fullPath, () => {});
  }
}

// Get public URL path from stored filename
function getPublicUrl(subdir, filename) {
  return `/uploads/${subdir}/${filename}`;
}

module.exports = {
  avatarUpload,
  messageUpload,
  deleteFile,
  getPublicUrl,
  UPLOAD_DIR,
  AVATAR_DIR,
  MESSAGE_DIR,
};
