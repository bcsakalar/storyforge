# StoryForge

**AI destekli interaktif hikaye platformu.**
*AI-powered interactive story platform.*

---

## 🇹🇷 Türkçe

### Nedir?

StoryForge, yapay zekanın hikayeler yazdığı ve senin seçimlerinle şekillendirdiği bir interaktif hikaye platformudur. Her bölümün sonunda sana seçenekler sunulur — hangi yolu seçersen hikaye o yöne evrilir. Hiçbir hikaye birbirinin aynısı değildir.

Platform hem web arayüzü hem de mobil uygulama olarak çalışır. Web tarafında tarayıcıdan giriş yapıp oynarsın, mobilde ise Android uygulamasıyla aynı hesabınla devam edersin.

### Ne Yapabilirsin?

- **6 farklı türde hikaye başlat:** Fantastik, Korku, Bilim Kurgu, Romantik, Macera, Gizem
- **Seçimlerle hikayeyi yönlendir:** Her bölüm sonunda 2-4 seçenek, her biri farklı bir yol
- **Fotoğrafla hikayeyi etkile:** Kameranı aç, çektiğin fotoğraf hikayeye dahil edilsin (multimodal AI)
- **Hikayeni sesli dinle:** Gemini TTS ile her bölüm sesli okunur (Kore sesi)
- **Birden fazla hikaye:** İstediğin kadar hikaye başlat, istediğin zaman devam et

### Teknoloji

| Katman | Teknoloji |
|--------|-----------|
| Backend | Node.js, Express, EJS |
| Veritabanı | PostgreSQL 16, Prisma ORM |
| AI | Google Gemini API (gemini-3-flash-preview + TTS) |
| Mobil | Flutter (Android) |
| Altyapı | Docker, Docker Compose |
| Tasarım | Architectural Minimalism — koyu tema, serif başlıklar, altın aksanlar |

### Mimari

```
Web Tarayıcı ──► Express (EJS) ──► PostgreSQL
                      │
Flutter App ───► REST API ──────► Gemini AI
```

Web kullanıcıları session-based auth ile, mobil kullanıcılar JWT token ile giriş yapar. Her iki taraf da aynı veritabanını paylaşır. AI hikaye üretimi ve TTS Gemini API üzerinden yapılır.

---

## 🇬🇧 English

### What is it?

StoryForge is an interactive story platform where AI writes stories shaped by your choices. At the end of each chapter, you're presented with options — the story evolves based on what you pick. No two stories are ever the same.

The platform runs as both a web interface and a mobile app. Log in from a browser on the web side, or continue with the same account on Android.

### What Can You Do?

- **Start stories in 6 genres:** Fantasy, Horror, Sci-Fi, Romance, Adventure, Mystery
- **Shape the story with choices:** 2-4 options at the end of each chapter, each leading somewhere different
- **Influence the story with photos:** Open your camera, and the photo gets woven into the narrative (multimodal AI)
- **Listen to your story:** Every chapter is read aloud via Gemini TTS (Kore voice)
- **Multiple stories:** Start as many stories as you want, continue any time

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Node.js, Express, EJS |
| Database | PostgreSQL 16, Prisma ORM |
| AI | Google Gemini API (gemini-3-flash-preview + TTS) |
| Mobile | Flutter (Android) |
| Infrastructure | Docker, Docker Compose |
| Design | Architectural Minimalism — dark theme, serif headings, gold accents |

### Architecture

```
Web Browser ───► Express (EJS) ──► PostgreSQL
                      │
Flutter App ───► REST API ──────► Gemini AI
```

Web users authenticate via sessions, mobile users via JWT. Both share the same database. Story generation and TTS run through the Gemini API.

---

## Hızlı Başlangıç / Quick Start

### Gereksinimler / Requirements

- Docker & Docker Compose
- Google Gemini API Key → [aistudio.google.com](https://aistudio.google.com)
- (Mobil için) Flutter SDK

### 1. Klonla / Clone

```bash
git clone https://github.com/KULLANICI_ADIN/storyforge.git
cd storyforge
```

### 2. Ortam Değişkenleri / Environment Variables

```bash
cp .env.example .env
```

`.env` dosyasını düzenle / Edit the `.env` file:

```env
GEMINI_API_KEY=your_gemini_api_key_here
SESSION_SECRET=random_64_char_hex_string
JWT_SECRET=another_random_64_char_hex_string
PORT=3001
NODE_ENV=development
DATABASE_URL=postgresql://storyforge:SfStr0ngPwd2026x@db:5432/storyforge?schema=public
```

> Secret üretmek için / Generate secrets: `openssl rand -hex 32`

### 3. Çalıştır / Run

```bash
docker-compose up -d
```

İlk çalıştırmada migration:

```bash
docker exec -it storyforge-backend-1 npx prisma migrate deploy
```

Tarayıcıda aç / Open in browser: `http://localhost:3001`

### 4. Mobil / Mobile (opsiyonel)

```bash
cd mobile
flutter pub get
flutter build apk --release
```

APK: `mobile/build/app/outputs/flutter-apk/app-release.apk`

> Mobil uygulamada login ekranındaki ⚙ butonundan sunucu adresini ayarlayabilirsin.

---

## Proje Yapısı / Project Structure

```
storyforge/
├── backend/
│   ├── prisma/              # Veritabanı şeması ve migration'lar
│   ├── src/
│   │   ├── config/          # DB, session, Gemini yapılandırması
│   │   ├── controllers/     # İş mantığı
│   │   ├── middleware/       # Auth, error handler
│   │   ├── routes/           # Web ve API rotaları
│   │   ├── services/         # Gemini AI, hikaye servisi
│   │   ├── views/            # EJS şablonları
│   │   └── public/           # CSS, statik dosyalar
│   ├── Dockerfile
│   └── package.json
├── mobile/
│   └── lib/
│       ├── models/           # Veri modelleri
│       ├── providers/        # State management
│       ├── screens/          # Ekranlar
│       ├── services/         # API servisi
│       └── widgets/          # Bileşenler
├── docker-compose.yml
├── .env.example
├── DEPLOY.md                 # VPS deployment rehberi
└── README.md
```

---

## API Endpoints

| Method | Endpoint | Açıklama |
|--------|----------|----------|
| POST | `/api/auth/register` | Kayıt ol |
| POST | `/api/auth/login` | Giriş yap |
| GET | `/api/auth/me` | Kullanıcı bilgisi |
| GET | `/api/genres` | Tür listesi |
| GET | `/api/stories` | Hikayeleri listele |
| POST | `/api/stories` | Yeni hikaye |
| GET | `/api/stories/:id` | Hikaye detayı |
| POST | `/api/stories/:id/choose` | Seçim yap |
| DELETE | `/api/stories/:id` | Hikaye sil |
| POST | `/api/stories/:id/chapters/:num/tts` | Sesli okuma |

---

## Lisans / License

MIT

---

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
