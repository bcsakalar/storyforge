# StoryForge — Mimari Dokümanı

## Genel Bakış

StoryForge, yapay zeka destekli interaktif bir hikaye platformudur. Kullanıcılar Gemini AI ile dallanmalı hikayeler oluşturur, seçimler yapar, çok oyunculu co-op oturumları başlatır ve sosyal özelliklerle (paylaşım, beğeni, yorum, arkadaşlık, mesajlaşma) etkileşime girer.

```
┌─────────────────────────────────────────────────────────────┐
│                     İstemciler (Clients)                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  Web (EJS)   │  │ Flutter App  │  │  Socket.io       │  │
│  │  Session Auth │  │  JWT Auth    │  │  Real-time       │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
│         │                 │                    │             │
└─────────┼─────────────────┼────────────────────┼─────────────┘
          │                 │                    │
          ▼                 ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│                   Nginx Reverse Proxy                        │
│            (Cloudflare DNS + SSL terminasyon)                 │
└──────────────────────────┬───────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Express.js Backend (Port 3004)                  │
│                                                              │
│  ┌─────────────┐ ┌─────────────┐ ┌───────────────────────┐ │
│  │  Middleware  │ │  Routes     │ │  Socket.io Server     │ │
│  │  ─ Helmet   │ │  ─ /auth    │ │  ─ Story streaming    │ │
│  │  ─ CORS     │ │  ─ /api     │ │  ─ Co-op events       │ │
│  │  ─ HPP      │ │  ─ /story   │ │  ─ Chat & typing      │ │
│  │  ─ Rate Lim │ │  ─ /upload  │ │  ─ Notifications      │ │
│  │  ─ Sanitize │ │             │ │  ─ Online status       │ │
│  │  ─ Auth     │ │             │ │  ─ Social events       │ │
│  └─────────────┘ └──────┬──────┘ └───────────────────────┘ │
│                         │                                    │
│                    ┌────▼─────┐                              │
│                    │Controllers│                             │
│                    └────┬─────┘                              │
│                         │                                    │
│                    ┌────▼─────┐                              │
│                    │ Services │                              │
│                    └────┬─────┘                              │
│                    ┌────▼─────┐                              │
│                    │ Prisma   │                              │
│                    └────┬─────┘                              │
└─────────────────────────┼────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ PostgreSQL   │ │    Redis     │ │  Gemini API  │
│  + pgvector  │ │   (Cache)    │ │  (AI Motor)  │
│  (Ana DB)    │ │  (Session)   │ │              │
└──────────────┘ └──────────────┘ └──────────────┘
```

---

## Katman Yapısı (Backend)

### 1. Middleware Katmanı
İstekler sırasıyla şu middleware'lerden geçer:

```
İstek → CSP Nonce → Helmet → HPP → Rate Limiter → CORS → Session → Body Parser → Auth → Route Handler
```

| Middleware | Dosya | Görev |
|-----------|-------|-------|
| CSP Nonce | `app.js` (inline) | Her istekte rastgele `res.locals.cspNonce` üretir |
| Helmet | `app.js` | Security headers (CSP, X-Frame, HSTS...) |
| HPP | `app.js` | HTTP Parameter Pollution koruması |
| Rate Limiter | `app.js` | 6 farklı rate limiter (genel, auth, AI, TTS, mesaj, sosyal) |
| CORS | `app.js` | Origin kontrolü (dev: hepsi, prod: tek domain) |
| Session | `config/session.js` | PostgreSQL-backed session (connect-pg-simple) |
| Auth | `middleware/auth.js` | Session (web) VEYA JWT (mobile) dual-auth |
| Sanitize | `middleware/sanitize.js` | XSS koruması (xss kütüphanesi) |
| Error Handler | `middleware/errorHandler.js` | Merkezi hata yakalama |

### 2. Route Katmanı

```
/api/auth/*      → apiRoutes.js → authController → authService
/api/stories/*   → apiRoutes.js → apiController  → storyService, geminiService
/api/friends/*   → apiRoutes.js → apiController  → friendService
/api/messages/*  → apiRoutes.js → apiController  → messageService
/api/coop/*      → apiRoutes.js → apiController  → coopService
/api/shared/*    → apiRoutes.js → apiController  → socialService
/api/upload/*    → apiRoutes.js → apiController  → multer upload

/login, /register, /logout → authRoutes.js → authController (Web, EJS)
/dashboard, /story/*       → storyRoutes.js → storyController (Web, EJS)
```

### 3. Controller Katmanı

| Controller | Dosya | Sorumluluk |
|-----------|-------|------------|
| `authController` | `controllers/authController.js` | Kullanıcı kayıt/giriş (hem web hem API) |
| `storyController` | `controllers/storyController.js` | Web hikaye yönetimi (EJS render) |
| `apiController` | `controllers/apiController.js` | Mobile/API: tüm REST endpointler |

### 4. Service Katmanı

| Servis | Dosya | Sorumluluk |
|--------|-------|------------|
| `authService` | `services/authService.js` | Kullanıcı CRUD, parola hash, doğrulama |
| `storyService` | `services/storyService.js` | Hikaye oluşturma, seçim yapma, ağaç yapısı, dallanma |
| `geminiService` | `services/geminiService.js` | Gemini API entegrasyonu (metin, TTS, özet) |
| `storyMemoryService` | `services/storyMemoryService.js` | RAG sistemi (entity extraction, embedding, retrieval) |
| `socialService` | `services/socialService.js` | Paylaşım, beğeni, yorum, galeri, feed |
| `friendService` | `services/friendService.js` | Arkadaşlık istekleri, kabul/red, arama |
| `messageService` | `services/messageService.js` | Mesajlaşma, okundu bilgisi |
| `coopService` | `services/coopService.js` | İki oyunculu co-op oturumları |
| `levelService` | `services/levelService.js` | XP, seviye hesaplama, streak |
| `questService` | `services/questService.js` | Günlük görevler (3/gün, rastgele) |
| `achievementService` | `services/achievementService.js` | Başarımlar (24 adet, otomatik kilit açma) |
| `notificationService` | `services/notificationService.js` | DB + Socket.io + FCM bildirimler |
| `pushService` | `services/pushService.js` | Firebase Cloud Messaging |
| `blockService` | `services/blockService.js` | Kullanıcı engelleme |
| `cacheService` | `services/cacheService.js` | Redis cache yönetimi (entity, lore, relationship, summary) |
| `agentOrchestratorService` | `services/agentOrchestratorService.js` | Multi-Agent pipeline: Writer → Consistency → Retry |
| `consistencyAgentService` | `services/consistencyAgentService.js` | RAG Triad anti-hallucination doğrulama |
| `relationshipGraphService` | `services/relationshipGraphService.js` | Karakter ilişki grafı extraction + yönetim |

### 5. Config Katmanı

| Config | Dosya | Görev |
|--------|-------|-------|
| `database` | `config/database.js` | Prisma client singleton |
| `redis` | `config/redis.js` | ioredis client (lazy connect) |
| `gemini` | `config/gemini.js` | @google/genai client başlatma |
| `socket` | `config/socket.js` | Socket.io server + tüm event handler'lar |
| `session` | `config/session.js` | express-session + connect-pg-simple |
| `firebase` | `config/firebase.js` | firebase-admin SDK başlatma |
| `upload` | `config/upload.js` | Multer disk storage konfigürasyonu |

---

## Veri Akışı: Hikaye Oluşturma

```
1. Kullanıcı (Mobile/Web) → "Yeni Hikaye" isteği
   │  POST /api/stories {genre, mood, characters}
   │
2. apiController.createStory()
   │  → storyService.createStory(userId, genre, mood, characters)
   │
3. storyService → geminiService.startNewStory(genre, mood, characters)
   │  → Gemini API çağrısı (system prompt + user prompt)
   │  ← JSON response: {title, storyText, choices[], mood, chapterSummary}
   │
4. storyService → DB kayıtları:
   │  → Story oluştur (title, genre, mood, interactionId)
   │  → Chapter #1 oluştur (content, choices, summary)
   │  → UserStats güncelle (XP +10)
   │  → Quest progress kontrol
   │
5. storyService → storyMemoryService.processChapter() [ARKA PLAN]
   │  → Entity extraction (Gemini Function Calling)
   │  → Embedding üretimi (gemini-embedding-2-preview)
   │  → pgvector'e kaydet (StoryEntity, StoryEvent, StoryWorldState)
   │
6. Response → Kullanıcıya story + chapter #1 döner
```

### Hikaye Devam Ettirme (Seçim Yapma)

```
1. POST /api/stories/:id/choose {choiceIndex, imageData?}
   │
2. storyService.makeChoice()
   │  → Son bölümleri getir (Dynamic Context Window: Ch 1-10: son 5 | Ch 11-30: son 3+5 özet | Ch 31+: son 2+milestone)
   │  → storyMemoryService.getRelevantContext(storyId, choiceText)
   │    → Embedding üret → pgvector cosine similarity → ilgili entity/event/lore
   │  → Quick summary: her bölüm (2-3 cümle) | Deep summary: her 5 bölümde (kapsamlı)
   │
3. agentOrchestratorService.generateWithPipeline()
   │  → Writer Agent (temp 0.9): Hikaye üretimi (system prompt + RAG bağlam + karakter)
   │  → Consistency Agent (temp 0.1): RAG Triad doğrulama
   │    → Groundedness (%40) + Temporal Consistency (%35) + Context Relevance (%25)
   │  → Başarısızsa max 1 retry (Writer Agent tekrar çağrılır)
   │  → 10+ bölümde Gemini "thinking" modu aktif (2048 token bütçe)
   │  → maxOutputTokens: 8192 (8-12 paragraf, 800-1200 kelime)
   │  ← JSON: {storyText, choices[], mood, chapterSummary}
   │
4. DB güncelle + response
```

---

## Real-time Veri Akışı (Socket.io)

```
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│   Client A   │◄────────│  Socket.io   │────────►│   Client B   │
│  (Flutter)   │         │   Server     │         │  (Flutter)   │
└──────────────┘         └──────┬───────┘         └──────────────┘
                                │
                    ┌───────────┼───────────┐
                    │           │           │
               ┌────▼───┐ ┌────▼───┐ ┌────▼────┐
               │  Story  │ │  Chat  │ │  Co-op  │
               │Streaming│ │ Events │ │  Turns  │
               └─────────┘ └────────┘ └─────────┘

Event Türleri:
- story:createStream / story:chooseStream → story:chunk → story:complete
- chat:join + message:new + message:read + typing:start/stop
- coop:join + coop:invite + coop:accepted + coop:statusChange
- notification:new + social:like + social:comment
- friend:request + friend:accepted
- user:online / user:offline / user:onlineList
```

---

## Kimlik Doğrulama Mimarisi (Dual Auth)

```
Web İstekleri:                          Mobile İstekleri:
┌──────────────┐                       ┌──────────────┐
│   Browser    │                       │ Flutter App  │
│  Cookie:     │                       │ Header:      │
│  connect.sid │                       │ Bearer <JWT> │
└──────┬───────┘                       └──────┬───────┘
       │                                      │
       ▼                                      ▼
┌──────────────────────────────────────────────────────┐
│              requireApiAuth() Middleware              │
│                                                      │
│  1. req.session?.userId var mı? → Session auth (web) │
│  2. Authorization header var mı? → JWT verify (API)  │
│  3. Hiçbiri → 401 Unauthorized                       │
│                                                      │
│  Sonuç: req.userId = doğrulanmış kullanıcı ID       │
└──────────────────────────────────────────────────────┘
```

- **Web:** express-session + connect-pg-simple (PostgreSQL session store)
- **Mobile:** JWT (jsonwebtoken, 30 gün geçerlilik)
- **Password:** bcryptjs (12 salt rounds)

---

## AI Entegrasyonu Detayı

### Kullanılan Modeller

| Model | Kullanım | Çıktı |
|-------|----------|-------|
| `gemini-3-flash-preview` | Hikaye üretimi, devam, özet, TTS | Metin / JSON / Audio |
| `gemini-embedding-2-preview` | Metin embedding (Entity, Event) | 768-boyutlu vektör |

### RAG (Retrieval-Augmented Generation) Pipeline

```
Yeni Bölüm Yazıldığında (Arka Plan):
  Content → Gemini Function Calling (extractStoryEntities)
    → Karakterler, lokasyonlar, objeler, olaylar çıkar
    → Her birine embedding üret
    → pgvector'e kaydet (StoryEntity, StoryEvent tabloları)
    → StoryWorldState snapshot'ı oluştur

Seçim Yapıldığında (Real-time):
  "Kullanıcının sağdaki kapıyı seçti" → Embedding üret
    → pgvector cosine similarity araması
    → İlgili entity'ler + olaylar çek (top-K)
    → Prompt'a "hatırlatma" olarak ekle
    → Tutarlı hikaye devamı üret
```

### Token Maliyet Optimizasyonu

1. **Redis Cache:** Entity, lore, relationship, summary cache katmanları (cacheService)
2. **Quick/Deep Summarization:** Quick = her bölüm (2-3 cümle, 512 token), Deep = her 5 bölüm (kapsamlı, 4096 token)
3. **Thinking Mode:** 10+ bölümde aktif (2048 token bütçe)
4. **Dynamic Context Window:** Bölüm sayısına göre adaptif bağlam miktarı
5. **Event Relevance Decay:** Çözülmemiş olaylar bölüm başına 0.95x azalma
6. **TokenUsage Tracking:** Her API çağrısı loglanır (inputTokens, outputTokens)

---

## Deployment Mimarisi

```
┌── Cloudflare ──────────────────┐
│  DNS + SSL + CDN + DDoS Shield │
└──────────────┬─────────────────┘
               │
┌──────────────▼─────────────────┐
│         Nginx (VPS)            │
│  - Reverse proxy → :3004      │
│  - Static file serving         │
│  - SSL termination (optional)  │
└──────────────┬─────────────────┘
               │
┌──────────────▼─────────────────────────────────┐
│            Docker Compose                       │
│                                                 │
│  ┌─────────────┐ ┌────────┐ ┌───────────────┐ │
│  │  backend     │ │  db    │ │     redis     │ │
│  │  Node.js     │ │  PG16  │ │  7-alpine     │ │
│  │  :3004       │ │  :5432 │ │  :6379        │ │
│  │  512M/0.75CPU│ │  512M  │ │  256M/128M    │ │
│  └─────────────┘ └────────┘ └───────────────┘ │
│                                                 │
│  Volumes: pgdata, redis_data, uploads           │
└─────────────────────────────────────────────────┘
```

- **Production:** `docker-compose.yml` → DB portları dışarı kapalı
- **Development:** `docker-compose.override.yml` → DB port 5432 açık (pgAdmin erişimi)
- **Override dosyası:** `.gitignore`'da, sadece yerel geliştirmede mevcut

---

## Multi-Agent Pipeline Mimarisi

```
Kullanıcı Seçimi → storyService → agentOrchestratorService
                                        │
                    ┌───────────────────┤
                    ▼                   │
              Writer Agent              │
              (temp 0.9)                │
              8-12 paragraf             │
              800-1200 kelime           │
                    │                   │
                    ▼                   │
           Consistency Agent            │
              (temp 0.1)                │
           RAG Triad Check:             │
           • Groundedness %40           │
           • Temporal %35               │
           • Context Relevance %25      │
                    │                   │
              ┌─────┴─────┐             │
              │           │             │
           PASSED      FAILED ──────────┘
              │         (max 1 retry)
              ▼
         Sonuç döner
```

- **Writer Agent:** Yaratıcı hikaye üretimi, system prompt + RAG bağlam + karakter bilgisi
- **Consistency Agent:** Anti-hallucination doğrulama — ölü karakterleri diriltme, lokasyon tutarsızlığı, zaman çelişkisi tespiti
- **relationshipGraphService:** Gemini Function Calling ile otomatik karakter ilişki grafı extraction
- **Event Decay:** Çözülmemiş olaylar her bölümde × 0.95 azaltılır
- **Lore-book:** Hikaye kuralları, dünya bilgisi, canon tracking (StoryWorldState)

---

## Yeni API Endpoint'leri (Codex / Timeline / Stats)

### Story Codex (Ansiklopedi)
```
GET /api/stories/:id/codex
  → Entity'ler türe göre gruplanmış (character, location, object, faction)
  → Lore kuralları listesi
  → Karakter ilişkileri
  → Mobile: codex_screen.dart (4 tab)
  → Web: story.ejs sidebar panel
```

### Story Timeline (Kronoloji)
```
GET /api/stories/:id/timeline
  → Olaylar bölüm bazlı gruplanmış (chapterNum sıralaması)
  → impact: major/minor/twist filtreleme
  → İlişkili entity isimleri
```

### Reading Stats (İstatistikler)
```
GET /api/stats/reading
  → Toplam hikaye/bölüm sayısı
  → Tahmini kelime sayısı (bölüm × 1000)
  → Tür dağılımı (genreCounts)
  → Günlük streak bilgisi
```

---

## Mood Dynamic Theme Sistemi

Her hikaye türü için farklı accent renk paleti:
| Tür | Renk | Hex |
|-----|------|-----|
| fantasy | Mor/Altın | #9C27B0 |
| scifi | Cyan/Neon | #00BCD4 |
| horror | Kırmızı | #F44336 |
| romance | Pembe | #E91E63 |
| mystery | Amber | #FF9800 |
| adventure | Yeşil | #4CAF50 |

- **Mobile:** `story_screen.dart`'ta `_accent` getter ile tür bazlı renk
- **Web:** `story.ejs`'de CSS custom property ile dinamik renk
