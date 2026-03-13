const xss = require('xss');

// Strict XSS filter — strips all HTML tags
const strictOptions = {
  whiteList: {},
  stripIgnoreTag: true,
  stripIgnoreTagBody: ['script', 'style'],
};

function sanitize(str) {
  if (typeof str !== 'string') return str;
  return xss(str, strictOptions);
}

// Middleware: sanitize common text fields in req.body
function sanitizeBody(fields) {
  return (req, res, next) => {
    if (req.body) {
      for (const field of fields) {
        if (typeof req.body[field] === 'string') {
          req.body[field] = sanitize(req.body[field]);
        }
      }
    }
    next();
  };
}

module.exports = { sanitize, sanitizeBody };
