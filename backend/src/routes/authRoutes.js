const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// Web auth pages
router.get('/login', authController.showLoginPage);
router.get('/register', authController.showRegisterPage);
router.post('/login', authController.webLogin);
router.post('/register', authController.webRegister);
router.post('/logout', authController.webLogout);

module.exports = router;
