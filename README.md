<div align="center">

# StoryForge

**AI-Powered Interactive Storytelling Platform**

[![Node.js](https://img.shields.io/badge/Node.js-18+-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Gemini AI](https://img.shields.io/badge/Google%20Gemini-AI-4285F4?logo=google&logoColor=white)](https://ai.google.dev/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

*Every choice you make writes a different story. No two adventures are ever the same.*

</div>

---

## What is StoryForge?

StoryForge is a full-stack interactive fiction platform where **AI writes stories shaped by your choices**. Powered by Google's Gemini AI, it generates rich, branching narratives across multiple genres. At the end of each chapter, you're presented with choices — the story evolves based on what you pick.

The platform features a **web interface** (server-rendered with EJS) and a **cross-platform mobile app** (Flutter), both sharing the same backend and database. Play solo, invite a friend for **co-op storytelling**, or explore stories shared by the community.

### Key Highlights

- **Multi-Agent AI Pipeline** — Writer Agent generates story content, Consistency Agent validates narrative coherence with RAG Triad anti-hallucination checks
- **RAG Memory System** — Entity extraction, vector embeddings (pgvector), and contextual retrieval ensure the AI remembers characters, events, and world rules
- **Real-time Co-op** — Two players take turns writing a story together via Socket.io
- **Full Social Platform** — Share stories, like, comment, bookmark, add friends, chat in real-time
- **Gamification** — XP, levels, 24 achievements, daily quests, reading streaks

---

## Features

### Story Engine
- **7 genres** — Fantasy, Sci-Fi, Horror, Romance, Mystery, Adventure, Historical
- **Branching narratives** — 2-4 choices per chapter, story tree visualization
- **Photo influence** — Take a photo and the AI weaves it into the narrative (multimodal)
- **Text-to-Speech** — Listen to chapters read aloud via Gemini TTS
- **Story Codex** — Encyclopedia of characters, lore, relationships, and timeline
- **PDF Export** — Download completed stories as PDF
- **Dynamic context window** — Adapts AI context based on story length
- **Deep & quick summaries** — Automatic chapter summaries for long stories

### Social & Multiplayer
- **Public gallery** — Browse and discover community stories
- **Friend feed** — See stories from your friends
- **Real-time chat** — 1-on-1 messaging with typing indicators and read receipts
- **Co-op mode** — Turn-based collaborative storytelling with a friend
- **Likes, comments, bookmarks** — Full social engagement

### Gamification
- **XP & Levels** — Earn XP for reading, completing stories, and social actions
- **24 Achievements** — Unlock milestones as you play
- **Daily Quests** — 3 random quests per day across 7 quest types
- **Reading Streaks** — Track consecutive days of reading

### Technical
- **Dual authentication** — Session-based (web) + JWT (mobile)
- **Multi-agent AI pipeline** — Writer → Consistency → Retry with RAG Triad validation
- **Vector search** — pgvector HNSW indexes for semantic entity/event retrieval
- **Redis caching** — Entity, lore, relationship, and summary cache layers
- **Real-time events** — Socket.io for streaming, co-op, chat, notifications
- **Push notifications** — Firebase Cloud Messaging (optional)
- **Offline support** — Hive local cache with connectivity monitoring (mobile)
- **i18n** — Turkish and English localization

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Backend** | Node.js, Express.js, EJS templates |
| **Database** | PostgreSQL 16 + pgvector, Prisma ORM |
| **Cache** | Redis 7 (sessions, entity cache, rate limiting) |
| **AI** | Google Gemini API (`gemini-3-flash-preview` + `gemini-embedding-2-preview`) |
| **Real-time** | Socket.io |
| **Mobile** | Flutter (Dart 3), Provider, Dio, Hive |
| **Push** | Firebase Cloud Messaging |
| **Infrastructure** | Docker Compose, Nginx, Cloudflare |
| **Testing** | Jest (backend), flutter_test (mobile) |

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                        Clients                            │
│   ┌─────────────┐   ┌──────────────┐   ┌─────────────┐  │
│   │ Web (EJS)   │   │ Flutter App  │   │ Socket.io   │  │
│   │ Session Auth│   │ JWT Auth     │   │ Real-time   │  │
│   └──────┬──────┘   └──────┬───────┘   └──────┬──────┘  │
└──────────┼─────────────────┼──────────────────┼──────────┘
           │                 │                  │
           ▼                 ▼                  ▼
┌──────────────────────────────────────────────────────────┐
│            Express.js Backend (Port 3004)                 │
│                                                           │
│  Middleware: Helmet → HPP → Rate Limiter → CORS → Auth   │
│                                                           │
│  ┌────────────┐  ┌────────────┐  ┌────────────────────┐ │
│  │ Controllers │  │  Services  │  │  AI Agent Pipeline │ │
│  │ (3 files)   │  │ (20 files) │  │  Writer → Check →  │ │
│  │             │  │            │  │  Retry             │ │
│  └─────┬──────┘  └─────┬──────┘  └─────────┬──────────┘ │
│        └────────────────┼───────────────────┘            │
│                         ▼                                │
│                    Prisma ORM                            │
└─────────────────────────┬────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
   ┌────────────┐  ┌────────────┐  ┌────────────┐
   │ PostgreSQL │  │   Redis    │  │ Gemini API │
   │ + pgvector │  │  (Cache)   │  │   (AI)     │
   └────────────┘  └────────────┘  └────────────┘
```

### AI Pipeline Detail

```
User Choice → RAG Context Retrieval → Writer Agent (temp 0.9)
                                           │
                                           ▼
                                    Consistency Agent (temp 0.1)
                                    ├── Groundedness (40%)
                                    ├── Temporal Consistency (35%)
                                    └── Context Relevance (25%)
                                           │
                                      Pass? ──► New Chapter
                                      Fail? ──► Retry (max 1)
```

---

## Getting Started

### Prerequisites

- **Docker** & **Docker Compose**
- **Google Gemini API Key** → [aistudio.google.com](https://aistudio.google.com)
- **Flutter SDK** (only if building the mobile app)

### 1. Clone

```bash
git clone https://github.com/bcsakalar/storyforge.git
cd storyforge
```

### 2. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with your values:

```env
GEMINI_API_KEY=your_gemini_api_key_here
POSTGRES_PASSWORD=your_secure_db_password
SESSION_SECRET=random_64_char_hex_string
JWT_SECRET=another_random_64_char_hex_string
NODE_ENV=development
```

> Generate secrets with: `openssl rand -hex 32`

### 3. Run with Docker

```bash
docker-compose up -d
```

Run database migrations on first start:

```bash
docker exec -it storyforge-backend-1 npx prisma migrate deploy
```

Open in browser: **http://localhost:3004**

### 4. Mobile App (Optional)

```bash
cd mobile
flutter pub get
flutter run
```

Build release APK:

```bash
flutter build apk --release
```

> Use the ⚙ icon on the login screen to configure the server address.

---

## Project Structure

```
storyforge/
├── backend/
│   ├── prisma/                 # Database schema & migrations (31 models)
│   ├── src/
│   │   ├── config/             # DB, Redis, Gemini, Socket.io, Firebase config
│   │   ├── controllers/        # Auth, Story, API controllers
│   │   ├── middleware/          # Auth, error handler, sanitize, rate limiting
│   │   ├── routes/             # Web routes + REST API routes
│   │   ├── services/           # 20 service modules (AI, social, gamification...)
│   │   ├── views/              # 17 EJS templates (web interface)
│   │   └── public/             # Static assets (CSS, JS)
│   ├── __tests__/              # Jest test suites
│   ├── Dockerfile
│   └── package.json
├── mobile/
│   └── lib/
│       ├── models/             # Data models
│       ├── providers/          # 8 Provider state managers
│       ├── screens/            # 21 screens
│       ├── services/           # 18 service modules
│       ├── widgets/            # Reusable UI components
│       └── l10n/               # Localization (TR/EN)
├── knowledge/                  # AI agent knowledge base
├── docker-compose.yml
├── .env.example
└── DEPLOY.md                   # VPS deployment guide
```

---

## API Reference

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/auth/register` | Create account |
| `POST` | `/api/auth/login` | Login (returns JWT) |
| `GET` | `/api/auth/me` | Get current user |

### Stories
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/genres` | List available genres |
| `GET` | `/api/stories` | List user's stories |
| `POST` | `/api/stories` | Create new story |
| `GET` | `/api/stories/:id` | Get story with chapters |
| `POST` | `/api/stories/:id/choose` | Make a choice (continue story) |
| `POST` | `/api/stories/:id/complete` | Complete a story |
| `POST` | `/api/stories/:id/branch/:chapterId` | Branch from a chapter |
| `GET` | `/api/stories/:id/tree` | Get story decision tree |
| `DELETE` | `/api/stories/:id` | Delete story |

### Story Features
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/stories/:id/chapters/:num/tts` | Text-to-speech for chapter |
| `GET` | `/api/stories/:id/codex` | Story codex (entities, lore) |
| `GET` | `/api/stories/:id/timeline` | Story event timeline |
| `POST` | `/api/stories/:id/export/pdf` | Export story as PDF |

### Social
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/stories/:id/share` | Share story publicly |
| `GET` | `/api/shared/gallery` | Browse public stories |
| `GET` | `/api/shared/feed` | Friend feed |
| `POST` | `/api/shared/:id/like` | Toggle like |
| `POST` | `/api/shared/:id/comment` | Add comment |
| `POST` | `/api/shared/:id/bookmark` | Toggle bookmark |

### Friends & Messaging
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/friends` | List friends |
| `POST` | `/api/friends/request` | Send friend request |
| `POST` | `/api/friends/:id/accept` | Accept request |
| `GET` | `/api/messages/:friendId` | Get conversation |
| `POST` | `/api/messages/:friendId` | Send message |

### Gamification
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/stats` | Reading statistics |
| `GET` | `/api/achievements` | User achievements |
| `GET` | `/api/quests` | Daily quests |

---

## Running Tests

### Backend

```bash
cd backend
npm test
```

### Mobile

```bash
cd mobile
flutter test
```

---

## Deployment

See [DEPLOY.md](DEPLOY.md) for a complete VPS deployment guide with Nginx and Cloudflare.

Quick production setup:

```bash
# Set NODE_ENV=production in .env
docker-compose up -d --build
docker exec -it storyforge-backend-1 npx prisma migrate deploy
```

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GEMINI_API_KEY` | Yes | Google Gemini API key |
| `POSTGRES_PASSWORD` | Yes | PostgreSQL password |
| `SESSION_SECRET` | Yes | Session encryption key |
| `JWT_SECRET` | Yes | JWT signing secret |
| `NODE_ENV` | No | `development` or `production` (default: `production`) |
| `PORT` | No | Server port (default: `3004`) |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | No | Path to Firebase service account JSON |
| `FIREBASE_PROJECT_ID` | No | Firebase project ID |

---

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feat/amazing-feature`)
3. Commit your changes (`feat: add amazing feature`)
4. Push to the branch (`git push origin feat/amazing-feature`)
5. Open a Pull Request

Please follow [Conventional Commits](https://www.conventionalcommits.org/) for commit messages.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

Built with Gemini AI, Node.js, Flutter, and PostgreSQL

**[bcsakalar](https://github.com/bcsakalar)**

</div>

*Built with Gemini AI, Node.js, Flutter & a love for stories.*

> **Not:** Android emülatörde `10.0.2.2:3000` otomatik olarak localhost'a eşlenir.
> Gerçek cihazda IP adresini değiştirmen gerekir (mobil uygulamadaki ayarlardan).

## Proje Yapısı

```
storyforge/
├── docker-compose.yml
├── backend/
│   ├── Dockerfile
│   ├── prisma/schema.prisma     # Veritabanı şeması
│   └── src/
│       ├── app.js               # Express app
│       ├── server.js            # Entry point
│       ├── config/              # DB, Gemini, Session config
│       ├── middleware/          # Auth, error handler
│       ├── routes/              # Web & API rotaları
│       ├── controllers/         # İstek işleyiciler
│       ├── services/            # İş mantığı (auth, story, gemini)
│       ├── views/               # EJS şablonları
│       └── public/              # CSS, JS, görseller
└── mobile/
    └── lib/
        ├── main.dart
        ├── models/              # Dart veri modelleri
        ├── services/            # HTTP istemcisi
        ├── providers/           # State yönetimi
        ├── screens/             # Uygulama ekranları
        └── widgets/             # Yeniden kullanılabilir widget'lar
```

## API Endpoints

### Auth
| Method | Endpoint | Açıklama |
|--------|----------|----------|
| POST | `/api/auth/register` | Kayıt `{email, username, password}` |
| POST | `/api/auth/login` | Giriş `{email, password}` → token |
| GET | `/api/auth/me` | Kullanıcı bilgisi |

### Hikaye
| Method | Endpoint | Açıklama |
|--------|----------|----------|
| GET | `/api/stories` | Hikaye listesi |
| POST | `/api/stories` | Yeni hikaye `{genre}` |
| GET | `/api/stories/:id` | Hikaye detay + bölümler |
| POST | `/api/stories/:id/choose` | Seçim yap `{choiceId, imageBase64?}` |
| DELETE | `/api/stories/:id` | Hikaye sil |
| GET | `/api/genres` | Tür listesi |

## Hikaye Türleri

- 🐉 **Fantastik** — Büyü, ejderhalar ve destansı maceralar
- 👻 **Korku** — Gerilim, karanlık ve doğaüstü tehditler
- 🚀 **Bilim Kurgu** — Uzay, teknoloji ve gelecek
- 💕 **Romantik** — Aşk, ilişkiler ve duygusal derinlik
- ⚔️ **Macera** — Aksiyon, keşif ve kahramanlık
- 🔍 **Gizem** — Sırlar, dedektiflik ve sürprizler

## Gemini Hafıza Stratejisi

1. **Dynamic Context Window**: Bölüm sayısına göre adaptif (Ch 1-10: son 5 full | Ch 11-30: son 3 full + 5 özet | Ch 31+: son 2 full + milestone'lar)
2. **Quick/Deep Summarization**: Quick = her bölüm (2-3 cümle), Deep = her 5 bölümde kapsamlı özet
3. **Multi-Agent Pipeline**: Writer Agent (temp 0.9) → Consistency Agent (temp 0.1, RAG Triad) → max 1 retry
4. **Thinking Mode**: 10+ bölümde aktif (2048 token bütçe)
5. **RAG Retrieval**: pgvector cosine similarity ile entity/event/lore bağlamı
6. **System Instruction**: Tür kuralları, tutarlılık kuralları, JSON format zorunluluğu
7. **Structured Output**: JSON formatında çıktı → parse güvenilirliği

## Kamera Özelliği (Mobil)

Mobil uygulamada hikaye seçim ekranında kamera butonuna basarak fotoğraf çekebilirsin.
Çektiğin fotoğraf:
- Hikayeye ilham kaynağı olarak kullanılır
- Seçenekleri etkileyebilir
- Gemini multimodal input olarak fotoğrafı analiz eder ve hikayeye entegre eder

## Lisans

MIT
