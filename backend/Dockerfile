FROM node:20-alpine

# Chromium for Puppeteer PDF generation
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    font-noto

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY prisma ./prisma/
RUN npx prisma generate

COPY src ./src/

# Firebase service account (if exists)
COPY flutter-mobile-1c9ce-firebase-adminsdk-fbsvc-e517433bdd.json ./

EXPOSE 3004

CMD ["node", "src/server.js"]
