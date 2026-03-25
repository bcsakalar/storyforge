# StoryForge — Veritabanı Şeması ve State Management

## Veritabanı Teknolojileri

| Bileşen | Teknoloji | Kullanım |
|---------|-----------|----------|
| Ana Veritabanı | PostgreSQL 16 | Tüm kalıcı veriler |
| Vektör Aramalar | pgvector eklentisi | RAG embedding'leri (768 boyut) |
| ORM | Prisma | Tüm DB işlemleri (raw SQL yasak) |
| Cache | Redis 7 (ioredis) | Session store, hikaye cache, günlük token sayacı |
| Session Store | connect-pg-simple | Web oturumları (PostgreSQL-backed) |
| Yerel DB (Mobile) | Hive | Offline cache (hikayeler, kullanıcı bilgisi) |
| Güvenli Depolama | FlutterSecureStorage | JWT token, hassas veriler |

---

## Prisma Şeması — Tam Model Haritası

> Kaynak: `backend/prisma/schema.prisma`

### Enum'lar

```prisma
enum FriendshipStatus {
  PENDING    // İstek gönderildi, cevap bekleniyor
  ACCEPTED   // Arkadaşlık kabul edildi
  REJECTED   // Arkadaşlık reddedildi
}

enum CoopStatus {
  WAITING    // Davet gönderildi, misafir bekleniyor
  ACTIVE     // Oyun devam ediyor
  COMPLETED  // Hikaye tamamlandı
  REJECTED   // Davet reddedildi
}
```

### Çekirdek Modeller (Core)

#### User (Kullanıcı)
```prisma
model User {
  id           Int      @id @default(autoincrement())
  email        String   @unique
  username     String   @unique
  password     String                    // bcryptjs ile hash'lenmiş (12 round)
  profileImage String?  @map("profile_image")
  language     String   @default("tr")   // "tr" | "en"
  theme        String   @default("dark") // "dark" | "light"
  fontSize     Int      @default(16)     // 12-24 arası
  pushToken    String?  @map("push_token")
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

  // İlişkiler
  stories, sentFriendships, receivedFriendships,
  sentMessages, receivedMessages, sharedStories,
  likes, comments, hostedCoopSessions, guestCoopSessions,
  characters, achievements, stats, dailyQuests,
  notifications, blockedUsers, blockedByUsers,
  reports, bookmarks, deviceTokens

  @@map("users")
}
```

#### Story (Hikaye)
```prisma
model Story {
  id            Int      @id @default(autoincrement())
  userId        Int                        // Sahibi
  title         String
  genre         String                     // "fantasy", "scifi", "horror", vb.
  mood          String?                    // Ruh hali (UI temalandırma)
  summary       String   @default("")     // AI tarafından üretilen özet
  interactionId String?                    // Gemini interaction ID (oturum devamlılığı)
  isActive      Boolean  @default(true)    // Devam edebilir mi?
  isCompleted   Boolean  @default(false)   // Bitmiş mi?
  createdAt     DateTime
  updatedAt     DateTime

  // İlişkiler
  chapters, sharedStories, coopSessions, characters,
  entities (RAG), events (RAG), worldStates (RAG)

  @@map("stories")
}
```

#### Chapter (Bölüm)
```prisma
model Chapter {
  id             Int      @id @default(autoincrement())
  storyId        Int                        // Hangi hikayeye ait
  chapterNumber  Int                        // Sıra numarası (1, 2, 3...)
  content        String                     // Bölüm metni (tam)
  choices        Json     @default("[]")    // [{id: 1, text: "..."}, ...]
  selectedChoice Int?                       // Kullanıcının seçtiği seçenek (null=henüz seçilmedi)
  imageData      String?                    // Kullanıcının gönderdiği fotoğraf (base64)
  interactionId  String                     // Gemini interaction ID
  summary        String?                    // AI tarafından üretilen bölüm özeti
  createdAt      DateTime

  @@map("chapters")
}
```

### Sosyal Modeller

#### Friendship (Arkadaşlık)
```prisma
model Friendship {
  id         Int              @id @default(autoincrement())
  senderId   Int              // İsteği gönderen
  receiverId Int              // İsteği alan
  status     FriendshipStatus @default(PENDING)
  createdAt  DateTime
  updatedAt  DateTime

  @@unique([senderId, receiverId])   // Aynı çift için tek kayıt
  @@index([receiverId])              // Alıcı bazlı hızlı sorgu
  @@map("friendships")
}
```

#### Message (Mesaj)
```prisma
model Message {
  id          Int      @id @default(autoincrement())
  senderId    Int
  receiverId  Int
  content     String
  messageType String   @default("text")    // "text" | "image"
  imageUrl    String?                      // Görsel mesaj URL'si
  isRead      Boolean  @default(false)
  createdAt   DateTime

  @@index([senderId, receiverId])          // Konuşma bazlı sorgu
  @@index([receiverId, createdAt])         // Yeni mesaj sorgulama
  @@map("messages")
}
```

#### SharedStory (Paylaşılan Hikaye)
```prisma
model SharedStory {
  id        Int      @id @default(autoincrement())
  storyId   Int
  userId    Int
  isPublic  Boolean  @default(false)       // Herkes görebilir mi?
  createdAt DateTime

  likes, comments, bookmarks

  @@unique([storyId, userId])              // Aynı hikaye bir kez paylaşılır
  @@index([isPublic, createdAt])           // Galeri sorgulama
  @@map("shared_stories")
}
```

#### Like, Comment, Bookmark
```prisma
model Like {
  userId, sharedStoryId
  @@unique([userId, sharedStoryId])        // Tek beğeni kısıtı
}

model Comment {
  userId, sharedStoryId, content (max 1000 karakter)
  @@index([sharedStoryId, createdAt])      // Hikaye bazlı yorumlar
}

model Bookmark {
  userId, sharedStoryId
  @@unique([userId, sharedStoryId])        // Tek yer imi kısıtı
}
```

### Co-op Modeli

```prisma
model CoopSession {
  id          Int        @id @default(autoincrement())
  storyId     Int                          // Paylaşılan hikaye
  hostUserId  Int                          // Ev sahibi
  guestUserId Int?                         // Misafir (null = henüz katılmadı)
  currentTurn Int        @default(1)       // 1 = Host, 2 = Guest
  status      CoopStatus @default(WAITING)

  @@map("coop_sessions")
}
```

### Gamification Modelleri

#### Achievement & UserAchievement
```prisma
model Achievement {
  id          Int    @id @default(autoincrement())
  key         String @unique              // "first_story", "genre_master_fantasy" vb.
  title       String                      // Görünen başlık
  description String                      // Açıklama
  icon        String                      // Emoji/icon
  category    String                      // "story" | "genre" | "social" | "coop" | "streak" | "level"
  threshold   Int    @default(1)          // Kilit açma eşiği
}

model UserAchievement {
  userId, achievementId, unlockedAt
  @@unique([userId, achievementId])       // Tek kilit açma
}
```

#### UserStats
```prisma
model UserStats {
  userId           Int   @unique
  xp               Int   @default(0)
  level            Int   @default(1)       // Formül: Math.sqrt(xp / 100)
  storiesCompleted Int   @default(0)
  genreCounts      Json  @default("{}")    // {"fantasy": 5, "horror": 3}
  dailyStreak      Int   @default(0)
  lastActiveDate   DateTime?
}
```

#### DailyQuest
```prisma
model DailyQuest {
  userId      Int
  questType   String                      // "write" | "complete" | "share" | "friend" | "message" | "like" | "start"
  isCompleted Boolean  @default(false)
  rewardXp    Int      @default(25)
  date        DateTime @db.Date           // Hangi güne ait

  @@index([userId, date])
}
```

### Altyapı Modelleri

#### Notification
```prisma
model Notification {
  userId, type, title, body
  data      Json    @default("{}")        // Ek veri (storyId, friendId, vb.)
  isRead    Boolean @default(false)

  @@index([userId, isRead])
}
```

#### DeviceToken (FCM Push)
```prisma
model DeviceToken {
  userId    Int
  token     String   @unique              // FCM registration token
  platform  String   @default("android")  // "android" | "ios" | "web"
}
```

#### Block & Report
```prisma
model Block {
  blockerId, blockedId
  @@unique([blockerId, blockedId])        // Tek yönlü engel
}

model Report {
  reporterId  Int
  targetType  String                      // "user" | "story" | "comment"
  targetId    Int
  reason      String
  description String?
  status      String  @default("pending") // "pending" | "reviewed" | "resolved"
  @@index([status])
}
```

### RAG / Hafıza Modelleri (pgvector)

#### StoryEntity
```prisma
model StoryEntity {
  storyId          Int
  type             String                      // "character" | "location" | "object" | "faction"
  name             String
  description      String   @db.Text
  attributes       Json     @default("{}")     // Dinamik özellikler
  embedding        Unsupported("vector(768)")? // pgvector — 768 boyutlu vektör
  firstSeen        Int      @default(1)        // İlk görüldüğü bölüm
  lastSeen         Int      @default(1)        // Son görüldüğü bölüm
  importance       Float    @default(0.5)      // 0.0 - 1.0 arası önem
  status           String   @default("active") // "active" | "dead" | "missing" | "transformed" | "inactive"
  statusHistory    Json     @default("[]")     // [{chapter, from, to, reason}]
  relationships    Json     @default("[]")     // [{targetName, type, since, description}]

  @@unique([storyId, type, name])         // Aynı entity tekrar oluşmaz
  @@index([storyId, type])
  @@index([storyId, importance])
  @@index([storyId, status])
}
```

#### StoryEvent
```prisma
model StoryEvent {
  storyId        Int
  chapterNum     Int
  description    String   @db.Text
  impact         String   @default("minor")  // "major" | "minor" | "twist"
  entities       String[]                     // İlişkili entity isimleri
  embedding      Unsupported("vector(768)")?
  relevanceDecay Float    @default(1.0)       // Her bölümde × 0.95 azalır (çözülmemişse)
  isResolved     Boolean  @default(false)     // Olay çözüldü mü?

  @@index([storyId, chapterNum])
  @@index([storyId, impact])
  @@index([storyId, isResolved])
}
```

#### StoryWorldState
```prisma
model StoryWorldState {
  storyId    Int
  chapterNum Int
  state      Json                         // {activeQuests, relationships, worldFacts, mood}

  @@unique([storyId, chapterNum])         // Bölüm başına tek snapshot
}
```

#### TokenUsage (Maliyet Takibi)
```prisma
model TokenUsage {
  userId       Int
  storyId      Int?
  model        String   @default("gemini-3-flash-preview")
  inputTokens  Int      @default(0)
  outputTokens Int      @default(0)
  operation    String   @default("generate")  // "generate" | "embed" | "extract" | "summary" | "tts"

  @@index([userId, createdAt])
  @@index([storyId])
}
```

#### StoryExport
```prisma
model StoryExport {
  storyId  Int
  format   String  @default("pdf")
  url      String
}
```

---

## Migration Geçmişi

| Migration | Tarih | İçerik |
|-----------|-------|--------|
| `20260310213617_init` | 10 Mar 2026 | User, Story, Chapter — temel tablolar |
| `20260311020647_add_all_models` | 11 Mar 2026 | Tüm sosyal/gamification modelleri |
| `20260313062917_add_block_report_bookmark_message_type` | 13 Mar 2026 | Block, Report, Bookmark, messageType |
| `20260313070000_add_device_tokens` | 13 Mar 2026 | DeviceToken tablosu (FCM) |
| `20260313080000_add_memory_system` | 13 Mar 2026 | RAG modelleri (StoryEntity, StoryEvent, StoryWorldState, TokenUsage) |

---

## Redis Kullanımı

| Amaç | Key Pattern | TTL | Açıklama |
|------|-------------|-----|----------|
| Hikaye Bağlamı | `story:{storyId}:context` | 1 saat | Son bölümlerin cache'i (prompt boyutu azaltma) |
| Entity Cache | `story:{storyId}:entities` | 30 dk | Hikaye entity'leri (codex hızlandırma) |
| Lore Cache | `story:{storyId}:lore` | 30 dk | Hikaye lore kuralları |
| Relationship Cache | `story:{storyId}:relationships` | 30 dk | Karakter ilişki grafı |
| Summary Cache | `story:{storyId}:summary` | 1 saat | Hikaye özeti (quick/deep) |
| Günlük Token Sayacı | `user:{userId}:tokens:daily` | 24 saat | Kullanıcı başına günlük API kullanımı |
| Session Store | Managed by connect-pg-simple | Session maxAge | Web oturumları (PostgreSQL'de, Redis'te değil) |

**Not:** Session verileri PostgreSQL'de saklanır (connect-pg-simple), Redis değil. Redis yalnızca uygulama cache'i için kullanılır. Cache yönetimi `cacheService.js` üzerinden yapılır.

---

## State Management (Mobile — Flutter)

### Provider Pattern

Tüm state management `ChangeNotifier + Provider` pattern'i ile yapılır.

```dart
// main.dart'ta MultiProvider sarmalayıcısı
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => StoryProvider()),
    ChangeNotifierProvider(create: (_) => FriendProvider()),
    ChangeNotifierProvider(create: (_) => MessageProvider()),
    ChangeNotifierProvider(create: (_) => SocialProvider()),
    ChangeNotifierProvider(create: (_) => CoopProvider()),
    ChangeNotifierProvider(create: (_) => NotificationProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
  ],
  child: StoryForgeApp(),
)
```

### Provider Sorumlulukları

| Provider | State |İşlemler |
|----------|-------|---------|
| `AuthProvider` | `user`, `isLoggedIn`, `isLoading` | login, register, logout, autoLogin, refreshProfile |
| `StoryProvider` | `stories[]`, `currentStory`, `isCreating`, `streamingText` | fetchStories, createStory (streaming), makeChoice, deleteStory |
| `FriendProvider` | `friends[]`, `pendingRequests[]`, `searchResults[]` | sendRequest, accept, reject, removeFriend, search |
| `MessageProvider` | `conversations[]`, `messages{}`, `unreadCount` | fetchConversations, fetchMessages, sendMessage, markRead |
| `SocialProvider` | `publicStories[]`, `feedStories[]` | fetchGallery, fetchFeed, like, unlike, addComment |
| `CoopProvider` | `invites[]`, `activeSessions[]`, `currentSession` | createSession, join, reject, makeChoice |
| `NotificationProvider` | `notifications[]`, `unreadCount` | fetchAll, markRead, markAllRead |
| `ThemeProvider` | `isDarkMode`, `fontSize`, `locale` | toggleTheme, setFontSize, setLocale |

### Yerel Depolama Stratejisi

```
┌─────────────────────────────────────────────────────────┐
│                    Mobile Depolama                       │
│                                                         │
│  FlutterSecureStorage        Hive                       │
│  ─────────────────           ────                       │
│  • JWT Token                 • Offline hikaye cache     │
│  • Refresh Token             • Kullanıcı tercihleri     │
│  • Sunucu adresi             • Son görülen veriler     │
│                                                         │
│  SharedPreferences                                      │
│  ─────────────────                                      │
│  • Tema (dark/light)                                    │
│  • Dil (tr/en)                                         │
│  • Font boyutu                                          │
│  • İlk açılış flag'i                                    │
└─────────────────────────────────────────────────────────┘
```

### Offline Desteği

`OfflineService` Hive kullanarak offline-first yaklaşım sağlar:

1. **Online:** API'den veri çek → Hive'a cache'le → UI'ye göster
2. **Offline:** Hive'dan oku → UI'ye göster → Bağlantı geldiğinde senkronize et
3. **Bağlantı Tespiti:** `connectivity_plus` paketi ile gerçek zamanlı izleme
4. **Banner:** `ConnectionBanner` widget'ı ile offline durumu kullanıcıya gösterme
