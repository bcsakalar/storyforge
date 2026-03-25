# StoryForge — Klasör Yapısı ve Dosya Açıklamaları

## Kök Dizin

```
storyforge/
├── AGENTS.md                   # AI ajanları için ana kılavuz
├── MEMORY.md                   # Dinamik hafıza — güncel durum ve TODO
├── .github/
│   └── copilot-instructions.md # GitHub Copilot talimatları
├── knowledge/                  # Projeye özel bilgi tabanı
│   ├── architecture.md
│   ├── directory_structure.md  # (bu dosya)
│   ├── database_and_state.md
│   ├── business_logic.md
│   ├── commands_and_scripts.md
│   └── testing_strategy.md
├── .agents/skills/             # Genel yazılım becerileri ve teknoloji kuralları
├── docker-compose.yml          # Production Docker konfigürasyonu
├── docker-compose.override.yml # Dev-only overrides (git-ignored)
├── README.md                   # Proje tanıtımı
├── DEPLOY.md                   # Deployment rehberi
├── AI_KAVRAMLARI.md            # AI kavramları ve teknik açıklamalar
├── backend/                    # Node.js + Express backend
└── mobile/                     # Flutter mobile uygulama
```

---

## Backend Yapısı

```
backend/
├── Dockerfile                                      # Node 20 Alpine + Chromium (Puppeteer PDF)
├── package.json                                    # Bağımlılıklar ve npm scripts
├── jest.config.js                                  # Jest test konfigürasyonu
├── flutter-mobile-1c9ce-firebase-adminsdk-*.json   # Firebase service account (FCM için)
│
├── prisma/
│   ├── schema.prisma           # Veritabanı şeması (25+ model, pgvector)
│   └── migrations/             # Prisma migration dosyaları
│       ├── migration_lock.toml
│       ├── 20260310213617_init/
│       ├── 20260311020647_add_all_models/
│       ├── 20260313062917_add_block_report_bookmark_message_type/
│       ├── 20260313070000_add_device_tokens/
│       └── 20260313080000_add_memory_system/
│
├── __tests__/                  # Jest test dosyaları
│   ├── unit/
│   │   ├── services/
│   │   │   ├── agentOrchestratorService.test.js
│   │   │   ├── cacheService.test.js
│   │   │   ├── consistencyAgentService.test.js
│   │   │   └── relationshipGraphService.test.js
│   │   └── controllers/
│   │       └── apiController.codex.test.js
│   └── helpers/
│       ├── mockPrisma.js       # Prisma mock factory
│       └── mockRedis.js        # Redis mock
│
└── src/
    ├── app.js                  # Express uygulaması — middleware, rate limiter, route mounting
    ├── server.js               # HTTP server + Socket.io başlatma (entry point)
    │
    ├── config/                 # Bağlantı ve yapılandırma modülleri
    │   ├── database.js         # Prisma client singleton
    │   ├── redis.js            # ioredis client (lazyConnect)
    │   ├── gemini.js           # @google/genai client başlatma
    │   ├── socket.js           # Socket.io server + tüm event handler'lar
    │   ├── session.js          # express-session + connect-pg-simple (PG session store)
    │   ├── firebase.js         # firebase-admin SDK başlatma
    │   └── upload.js           # Multer disk storage konfigürasyonu
    │
    ├── middleware/              # Express middleware'leri
    │   ├── auth.js             # requireAuth() (web session) + requireApiAuth() (dual auth)
    │   ├── errorHandler.js     # Merkezi hata yakalama (JSON/EJS)
    │   └── sanitize.js         # XSS koruması — sanitizeBody(fields) middleware factory
    │
    ├── controllers/            # Route handler'lar (request/response katmanı)
    │   ├── authController.js   # Kayıt/giriş/çıkış (web + API)
    │   ├── storyController.js  # Web hikaye yönetimi (EJS render)
    │   └── apiController.js    # Mobile/API: tüm REST endpoint handler'ları
    │
    ├── routes/                 # Express route tanımları
    │   ├── authRoutes.js       # /login, /register, /logout (web)
    │   ├── storyRoutes.js      # /dashboard, /story/* (web, EJS)
    │   └── apiRoutes.js        # /api/* tüm REST API route'ları (mobile + API)
    │
    ├── services/               # İş mantığı katmanı (controller'lardan bağımsız)
    │   ├── authService.js          # Kullanıcı CRUD, parola hash/verify, doğrulama
    │   ├── storyService.js         # Hikaye oluşturma, seçim, ağaç, dallanma, özet
    │   ├── geminiService.js        # Gemini API: hikaye üretimi, TTS, özet, function calling
    │   ├── storyMemoryService.js   # RAG: entity extraction, embedding, pgvector retrieval
    │   ├── socialService.js        # Paylaşım, beğeni, yorum, galeri, feed
    │   ├── friendService.js        # Arkadaşlık istekleri, kabul/red, arama
    │   ├── messageService.js       # Mesajlaşma, okundu bilgisi
    │   ├── coopService.js          # İki oyunculu co-op oturumları
    │   ├── characterService.js     # Hikaye karakteri CRUD
    │   ├── levelService.js         # XP, seviye hesaplama, streak
    │   ├── questService.js         # Günlük görevler
    │   ├── achievementService.js   # Başarımlar (24 tanım, otomatik kilit açma, seed)
    │   ├── notificationService.js  # DB + Socket.io + FCM bildirimler
    │   ├── pushService.js          # Firebase Cloud Messaging
    │   ├── blockService.js         # Kullanıcı engelleme
    │   ├── cacheService.js         # Redis cache yönetimi (entity, lore, relationship, summary)
    │   ├── agentOrchestratorService.js  # Multi-Agent pipeline: Writer → Consistency → Retry
    │   ├── consistencyAgentService.js   # RAG Triad anti-hallucination doğrulama
    │   ├── relationshipGraphService.js  # Karakter ilişki grafı extraction + yönetim
    │   └── exportService.js        # Hikaye PDF export (Puppeteer)
    │
    ├── views/                  # EJS template'leri (web arayüzü)
    │   ├── layout.ejs              # Ana layout (navbar, head, footer)
    │   ├── pages/
    │   │   ├── login.ejs           # Giriş formu
    │   │   ├── register.ejs        # Kayıt formu
    │   │   ├── dashboard.ejs       # Ana panel (hikaye listesi)
    │   │   ├── newStory.ejs        # Yeni hikaye oluşturma
    │   │   ├── story.ejs           # Hikaye okuma + seçim yapma
    │   │   ├── explore.ejs         # Herkese açık galeri
    │   │   ├── sharedStory.ejs     # Paylaşılan hikaye detay
    │   │   ├── friends.ejs         # Arkadaş yönetimi
    │   │   ├── conversations.ejs   # Mesaj listesi
    │   │   ├── chat.ejs            # 1-1 sohbet
    │   │   ├── coop.ejs            # Co-op lobi
    │   │   ├── coopSession.ejs     # Co-op oturumu
    │   │   ├── profile.ejs         # Profil sayfası
    │   │   ├── achievements.ejs    # Başarımlar
    │   │   ├── quests.ejs          # Günlük görevler
    │   │   ├── notifications.ejs   # Bildirimler
    │   │   └── error.ejs           # Hata sayfası
    │   └── partials/
    │       ├── navbar.ejs          # Üst navigasyon çubuğu
    │       └── storyCard.ejs       # Hikaye kart bileşeni
    │
    ├── public/                 # Statik dosyalar
    │   ├── css/style.css           # Web CSS
    │   └── js/
    │       ├── story.js            # Hikaye okuma JS (AJAX seçim)
    │       └── realtime.js         # Socket.io client (bildirimler, online status)
    │
    └── uploads/                # Kullanıcı yüklemeleri (avatar, mesaj görselleri)
```

---

## Mobile (Flutter) Yapısı

```
mobile/
├── pubspec.yaml                # Dart bağımlılıkları
├── analysis_options.yaml       # Dart linter kuralları
├── firebase.json               # Firebase hosting config
├── l10n.yaml                   # Lokalizasyon generator config
│
├── android/                    # Android platform dosyaları
│   ├── build.gradle.kts
│   ├── settings.gradle.kts
│   ├── gradle.properties
│   ├── local.properties        # Android SDK yolu (lokal, git-ignored)
│   └── app/
│       └── build.gradle.kts    # Uygulama seviyesi gradle
│
├── ios/                        # iOS platform dosyaları
├── linux/                      # Linux desktop desteği
├── macos/                      # macOS desktop desteği
├── windows/                    # Windows desktop desteği
├── web/                        # Flutter web desteği
│
├── test/
│   └── widget_test.dart        # Temel widget smoke test
│
├── build/                      # Build artifacts (git-ignored)
│
└── lib/                        # Ana Dart kaynak kodu
    ├── main.dart               # Uygulama giriş noktası, MultiProvider setup, routing
    ├── firebase_options.dart   # Firebase konfigürasyonu (otomatik üretilmiş)
    │
    ├── l10n/                   # Lokalizasyon dosyaları
    │   ├── app_tr.arb              # Türkçe çeviriler (kaynak)
    │   ├── app_en.arb              # İngilizce çeviriler
    │   ├── app_localizations.dart  # Otomatik üretilmiş delegate + factory
    │   ├── app_localizations_tr.dart
    │   └── app_localizations_en.dart
    │
    ├── models/                 # Veri modelleri (JSON serialization dahil)
    │   ├── user.dart               # Kullanıcı profili
    │   ├── story.dart              # Hikaye + bölümler
    │   ├── chapter.dart            # Bölüm (content, choices, selectedChoice)
    │   ├── character.dart          # Hikaye karakteri
    │   ├── friendship.dart         # Arkadaşlık ilişkisi
    │   ├── message.dart            # Mesaj
    │   ├── shared_story.dart       # Paylaşılan hikaye
    │   ├── comment.dart            # Yorum
    │   ├── achievement.dart        # Başarım
    │   ├── quest.dart              # Günlük görev
    │   └── coop_session.dart       # Co-op oturumu
    │
    ├── providers/              # State management (ChangeNotifier / Provider)
    │   ├── auth_provider.dart      # Auth state, login/logout, auto-login
    │   ├── story_provider.dart     # Hikaye listesi, aktif hikaye, streaming CRUD
    │   ├── friend_provider.dart    # Arkadaşlık istekleri, arama, yönetim
    │   ├── message_provider.dart   # Konuşmalar, mesajlar, real-time güncelleme
    │   ├── social_provider.dart    # Herkese açık feed, beğeni, yorum
    │   ├── coop_provider.dart      # Co-op davetleri, oturumlar
    │   ├── notification_provider.dart # Bildirim listesi, okunmamış sayacı
    │   └── theme_provider.dart     # Tema (dark/light), font boyutu, dil (locale)
    │
    ├── services/               # API ve platform servisleri
    │   ├── api_service.dart            # Dio HTTP client, JWT interceptor, token yönetimi
    │   ├── auth_service.dart           # Login/register/logout, güvenli token saklama
    │   ├── story_service.dart          # Hikaye CRUD, multimodal create/continue
    │   ├── social_service.dart         # Paylaşım, beğeni, yorum, galeri
    │   ├── friend_service.dart         # Arkadaşlık API çağrıları
    │   ├── message_service.dart        # Mesajlaşma API çağrıları
    │   ├── coop_service.dart           # Co-op API çağrıları
    │   ├── notification_service.dart   # Bildirim API çağrıları
    │   ├── moderation_service.dart     # Engelleme/bildirim API çağrıları
    │   ├── socket_service.dart         # Socket.io client, 30+ event listener
    │   ├── offline_service.dart        # Hive local cache, connectivity izleme
    │   ├── push_notification_service.dart # FCM token kaydı, local notifications
    │   ├── export_service.dart         # PDF export (platform-aware)
    │   ├── pdf_downloader_native.dart  # Native PDF indirme
    │   ├── pdf_downloader_web.dart     # Web PDF indirme
    │   ├── pdf_downloader_stub.dart    # Stub (platform detection)
    │   ├── io_helper_native.dart       # Platform-specific I/O (native)
    │   └── io_helper_stub.dart         # Platform-specific I/O (stub)
    │
    ├── screens/                # Uygulama ekranları (21 ekran)
    │   ├── login_screen.dart           # Giriş (sunucu adresi override desteği)
    │   ├── register_screen.dart        # Kayıt formu
    │   ├── dashboard_screen.dart       # Ana panel (5 sekme navigasyon)
    │   ├── new_story_screen.dart       # Tür/ruh hali seçimi + streaming hikaye oluşturma
    │   ├── story_screen.dart           # Bölüm okuma, seçim yapma, fotoğraf çekme, mood dynamic theme
    │   ├── story_tree_screen.dart      # Görsel karar ağacı
    │   ├── codex_screen.dart           # Story Codex/Ansiklopedi (4 tab: characters, locations, items, lore)
    │   ├── character_creation_screen.dart # Karakter tanımlama
    │   ├── public_gallery_screen.dart  # Herkese açık hikaye galerisi (arama + filtreleme)
    │   ├── story_detail_public_screen.dart # Paylaşılan hikaye detay + yorumlar
    │   ├── friends_screen.dart         # Arkadaş istekleri, liste, arama
    │   ├── conversations_screen.dart   # Mesaj listesi (okunmamış badge)
    │   ├── chat_screen.dart            # 1-1 sohbet (yazım göstergesi)
    │   ├── coop_lobby_screen.dart      # Co-op davetleri + aktif oturumlar
    │   ├── coop_story_screen.dart      # Co-op hikaye oynama (sıra tabanlı)
    │   ├── profile_screen.dart         # Profil, istatistikler, başarımlar, ayarlar
    │   ├── settings_screen.dart        # Tema, font, dil ayarları
    │   ├── achievements_screen.dart    # Başarım galerisi
    │   ├── bookmarks_screen.dart       # Kaydedilen hikayeler
    │   ├── notifications_screen.dart   # Bildirimler
    │   └── daily_quests_screen.dart    # Günlük görevler + ödüller
    │
    └── widgets/                # Yeniden kullanılabilir widget'lar
        ├── choice_card.dart        # Hikaye seçenek kartı
        ├── story_card.dart         # Hikaye önizleme kartı (galeri/liste)
        ├── camera_button.dart      # Fotoğraf çekme FAB butonu
        ├── typing_indicator.dart   # Animasyonlu "... yazıyor" göstergesi
        └── connection_banner.dart  # Online/offline durum banner'ı
```

---

## Yeni Dosya Ekleme Kuralları

### Backend'e Yeni Service Eklerken
1. `backend/src/services/` altında camelCase dosya adı: `yeniService.js`
2. `backend/src/controllers/apiController.js`'ye handler ekle
3. `backend/src/routes/apiRoutes.js`'ye route ekle
4. `backend/src/app.js`'de gerekli rate limiter tanımla
5. `backend/__tests__/` altında test dosyası oluştur

### Mobile'a Yeni Ekran Eklerken
1. `mobile/lib/screens/` altında snake_case: `yeni_ekran_screen.dart`
2. Gerekiyorsa `mobile/lib/services/` altında API servis dosyası
3. State gerektiriyorsa `mobile/lib/providers/` altında provider
4. `mobile/lib/l10n/app_tr.arb` ve `app_en.arb`'ye çeviri ekle
5. `mobile/test/` altında test dosyası oluştur

### Yeni Model Eklerken
1. `backend/prisma/schema.prisma`'ya model ekle
2. `npx prisma migrate dev --name model_adi` ile migration oluştur
3. `mobile/lib/models/` altında Dart modeli oluştur (fromJson/toJson)
4. İlgili servislere CRUD fonksiyonları ekle
5. Her iki tarafta da testler yaz
