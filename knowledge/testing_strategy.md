# StoryForge — Test Stratejisi ve Kuralları

## ANA KURAL

> **Yazılan veya değiştirilen her kod parçası (en küçük bir `util` fonksiyonu bile olsa) ilgili test senaryolarıyla birlikte teslim edilmeli ve mevcut testlerin bozulmadığından emin olunmalıdır.**

Bu kural istisnasızdır. Test olmadan kod kabul edilmez.

---

## Test Altyapısı

### Backend

| Bileşen | Teknoloji |
|---------|-----------|
| Test Framework | **Jest** |
| Assertion | Jest built-in (`expect`, `toBe`, `toEqual`, vb.) |
| Mock | Jest mock (`jest.mock`, `jest.fn`, `jest.spyOn`) |
| HTTP Test | **supertest** |
| Test DB | In-memory mock VEYA test PostgreSQL (Docker) |
| Konum | `backend/__tests__/` dizini |
| Çalıştırma | `npx jest` |

### Mobile (Flutter)

| Bileşen | Teknoloji |
|---------|-----------|
| Test Framework | **flutter_test** (built-in) |
| Widget Test | `WidgetTester` |
| Mock | `mockito` (gerekirse eklenmeli) |
| Konum | `mobile/test/` dizini |
| Çalıştırma | `flutter test` |

---

## Backend Test Kuralları

### Dosya Yapısı

> **Mevcut Durum:** Jest kurulu ve çalışıyor — 5 suite, 54 test geçiyor.

#### Mevcut Test Dosyaları (Çalışan)
```
backend/__tests__/
├── unit/
│   ├── services/
│   │   ├── agentOrchestratorService.test.js  # Multi-Agent pipeline testleri
│   │   ├── cacheService.test.js              # Redis cache testleri
│   │   ├── consistencyAgentService.test.js   # RAG Triad doğrulama testleri
│   │   └── relationshipGraphService.test.js  # İlişki grafı testleri
│   └── controllers/
│       └── apiController.codex.test.js       # Codex API endpoint testleri
└── helpers/
    ├── mockPrisma.js       # Prisma mock factory (tüm modeller)
    └── mockRedis.js        # Redis mock
```

#### Planlanmış Test Dosyaları (Henüz Yazılmadı)
```
backend/__tests__/
├── unit/
│   ├── services/
│   │   ├── authService.test.js
│   │   ├── storyService.test.js
│   │   ├── geminiService.test.js
│   │   ├── storyMemoryService.test.js
│   │   ├── socialService.test.js
│   │   ├── friendService.test.js
│   │   ├── messageService.test.js
│   │   ├── coopService.test.js
│   │   ├── levelService.test.js
│   │   ├── questService.test.js
│   │   ├── achievementService.test.js
│   │   ├── notificationService.test.js
│   │   ├── blockService.test.js
│   │   ├── cacheService.test.js
│   │   └── characterService.test.js
│   └── middleware/
│       ├── auth.test.js
│       ├── sanitize.test.js
│       └── errorHandler.test.js
├── integration/
│   ├── auth.test.js
│   ├── stories.test.js
│   ├── social.test.js
│   ├── friends.test.js
│   ├── messages.test.js
│   ├── coop.test.js
│   └── gamification.test.js
└── helpers/
    ├── testSetup.js       # Global setup/teardown
    ├── mockPrisma.js      # Prisma mock factory
    ├── mockRedis.js       # Redis mock
    ├── testFactory.js     # Test veri factory'leri
    └── testUtils.js       # Yardımcı fonksiyonlar
```

### İsimlendirme Kuralları

- Dosya adı: `<orijinalDosyaAdı>.test.js` (camelCase)
- Describe bloku: Servis/modül adı
- Test adı: `should <ne yapması bekleniyor>` formatı (İngilizce)

### Unit Test Şablonu (Service)

```javascript
// backend/__tests__/unit/services/authService.test.js

const authService = require('../../../src/services/authService');
const prisma = require('../../../src/config/database');

// Prisma'yı mock'la
jest.mock('../../../src/config/database', () => ({
  user: {
    findUnique: jest.fn(),
    create: jest.fn(),
    findFirst: jest.fn(),
  },
  userStats: {
    create: jest.fn(),
  },
}));

describe('AuthService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createUser', () => {
    it('should create a new user with hashed password', async () => {
      const userData = {
        email: 'test@example.com',
        username: 'testuser',
        password: 'Test1234',
      };

      prisma.user.create.mockResolvedValue({
        id: 1,
        ...userData,
        password: 'hashed_password',
      });

      prisma.userStats.create.mockResolvedValue({});

      const result = await authService.createUser(
        userData.email,
        userData.username,
        userData.password
      );

      expect(prisma.user.create).toHaveBeenCalledTimes(1);
      expect(result).toHaveProperty('id');
      expect(result.email).toBe(userData.email);
    });

    it('should throw error if email already exists', async () => {
      prisma.user.findFirst.mockResolvedValue({ id: 1 });

      await expect(
        authService.createUser('existing@email.com', 'user', 'Pass1234')
      ).rejects.toThrow();
    });
  });

  describe('validatePassword', () => {
    it('should accept valid password (8+ chars, uppercase, lowercase, digit)', () => {
      expect(() => authService.validatePassword('ValidPass1')).not.toThrow();
    });

    it('should reject password shorter than 8 characters', () => {
      expect(() => authService.validatePassword('Short1')).toThrow();
    });

    it('should reject password without uppercase letter', () => {
      expect(() => authService.validatePassword('nouppcase1')).toThrow();
    });

    it('should reject password without lowercase letter', () => {
      expect(() => authService.validatePassword('NOLOWER1')).toThrow();
    });

    it('should reject password without digit', () => {
      expect(() => authService.validatePassword('NoDigitHere')).toThrow();
    });
  });
});
```

### Unit Test Şablonu (Middleware)

```javascript
// backend/__tests__/unit/middleware/sanitize.test.js

const { sanitizeBody } = require('../../../src/middleware/sanitize');

describe('Sanitize Middleware', () => {
  let req, res, next;

  beforeEach(() => {
    req = { body: {} };
    res = {};
    next = jest.fn();
  });

  it('should sanitize XSS from specified fields', () => {
    req.body = {
      username: '<script>alert("xss")</script>testuser',
      email: 'test@example.com',
    };

    const middleware = sanitizeBody(['username']);
    middleware(req, res, next);

    expect(req.body.username).not.toContain('<script>');
    expect(req.body.email).toBe('test@example.com');
    expect(next).toHaveBeenCalled();
  });

  it('should not modify non-string fields', () => {
    req.body = { count: 42 };

    const middleware = sanitizeBody(['count']);
    middleware(req, res, next);

    expect(req.body.count).toBe(42);
    expect(next).toHaveBeenCalled();
  });
});
```

### Integration Test Şablonu (API Endpoint)

```javascript
// backend/__tests__/integration/auth.test.js

const request = require('supertest');
const app = require('../../src/app');

// Mock dış bağımlılıkları
jest.mock('../../src/config/database');
jest.mock('../../src/config/redis');

describe('Auth API', () => {
  describe('POST /api/auth/register', () => {
    it('should register a new user and return JWT token', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'new@example.com',
          username: 'newuser',
          password: 'ValidPass1',
        })
        .expect(201);

      expect(res.body).toHaveProperty('token');
      expect(res.body).toHaveProperty('user');
      expect(res.body.user.email).toBe('new@example.com');
    });

    it('should return 400 for invalid email', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'invalid-email',
          username: 'user',
          password: 'ValidPass1',
        })
        .expect(400);

      expect(res.body).toHaveProperty('error');
    });

    it('should return 400 for weak password', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'test@example.com',
          username: 'user',
          password: '123',
        })
        .expect(400);

      expect(res.body).toHaveProperty('error');
    });
  });

  describe('POST /api/auth/login', () => {
    it('should login with valid credentials and return token', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'existing@example.com',
          password: 'ValidPass1',
        })
        .expect(200);

      expect(res.body).toHaveProperty('token');
    });

    it('should return 401 for wrong password', async () => {
      await request(app)
        .post('/api/auth/login')
        .send({
          email: 'existing@example.com',
          password: 'WrongPass1',
        })
        .expect(401);
    });
  });
});
```

### Test Veri Factory Şablonu

```javascript
// backend/__tests__/helpers/testFactory.js

const bcrypt = require('bcryptjs');

const testFactory = {
  user(overrides = {}) {
    return {
      id: 1,
      email: 'test@example.com',
      username: 'testuser',
      password: bcrypt.hashSync('Test1234', 12),
      profileImage: null,
      language: 'tr',
      theme: 'dark',
      fontSize: 16,
      pushToken: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      ...overrides,
    };
  },

  story(overrides = {}) {
    return {
      id: 1,
      userId: 1,
      title: 'Test Hikayesi',
      genre: 'fantasy',
      mood: 'epic',
      summary: '',
      interactionId: 'test-interaction-id',
      isActive: true,
      isCompleted: false,
      createdAt: new Date(),
      updatedAt: new Date(),
      ...overrides,
    };
  },

  chapter(overrides = {}) {
    return {
      id: 1,
      storyId: 1,
      chapterNumber: 1,
      content: 'Bu bir test bölümüdür. Karanlık bir ormanda yürüyorsun...',
      choices: JSON.stringify([
        { id: 1, text: 'Sola dön' },
        { id: 2, text: 'Sağa dön' },
        { id: 3, text: 'Geri dön' },
      ]),
      selectedChoice: null,
      imageData: null,
      interactionId: 'test-interaction-id',
      summary: 'Kahraman karanlık ormanda seçim yapmak zorunda.',
      createdAt: new Date(),
      ...overrides,
    };
  },

  friendship(overrides = {}) {
    return {
      id: 1,
      senderId: 1,
      receiverId: 2,
      status: 'PENDING',
      createdAt: new Date(),
      updatedAt: new Date(),
      ...overrides,
    };
  },

  message(overrides = {}) {
    return {
      id: 1,
      senderId: 1,
      receiverId: 2,
      content: 'Merhaba!',
      messageType: 'text',
      imageUrl: null,
      isRead: false,
      createdAt: new Date(),
      ...overrides,
    };
  },

  sharedStory(overrides = {}) {
    return {
      id: 1,
      storyId: 1,
      userId: 1,
      isPublic: true,
      createdAt: new Date(),
      ...overrides,
    };
  },

  coopSession(overrides = {}) {
    return {
      id: 1,
      storyId: 1,
      hostUserId: 1,
      guestUserId: 2,
      currentTurn: 1,
      status: 'ACTIVE',
      createdAt: new Date(),
      updatedAt: new Date(),
      ...overrides,
    };
  },

  achievement(overrides = {}) {
    return {
      id: 1,
      key: 'first_story',
      title: 'İlk Hikaye',
      description: 'İlk hikayeni tamamla',
      icon: '📖',
      category: 'story',
      threshold: 1,
      ...overrides,
    };
  },

  userStats(overrides = {}) {
    return {
      id: 1,
      userId: 1,
      xp: 0,
      level: 1,
      storiesCompleted: 0,
      genreCounts: {},
      dailyStreak: 0,
      lastActiveDate: null,
      ...overrides,
    };
  },

  dailyQuest(overrides = {}) {
    return {
      id: 1,
      userId: 1,
      questType: 'write',
      isCompleted: false,
      rewardXp: 25,
      date: new Date(),
      ...overrides,
    };
  },

  notification(overrides = {}) {
    return {
      id: 1,
      userId: 1,
      type: 'like',
      title: 'Yeni Beğeni',
      body: 'Hikayeniz beğenildi',
      data: {},
      isRead: false,
      createdAt: new Date(),
      ...overrides,
    };
  },
};

module.exports = testFactory;
```

### Prisma Mock Şablonu

```javascript
// backend/__tests__/helpers/mockPrisma.js

const mockPrisma = {
  user: {
    findUnique: jest.fn(),
    findFirst: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  },
  story: {
    findUnique: jest.fn(),
    findFirst: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
    count: jest.fn(),
    groupBy: jest.fn(),
  },
  chapter: {
    findUnique: jest.fn(),
    findFirst: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  friendship: {
    findUnique: jest.fn(),
    findFirst: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  },
  message: {
    findMany: jest.fn(),
    create: jest.fn(),
    updateMany: jest.fn(),
  },
  sharedStory: {
    findUnique: jest.fn(),
    findFirst: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    delete: jest.fn(),
  },
  like: {
    findUnique: jest.fn(),
    create: jest.fn(),
    delete: jest.fn(),
    count: jest.fn(),
  },
  comment: {
    findMany: jest.fn(),
    create: jest.fn(),
    delete: jest.fn(),
  },
  coopSession: {
    findUnique: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  userStats: {
    findUnique: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    upsert: jest.fn(),
  },
  storyEntity: {
    findMany: jest.fn(),
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    upsert: jest.fn(),
    groupBy: jest.fn(),
  },
  storyEvent: {
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  storyWorldState: {
    findUnique: jest.fn(),
    create: jest.fn(),
    upsert: jest.fn(),
  },
  tokenUsage: {
    create: jest.fn(),
    findMany: jest.fn(),
  },
  achievement: {
    findMany: jest.fn(),
    createMany: jest.fn(),
  },
  userAchievement: {
    findMany: jest.fn(),
    create: jest.fn(),
  },
  dailyQuest: {
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  notification: {
    findMany: jest.fn(),
    create: jest.fn(),
    updateMany: jest.fn(),
  },
  block: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    delete: jest.fn(),
  },
  bookmark: {
    findUnique: jest.fn(),
    create: jest.fn(),
    delete: jest.fn(),
  },
  character: {
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  },
  $transaction: jest.fn((fn) => fn(mockPrisma)),
};

module.exports = mockPrisma;
```

---

## Mobile Test Kuralları

### Dosya İsimlendirme

```
mobile/test/
├── unit/
│   ├── models/
│   │   ├── user_test.dart
│   │   ├── story_test.dart
│   │   ├── chapter_test.dart
│   │   └── ...
│   ├── providers/
│   │   ├── auth_provider_test.dart
│   │   ├── story_provider_test.dart
│   │   └── ...
│   └── services/
│       ├── api_service_test.dart
│       └── ...
├── widget/
│   ├── choice_card_test.dart
│   ├── story_card_test.dart
│   ├── camera_button_test.dart
│   ├── typing_indicator_test.dart
│   └── connection_banner_test.dart
└── widget_test.dart               # Mevcut smoke test
```

### İsimlendirme Kuralları

- Dosya adı: `<orijinal_dosya_adi>_test.dart` (snake_case)
- Test grubu: `group('SınıfAdı', () {...})`
- Test adı: `test('açıklama', () {...})` veya `testWidgets('açıklama', ...)`

### Model Test Şablonu

```dart
// mobile/test/unit/models/user_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:storyforge_mobile/models/user.dart';

void main() {
  group('User Model', () {
    test('should create User from JSON', () {
      final json = {
        'id': 1,
        'email': 'test@example.com',
        'username': 'testuser',
        'profileImage': null,
        'language': 'tr',
        'theme': 'dark',
        'fontSize': 16,
      };

      final user = User.fromJson(json);

      expect(user.id, 1);
      expect(user.email, 'test@example.com');
      expect(user.username, 'testuser');
      expect(user.language, 'tr');
    });

    test('should convert User to JSON', () {
      final user = User(
        id: 1,
        email: 'test@example.com',
        username: 'testuser',
        language: 'tr',
        theme: 'dark',
        fontSize: 16,
      );

      final json = user.toJson();

      expect(json['email'], 'test@example.com');
      expect(json['username'], 'testuser');
    });

    test('should handle null profileImage', () {
      final json = {
        'id': 1,
        'email': 'test@example.com',
        'username': 'testuser',
        'profileImage': null,
      };

      final user = User.fromJson(json);
      expect(user.profileImage, isNull);
    });
  });
}
```

### Widget Test Şablonu

```dart
// mobile/test/widget/choice_card_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyforge_mobile/widgets/choice_card.dart';

void main() {
  group('ChoiceCard Widget', () {
    testWidgets('should display choice text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChoiceCard(
              text: 'Sola dön',
              index: 0,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Sola dön'), findsOneWidget);
    });

    testWidgets('should call onTap when pressed', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChoiceCard(
              text: 'Sağa dön',
              index: 1,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sağa dön'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
```

### Provider Test Şablonu

```dart
// mobile/test/unit/providers/auth_provider_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:storyforge_mobile/providers/auth_provider.dart';

void main() {
  group('AuthProvider', () {
    late AuthProvider provider;

    setUp(() {
      provider = AuthProvider();
    });

    test('initial state should be logged out', () {
      expect(provider.isLoggedIn, isFalse);
      expect(provider.user, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('should update loading state', () {
      // Provider'ın iç state'ini test eden senaryo
      expect(provider.isLoading, isFalse);
    });
  });
}
```

---

## Yeni Bileşen Ekleme Kontrol Listesi

### Yeni Backend Service Eklerken

- [ ] `backend/src/services/yeniService.js` oluştur
- [ ] `backend/__tests__/unit/services/yeniService.test.js` oluştur
- [ ] İlgili Prisma modellerini mock'la
- [ ] Happy path + error path testleri yaz
- [ ] Edge case'leri test et (null, boş string, geçersiz ID, vb.)
- [ ] `npx jest __tests__/unit/services/yeniService.test.js` ile çalıştır
- [ ] Tüm testleri çalıştır: `npx jest`

### Yeni API Endpoint Eklerken

- [ ] Route handler'ı (controller) oluştur
- [ ] Service fonksiyonunu oluştur
- [ ] Rate limiter kuralı ekle (`app.js`)
- [ ] Sanitization gerekiyorsa `sanitizeBody` middleware ekle
- [ ] Unit test (service) yaz
- [ ] Integration test (API endpoint) yaz
- [ ] Auth kontrolü test et (401 without token)
- [ ] Validation test et (400 for invalid input)
- [ ] Tüm testleri çalıştır

### Yeni Flutter Widget Eklerken

- [ ] `mobile/lib/widgets/yeni_widget.dart` oluştur
- [ ] `mobile/test/widget/yeni_widget_test.dart` oluştur
- [ ] Render testi yaz (widget doğru görünüyor mu?)
- [ ] Interaction testi yaz (dokunma, swipe, vb.)
- [ ] Edge case testi yaz (boş veri, uzun metin, null değerler)
- [ ] `flutter test test/widget/yeni_widget_test.dart` ile çalıştır
- [ ] Tüm testleri çalıştır: `flutter test`

### Yeni Flutter Screen Eklerken

- [ ] Screen dosyası oluştur
- [ ] Gerekiyorsa service ve provider oluştur
- [ ] Lokalizasyon key'leri ekle (app_tr.arb + app_en.arb)
- [ ] Screen widget testi yaz
- [ ] Provider testi yaz (varsa)
- [ ] Service testi yaz (varsa)
- [ ] `flutter test` ile tüm testleri çalıştır

### Yeni Prisma Model Eklerken

- [ ] `schema.prisma`'ya model ekle
- [ ] Migration oluştur: `npx prisma migrate dev --name model_adi`
- [ ] Service fonksiyonlarını yaz
- [ ] Dart model dosyası oluştur (fromJson/toJson)
- [ ] mockPrisma.js'ye yeni model mock'unu ekle
- [ ] testFactory.js'ye factory fonksiyonu ekle
- [ ] Unit + integration testleri yaz
- [ ] Tüm testleri çalıştır

---

## Test Çalıştırma Komutları

### Backend
```bash
# Tüm testleri çalıştır
cd backend && npx jest

# Tek dosya
npx jest __tests__/unit/services/authService.test.js

# Pattern ile
npx jest --testPathPattern="auth"

# Watch mode (değişikliklerde otomatik çalışır)
npx jest --watch

# Coverage raporu
npx jest --coverage

# Verbose
npx jest --verbose

# Docker container içinde
docker exec -it storyforge-backend npx jest
```

### Mobile
```bash
# Tüm testleri çalıştır
cd mobile && flutter test

# Tek dosya
flutter test test/unit/models/user_test.dart

# Coverage
flutter test --coverage

# Verbose
flutter test --reporter expanded
```

---

## Jest Yapılandırması (package.json'a eklenecek)

```json
{
  "jest": {
    "testEnvironment": "node",
    "roots": ["<rootDir>/__tests__"],
    "testMatch": ["**/*.test.js"],
    "collectCoverageFrom": [
      "src/**/*.js",
      "!src/server.js",
      "!src/views/**",
      "!src/public/**"
    ],
    "coverageThreshold": {
      "global": {
        "branches": 60,
        "functions": 70,
        "lines": 70,
        "statements": 70
      }
    },
    "setupFilesAfterSetup": ["<rootDir>/__tests__/helpers/testSetup.js"]
  }
}
```

---

## Test Yazarken Dikkat Edilecekler

### YAPILMALI ✅
- Her `describe` bloğunda `beforeEach(() => jest.clearAllMocks())` kullan
- Pozitif ve negatif senaryoları birlikte test et
- Edge case'leri kapsa (null, undefined, boş array, max length, vb.)
- Asenkron testlerde `async/await` kullan
- Mock'ları minimum tutunsal — sadece dış bağımlılıkları mock'la
- Hata mesajlarını doğrula (`toThrow('beklenen mesaj')`)
- DB transaction'larını test et (özellikle co-op)

### YAPILMAMALI ❌
- Implementation detail'lerini test etme (sadece davranışı test et)
- Birden fazla şeyi tek test'te test etme
- Test'ler arasında state paylaşma (her test izole olmalı)
- console.log'ları test'te bırakma
- Gerçek API çağrıları yapma (her zaman mock kullan)
- Gerçek veritabanı bağlantısı açma (unit test'te)
- Sleep/timeout ile test senkronizasyonu yapma
