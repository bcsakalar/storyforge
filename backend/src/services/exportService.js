const puppeteer = require('puppeteer');
const prisma = require('../config/database');

const GENRE_LABELS = {
  bilim_kurgu: 'Bilim Kurgu',
  fantastik: 'Fantastik',
  korku: 'Korku',
  macera: 'Macera',
  romantik: 'Romantik',
  gerilim: 'Gerilim',
  drama: 'Drama',
  komedi: 'Komedi',
  tarih: 'Tarih',
  gizem: 'Gizem',
};

const MOOD_LABELS = {
  korku: 'Korku',
  macera: 'Macera',
  romantik: 'Romantik',
  komedi: 'Komedi',
  gerilim: 'Gerilim',
  melankolik: 'Melankolik',
  epik: 'Epik',
  gizemli: 'Gizemli',
};

function escapeHtml(text) {
  if (!text) return '';
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function buildHtml(story) {
  const genre = GENRE_LABELS[story.genre] || story.genre || '';
  const mood = MOOD_LABELS[story.mood] || story.mood || '';
  const author = escapeHtml(story.user.username);
  const title = escapeHtml(story.title);
  const now = new Date();
  const dateStr = `${now.getDate().toString().padStart(2, '0')}.${(now.getMonth() + 1).toString().padStart(2, '0')}.${now.getFullYear()}`;

  const chaptersHtml = story.chapters
    .map((ch) => {
      const content = escapeHtml(ch.content).replace(/\n/g, '<br>');
      let choiceHtml = '';
      if (ch.selectedChoice != null) {
        const choices = Array.isArray(ch.choices) ? ch.choices : [];
        const selected = choices.find((c) => c.id === ch.selectedChoice);
        if (selected) {
          choiceHtml = `<div class="choice"><span class="choice-icon">&#10149;</span> ${escapeHtml(selected.text)}</div>`;
        }
      }
      return `
        <div class="chapter">
          <div class="chapter-header">
            <div class="chapter-number">B\u00f6l\u00fcm ${ch.chapterNumber}</div>
          </div>
          <div class="chapter-content">${content}</div>
          ${choiceHtml}
        </div>`;
    })
    .join('\n');

  return `<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<style>
  @page {
    size: A4;
    margin: 0;
  }
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }
  body {
    font-family: 'Noto Sans', sans-serif;
    color: #1a1a1a;
    line-height: 1.7;
    font-size: 11pt;
  }

  /* ── Cover Page ── */
  .cover {
    page-break-after: always;
    height: 100vh;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    text-align: center;
    padding: 60px 80px;
    background: linear-gradient(160deg, #0f0f0f 0%, #1a1a2e 40%, #16213e 100%);
    color: #e0e0e0;
    position: relative;
    overflow: hidden;
  }
  .cover::before {
    content: '';
    position: absolute;
    top: -50%;
    left: -50%;
    width: 200%;
    height: 200%;
    background: radial-gradient(ellipse at 30% 50%, rgba(99, 102, 241, 0.08) 0%, transparent 60%),
                radial-gradient(ellipse at 70% 50%, rgba(168, 85, 247, 0.06) 0%, transparent 60%);
  }
  .cover-content {
    position: relative;
    z-index: 1;
  }
  .cover-badge {
    display: inline-block;
    padding: 6px 20px;
    border: 1px solid rgba(99, 102, 241, 0.4);
    border-radius: 20px;
    font-size: 9pt;
    letter-spacing: 2px;
    text-transform: uppercase;
    color: #818cf8;
    margin-bottom: 40px;
  }
  .cover-title {
    font-size: 32pt;
    font-weight: 700;
    line-height: 1.2;
    margin-bottom: 24px;
    color: #ffffff;
    max-width: 500px;
  }
  .cover-divider {
    width: 60px;
    height: 3px;
    background: linear-gradient(90deg, #6366f1, #a855f7);
    border-radius: 2px;
    margin: 0 auto 28px;
  }
  .cover-meta {
    font-size: 10pt;
    color: #94a3b8;
    margin-bottom: 6px;
  }
  .cover-meta strong {
    color: #c4b5fd;
  }
  .cover-footer {
    position: absolute;
    bottom: 40px;
    left: 0;
    right: 0;
    text-align: center;
    z-index: 1;
  }
  .cover-footer-logo {
    font-size: 10pt;
    color: #475569;
    letter-spacing: 3px;
  }
  .cover-footer-date {
    font-size: 8pt;
    color: #334155;
    margin-top: 4px;
  }

  /* ── Chapters ── */
  .chapter {
    page-break-before: always;
    padding: 56px 64px;
  }
  .chapter:first-child {
    page-break-before: auto;
  }
  .chapter-header {
    margin-bottom: 28px;
    padding-bottom: 16px;
    border-bottom: 2px solid #e2e8f0;
  }
  .chapter-number {
    font-size: 20pt;
    font-weight: 700;
    color: #1e293b;
    letter-spacing: 0.5px;
  }
  .chapter-content {
    font-size: 11pt;
    line-height: 1.85;
    color: #334155;
    text-align: justify;
    hyphens: auto;
  }
  .choice {
    margin-top: 28px;
    padding: 14px 20px;
    background: #f1f5f9;
    border-left: 3px solid #6366f1;
    border-radius: 0 8px 8px 0;
    font-size: 10pt;
    color: #475569;
    font-style: italic;
  }
  .choice-icon {
    color: #6366f1;
    margin-right: 6px;
  }
</style>
</head>
<body>

  <div class="cover">
    <div class="cover-content">
      <div class="cover-badge">StoryForge</div>
      <div class="cover-title">${title}</div>
      <div class="cover-divider"></div>
      <div class="cover-meta"><strong>${escapeHtml(genre)}</strong></div>
      ${mood ? `<div class="cover-meta">${escapeHtml(mood)}</div>` : ''}
      <div style="margin-top: 32px;">
        <div class="cover-meta">Yazan: <strong>${author}</strong></div>
      </div>
    </div>
    <div class="cover-footer">
      <div class="cover-footer-logo">S T O R Y F O R G E</div>
      <div class="cover-footer-date">${dateStr}</div>
    </div>
  </div>

  ${chaptersHtml}

</body>
</html>`;
}

let browserInstance = null;

async function getBrowser() {
  if (browserInstance && browserInstance.connected) {
    return browserInstance;
  }
  browserInstance = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
  });
  return browserInstance;
}

async function generatePdf(storyId, userId) {
  const story = await prisma.story.findFirst({
    where: { id: storyId, userId, isActive: true },
    include: {
      chapters: { orderBy: { chapterNumber: 'asc' } },
      user: { select: { username: true } },
    },
  });
  if (!story) {
    throw Object.assign(new Error('Hikaye bulunamadı'), { status: 404 });
  }

  return renderPdf(story);
}

async function generateCoopPdf(sessionId, userId) {
  const session = await prisma.coopSession.findUnique({
    where: { id: sessionId },
    include: {
      story: {
        include: {
          chapters: { orderBy: { chapterNumber: 'asc' } },
          user: { select: { username: true } },
        },
      },
      host: { select: { username: true } },
      guest: { select: { username: true } },
    },
  });
  if (!session) {
    throw Object.assign(new Error('Oturum bulunamadı'), { status: 404 });
  }
  if (session.hostUserId !== userId && session.guestUserId !== userId) {
    throw Object.assign(new Error('Bu oturuma erişiminiz yok'), { status: 403 });
  }

  // Build a story-like object with co-op author info
  const story = {
    ...session.story,
    user: { username: `${session.host.username} & ${session.guest?.username || '?'}` },
  };

  return renderPdf(story);
}

async function renderPdf(story) {
  const html = buildHtml(story);
  const browser = await getBrowser();
  const page = await browser.newPage();

  try {
    await page.setContent(html, { waitUntil: 'networkidle0' });
    const pdfBuffer = await page.pdf({
      format: 'A4',
      printBackground: true,
      preferCSSPageSize: true,
    });
    return Buffer.from(pdfBuffer);
  } finally {
    await page.close();
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  if (browserInstance) await browserInstance.close();
});
process.on('SIGINT', async () => {
  if (browserInstance) await browserInstance.close();
});

module.exports = { generatePdf, generateCoopPdf };
