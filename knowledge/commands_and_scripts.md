# StoryForge — Komutlar ve Scriptler

## Ön Koşullar

| Araç | Minimum Versiyon | Açıklama |
|------|-----------------|----------|
| Docker & Docker Compose | v2+ | Container yönetimi |
| Node.js | v20+ | Backend geliştirme (Alpine imaj: node:20-alpine) |
| npm | v9+ | Paket yönetimi |
| Flutter SDK | v3.11+ | Mobile geliştirme |
| Dart | v3.11+ | Flutter ile birlikte gelir |
| Git | v2+ | Versiyon kontrolü |
| Android Studio / Xcode | En güncel | Mobile platform araçları |

---

## Docker ile Projeyi Ayağa Kaldırma

### 1. Ortam Değişkenlerini Hazırla

Kök dizinde `.env` dosyası oluştur:

```env
# Database
POSTGRES_PASSWORD=guclu_bir_sifre_sec

# Backend
NODE_ENV=development
PORT=3004
SESSION_SECRET=rastgele_uzun_session_secret
JWT_SECRET=rastgele_uzun_jwt_secret

# Gemini AI
GEMINI_API_KEY=google_ai_studio_dan_alinacak_api_key

# Firebase (opsiyonel — yoksa push bildirimler devre dışı kalır)
FIREBASE_SERVICE_ACCOUNT_PATH=./flutter-mobile-1c9ce-firebase-adminsdk-fbsvc-e517433bdd.json
FIREBASE_PROJECT_ID=flutter-mobile-1c9ce

# Redis
REDIS_URL=redis://redis:6379

# Backend bind (dev: tüm arayüzler, prod: sadece localhost)
BACKEND_BIND=0.0.0.0
```

### 2. Container'ları Başlat

```bash
# İlk kez veya Dockerfile değiştiyse
docker-compose up -d --build

# Sonraki çalıştırmalarda
docker-compose up -d
```

### 3. Veritabanı Migration'larını Uygula

```bash
docker exec -it storyforge-backend npx prisma migrate deploy
```

### 4. (Opsiyonel) Prisma Client Yenile

```bash
docker exec -it storyforge-backend npx prisma generate
```

### 5. Logları İzle

```bash
# Tüm servisler
docker-compose logs -f

# Sadece backend
docker-compose logs -f backend

# Sadece veritabanı
docker-compose logs -f db
```

---

## Docker Yönetimi

### Container Durumunu Kontrol Et
```bash
docker-compose ps
```

### Container'ları Durdur
```bash
docker-compose down
```

### Container'ları Sil (Volume'lar korunur)
```bash
docker-compose down
```

### Container'ları VE Volume'ları Sil (DİKKAT: Tüm veriler silinir!)
```bash
docker-compose down -v
```

### Backend Container'ına Shell Bağlantısı
```bash
docker exec -it storyforge-backend sh
```

### PostgreSQL'e Doğrudan Bağlantı
```bash
# Docker container içinden
docker exec -it storyforge-db psql -U storyforge -d storyforge

# Lokal makineden (docker-compose.override.yml aktifse, port 5432 açık)
psql -h localhost -U storyforge -d storyforge
```

### Redis CLI
```bash
docker exec -it storyforge-redis redis-cli
```

---

## Backend Geliştirme (Docker Dışı — Lokal)

> Normalde Docker tercih edilir, ancak hızlı geliştirme için lokal çalıştırma da mümkündür.

### 1. Bağımlılıkları Yükle
```bash
cd backend
npm install
```

### 2. Prisma Client Oluştur
```bash
npx prisma generate
```

### 3. Migration Uygula (Lokal PostgreSQL gerekir)
```bash
npx prisma migrate dev
```

### 4. Development Modunda Çalıştır (Auto-reload)
```bash
npm run dev
# veya
node --watch src/server.js
```

### 5. Production Modunda Çalıştır
```bash
npm start
# veya
node src/server.js
```

---

## Prisma Komutları

| Komut | Açıklama |
|-------|----------|
| `npx prisma generate` | Prisma client'ı yeniden oluştur (schema değişikliği sonrası) |
| `npx prisma migrate dev --name aciklama` | Yeni migration oluştur (dev) |
| `npx prisma migrate deploy` | Migration'ları uygula (production) |
| `npx prisma migrate reset` | DB'yi sıfırla + tüm migration'ları uygula (DİKKAT!) |
| `npx prisma studio` | Prisma Studio (görsel DB yönetimi) — tarayıcıda açılır |
| `npx prisma db push` | Schema'yı DB'ye push et (migration oluşturmadan — sadece prototyping) |
| `npx prisma db pull` | DB'den schema'yı çek (reverse engineering) |

### Docker İçinde Prisma
```bash
# Migration oluştur (container içinde)
docker exec -it storyforge-backend npx prisma migrate dev --name yeni_migration_adi

# Studio başlat (port forwarding gerekebilir)
docker exec -it storyforge-backend npx prisma studio
```

---

## Mobile (Flutter) Geliştirme

### 1. Bağımlılıkları Yükle
```bash
cd mobile
flutter pub get
```

### 2. Lokalizasyon Dosyalarını Üret
```bash
flutter gen-l10n
```

### 3. Uygulama Simgesini Güncelle
```bash
dart run flutter_launcher_icons
```

### 4. Development Modunda Çalıştır
```bash
# Bağlı cihaz/emülatöre göre
flutter run

# Belirli cihaz
flutter run -d <device_id>

# Chrome'da web olarak çalıştır
flutter run -d chrome

# Debug bilgisi ile
flutter run --verbose
```

### 5. Release APK Oluştur
```bash
flutter build apk --release
```

### 6. Release App Bundle (Google Play)
```bash
flutter build appbundle --release
```

### 7. iOS Build (macOS gerekli)
```bash
flutter build ios --release
```

### 8. Web Build
```bash
flutter build web --release
```

### 9. Cihaz Listesi
```bash
flutter devices
```

### 10. Flutter Doktor (Ortam Kontrolü)
```bash
flutter doctor -v
```

---

## Test Komutları

### Backend Testleri (Jest — Kurulu, 54 Test Geçiyor)
```bash
cd backend

# Tüm testleri çalıştır
npx jest

# Belirli bir test dosyası
npx jest __tests__/auth.test.js

# Watch modunda
npx jest --watch

# Coverage raporu ile
npx jest --coverage

# Verbose çıktı
npx jest --verbose
```

### Mobile Testleri (flutter_test)
```bash
cd mobile

# Tüm testleri çalıştır
flutter test

# Belirli bir test dosyası
flutter test test/widget_test.dart

# Coverage ile
flutter test --coverage

# Machine-readable çıktı
flutter test --reporter json
```

---

## Bakım Komutları

### Docker Volume Boyutlarını Kontrol Et
```bash
docker system df -v
```

### Kullanılmayan Docker Kaynaklarını Temizle
```bash
docker system prune -f
```

### Kullanılmayan Docker İmajlarını Temizle
```bash
docker image prune -f
```

### Backend Container'ı Yeniden Build Et
```bash
docker-compose build --no-cache backend
docker-compose up -d backend
```

### PostgreSQL Backup
```bash
# Backup al
docker exec storyforge-db pg_dump -U storyforge storyforge > backup_$(date +%Y%m%d).sql

# Backup'tan geri yükle (DİKKAT!)
docker exec -i storyforge-db psql -U storyforge storyforge < backup_20260316.sql
```

### Redis Cache Temizle
```bash
docker exec storyforge-redis redis-cli FLUSHALL
```

---

## npm Scriptleri (package.json)

```json
{
  "start": "node src/server.js",           // Production başlatma
  "dev": "node --watch src/server.js",      // Dev başlatma (auto-reload)
  "test": "jest --verbose",                 // Tüm testleri çalıştır
  "test:coverage": "jest --coverage",       // Coverage raporu ile
  "prisma:generate": "npx prisma generate", // Prisma client oluştur
  "prisma:migrate": "npx prisma migrate dev", // Migration oluştur
  "prisma:studio": "npx prisma studio"      // Prisma Studio
}
```

---

## Ortam Değişkenleri Referansı

| Değişken | Zorunlu | Varsayılan | Açıklama |
|----------|---------|------------|----------|
| `POSTGRES_PASSWORD` | ✅ | — | PostgreSQL şifresi |
| `NODE_ENV` | ❌ | `production` | Ortam (development/production) |
| `PORT` | ❌ | `3004` | Backend port |
| `SESSION_SECRET` | ✅ | — | Express session secret |
| `JWT_SECRET` | ✅ | — | JWT imzalama secret |
| `GEMINI_API_KEY` | ✅ | — | Google Gemini API anahtarı |
| `REDIS_URL` | ❌ | `redis://redis:6379` | Redis bağlantı URL'si |
| `DATABASE_URL` | ✅ (auto) | — | Docker Compose'da otomatik ayarlanır |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | ❌ | — | Firebase SA JSON yolu |
| `FIREBASE_PROJECT_ID` | ❌ | — | Firebase proje ID |
| `BACKEND_BIND` | ❌ | `127.0.0.1` | Backend bind adresi |

---

## Sorun Giderme

### "Connection refused" hatası
```bash
# Container'lar çalışıyor mu?
docker-compose ps

# DB sağlık kontrolü geçti mi?
docker-compose logs db | tail -20

# Redis bağlantısı var mı?
docker exec storyforge-redis redis-cli ping
# Beklenen çıktı: PONG
```

### "Prisma migrate hatası"
```bash
# Migration durumunu kontrol et
docker exec -it storyforge-backend npx prisma migrate status

# Gerekirse migration'ları yeniden uygula
docker exec -it storyforge-backend npx prisma migrate deploy
```

### "Port already in use"
```bash
# Windows'ta portu kullanan process'i bul
netstat -ano | findstr :3004
# PID'yi kill et
taskkill /PID <pid> /F

# Linux/Mac
lsof -ti:3004 | xargs kill -9
```

### Flutter "build hatası"
```bash
# Cache temizle
flutter clean
flutter pub get

# Gradle cache (Android)
cd android && ./gradlew clean && cd ..

# Tekrar build
flutter run
```
