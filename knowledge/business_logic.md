# StoryForge — İş Kuralları ve Kısıtlamalar

## Projenin Ana Amacı

StoryForge, yapay zeka (Gemini) ile etkileşimli, dallanmalı hikayeler oluşturmaya yarayan bir platformdur. Kullanıcılar:

1. Genre ve ruh hali seçerek yeni hikaye başlatır
2. Her bölüm sonunda 2-4 seçenek arasından birini seçer
3. Opsiyonel olarak fotoğraf çekerek hikayeye multimodal girdiler sağlar
4. Arkadaşlarıyla co-op oturumlarında birlikte hikaye oluşturur
5. Hikayelerini paylaşarak sosyal etkileşime girer
6. Gamification sistemiyle (XP, seviye, başarım, günlük görev) motive olur

---

## Hikaye Oluşturma Kuralları

### Yeni Hikaye Başlatma
- Kullanıcı bir **genre** (fantasy, scifi, horror, romance, mystery, adventure, historical) ve opsiyonel **mood** seçer
- İsteğe bağlı **karakterler** tanımlanabilir (isim, kişilik, görünüş)
- Gemini API'ye gönderilen prompt:
  - 5 farklı rastgele açılış prompt'undan biri seçilir (çeşitlilik)
  - Genre açıklaması + mood tonu + karakter bilgileri eklenir
  - Kural: JSON formatında dönüş (`{title, storyText, choices[], mood, chapterSummary}`)
  - Seçenek sayısı: **2-4 arası** (AI belirler)
  - Yasaklanan isimler: "Ali", "Elif" gibi basit isimler (benzersiz isim zorunlu)

### Hikaye Devam Ettirme (Seçim Yapma)
- Kullanıcı bir `choiceIndex` gönderir (seçenekler arasından)
- Opsiyonel `imageData` (base64 fotoğraf) gönderebilir
- Backend iş akışı:
  1. Son 3-5 bölüm getirilir (bağlam)
  2. RAG sistemi devreye girer: seçim metninden embedding üretilir → pgvector'de benzer entity/event/lore aranır → ilgili bağlam eklenir
  3. Summary sistemi: Quick = her bölüm (2-3 cümle, 512 token), Deep = her 5 bölümde (kapsamlı, 4096 token)
  4. Multi-Agent Pipeline devreye girer:
     - Writer Agent (temp 0.9): Hikaye üretimi, 8-12 paragraf, 800-1200 kelime, maxOutputTokens 8192
     - Consistency Agent (temp 0.1): RAG Triad doğrulama
       - Groundedness (%40) + Temporal Consistency (%35) + Context Relevance (%25)
     - Başarısızsa max 1 retry ile Writer Agent tekrar çağrılır
  5. 10+ bölümde Gemini'nin "thinking" modu aktif olur (2048 token bütçe)
  6. Dynamic Context Window: Ch 1-10: son 5 full | Ch 11-30: son 3 full + 5 summary | Ch 31+: son 2 full + milestone'lar
- Seçim yapıldığında:
  - `selectedChoice` güncellenir (önceki bölümün seçimi)
  - Yeni `Chapter` oluşturulur
  - XP verilir (+10 bölüm)
  - Quest progress kontrol edilir
  - RAG entity extraction arka planda çalışır
  - Karakter ilişki grafı güncellenir (relationshipGraphService)
  - Event relevance decay uygulanır (0.95x/bölüm)

### Hikaye Tamamlama
- Kullanıcı elle "tamamla" butonuna basar VEYA
- Hikaye doğal sonlanma noktasına gelir (choices boş döner)
- `isCompleted = true`, `isActive = false` yapılır
- XP ödülü: +100 (hikaye tamamlama)
- İlgili başarımlar kontrol edilir

### Hikaye Dallanma (Branch)
- Herhangi bir bölümden alternatif sona gidilebilir
- `POST /api/stories/:id/branch/:chapterId`
- O bölüme kadar olan bağlam korunur, yeni bir yol açılır

### Hikaye Ağacı (Tree)
- `GET /api/stories/:id/tree` → Tüm bölümler ve seçimler ağaç yapısında döner
- Flutter'da görsel karar ağacı olarak render edilir

---

## Sosyal Etkileşim Kuralları

### Hikaye Paylaşma
- Sadece `isCompleted = true` olan hikayeler paylaşılabilir (kural BE'de uygulanıyor)
- `SharedStory` kaydı oluşturulur (`isPublic = true`)
- Bir hikaye bir kullanıcı tarafından sadece **bir kez** paylaşılabilir (`@@unique([storyId, userId])`)
- Paylaşım kaldırılabilir (`DELETE /api/stories/:id/share`)

### Beğeni (Like)
- Bir kullanıcı bir hikayeyi sadece **bir kez** beğenebilir (`@@unique([userId, sharedStoryId])`)
- Beğeni geri alınabilir (toggle)
- Beğeni yapıldığında hikaye sahibine bildirim gider (DB + Socket.io + FCM)

### Yorum (Comment)
- Minimum 1, **maksimum 1000 karakter**
- Yorum sahibi kendi yorumunu silebilir
- Yorum eklendiğinde hikaye sahibine bildirim
- Engellenen kullanıcıların yorumları filtrelenmez (ama mesaj gönderilemez)

### Yer İmi (Bookmark)
- Bir kullanıcı bir hikayeyi bir kez yer imleyebilir (`@@unique([userId, sharedStoryId])`)
- Yer imi ekle/kaldır toggle

### Galeri ve Feed
- **Galeri:** Tüm `isPublic = true` hikayeler, sıralama: popüler (beğeni sayısı) veya en yeni
- **Feed:** Sadece kabul edilmiş arkadaşların paylaştığı hikayeler
- Her iki sorguda da **engellenen kullanıcıların hikayeleri filtrelenir**
- Sayfalama: `skip/take` pattern (varsayılan limit: 20)

---

## Arkadaşlık Sistemi Kuralları

### İstek Gönderme
- Kullanıcı kendisine istek gönderemez
- Aynı çift arasında **tek yönlü** kayıt: senderId < receiverId (DB unique constraint)
- Daha önce reddedilmiş istek: status `REJECTED` → `PENDING` olarak güncellenir (yeniden gönderilebilir)
- Zaten kabul edilmiş / bekleyen istek varsa hata döner

### İstek Kabul/Red
- Sadece `receiverId = req.userId` olan istekler kabul/reddedilebilir
- Kabul: `status = ACCEPTED`
- Red: `status = REJECTED`
- Kabul sonrası karşı tarafa bildirim (Socket.io + FCM)

### Arkadaş Listesi
- **Çift yönlü** sorgu: `(senderId = userId AND status = ACCEPTED) OR (receiverId = userId AND status = ACCEPTED)`
- Response'da karşı tarafın bilgileri döner

### Arkadaş Silme
- Friendship kaydı tamamen silinir (hard delete)
- İki taraftan da bilinir

### Kullanıcı Arama
- `username` alanında `ILIKE '%query%'` ile fuzzy arama
- Kendi hesabı sonuçlardan çıkarılır

---

## Engelleme Sistemi

### Engelleme Etkileri
Bir kullanıcı engellendiğinde:
1. Mevcut arkadaşlık **otomatik olarak silinir**
2. Engellenen kişi engellene **mesaj gönderemez** (her iki yön)
3. Engellenen kişinin hikayeleri **galeri/feed'de görünmez**
4. Engellenen kişi engellene **co-op daveti gönderemez**

### Engelleme Yapısı
- Tek yönlü: A → B engelleyince B'nin A'yı engellemesi gerekmez
- `@@unique([blockerId, blockedId])` → aynı çift için tek kayıt
- Engel kaldırılabilir (hard delete)

---

## Co-op (İşbirlikçi Hikaye) Kuralları

### Oturum Oluşturma
- Sadece **kabul edilmiş arkadaşlara** davet gönderilebilir
- Host hikayeyi oluşturur → `CoopSession` WAITING statüsünde
- Misafire Socket.io + bildirim gönderilir

### Oturuma Katılma
- Misafir `WAITING` statüsündeki daveti kabul eder → `ACTIVE`
- Misafir reddedebilir → `REJECTED`
- Kabul sonrası host'a bildirim

### Sıra Tabanlı Seçim
- `currentTurn = 1` → Host'un sırası
- `currentTurn = 2` → Misafirin sırası
- Sıra değişimi sadece **DB transaction** içinde yapılır (race condition koruması)
- Yanlış sırada seçim yapılırsa hata döner

### Tamamlama
- Her iki oyuncu da "tamamla" diyebilir
- `status = COMPLETED` yapılır
- Co-op hikaye paylaşılabilir

---

## Gamification Kuralları

### XP Sistemi

| Eylem | XP |
|-------|-----|
| Bölüm yazma (seçim yapma) | +10 |
| Hikaye tamamlama | +100 |
| Hikaye paylaşma | +15 |
| Co-op oturumu tamamlama | +15 |
| Günlük görev tamamlama | +25 |
| Başarım kilit açma | +50 |

### Seviye Formülü
```javascript
level = Math.floor(Math.sqrt(xp / 100))
```
- 0 XP → Level 0
- 100 XP → Level 1
- 400 XP → Level 2
- 900 XP → Level 3
- 10000 XP → Level 10

### Günlük Streak
- Her gün giriş yapan kullanıcının `dailyStreak` +1 artar
- Bir gün atlanırsa streak **sıfırlanır**
- `lastActiveDate` ile takip edilir

### Başarımlar (24 Adet)

**Hikaye Kategorisi (5):**
- `first_story` — İlk hikaye (threshold: 1)
- `story_5`, `story_10`, `story_25`, `story_50`

**Tür Kategorisi (7):**
- `genre_master_fantasy`, `genre_master_scifi`, `genre_master_horror`, `genre_master_romance`, `genre_master_mystery`, `genre_master_adventure`, `genre_master_historical` (threshold: 5 her biri)

**Sosyal Kategorisi (3):**
- `social_first_share` — İlk paylaşım (1)
- `social_popular` — 10 beğeni alan hikaye
- `social_influencer` — 5 hikaye paylaşma

**Co-op (1):**
- `coop_first` — İlk co-op tamamlama

**Streak (2):**
- `streak_7` — 7 günlük streak
- `streak_30` — 30 günlük streak

**Seviye (3):**
- `level_5`, `level_10`, `level_20`

### Günlük Görevler
- Her gün **3 rastgele görev** atanır
- 7 görev türü: write, complete, share, friend, message, like, start
- Her görev **25 XP** ödül
- Claim edilmeden önce `isCompleted = true` olmalı→ XP verilir
- Aynı görev iki kez claim edilemez

---

## Bildirim Kuralları

### Bildirim Türleri
| Tür | Tetikleyici | Hedef |
|-----|------------|-------|
| `like` | Hikaye beğenildiğinde | Hikaye sahibi |
| `comment` | Yorum yapıldığında | Hikaye sahibi |
| `friend_request` | Arkadaşlık isteği gönderildiğinde | İstek alan |
| `friend_accepted` | İstek kabul edildiğinde | İstek gönderen |
| `boss_level_up` | Seviye atlandığında | Kullanıcı |

### Bildirim Kanalları (Paralel)
1. **DB:** `Notification` tablosuna kayıt (kalıcı)
2. **Socket.io:** `notification:new` event (real-time, anlık)
3. **FCM:** Firebase push notification (uygulama kapalıyken)

### FCM Graceful Degradation
- Firebase yapılandırılmamışsa bildirimler sessizce atlanır
- Geçersiz tokenlar otomatik temizlenir

---

## Güvenlik Kuralları

### Rate Limiting

| Endpoint | Limit | Pencere |
|----------|-------|---------|
| Genel (tüm istekler) | 200 req | 15 dk |
| Auth (login/register) | 15 req | 15 dk |
| AI (hikaye oluşturma/devam) | 10 req | 1 dk |
| TTS (ses üretimi) | 5 req | 1 dk |
| Mesaj gönderme | 30 req | 1 dk |
| Sosyal (like/comment/block) | 40 req | 1 dk |
| Report (bildiri) | 10 req | 15 dk |

### Parola Kuralları
- Minimum 8 karakter
- En az 1 büyük harf
- En az 1 küçük harf
- En az 1 rakam

### Veri Doğrulama
- Backend: `express-validator` ile route-level validation
- XSS: `xss` kütüphanesi (boş whitelist — hiçbir HTML tag'ine izin verilmez)
- Body parser limiti: 5MB (`express.json({ limit: '5mb' })`)
- Dosya yükleme: Multer ile kontrollü (avatar + mesaj görseli)

---

## Mesajlaşma Kuralları

### Mesaj Gönderme
- Engellenen kullanıcıya mesaj gönderilemez (her iki yön kontrol edilir)
- `messageType`: "text" veya "image"
- Görsel mesaj: Multer ile upload → URL oluşturulur → `imageUrl` alanına kaydedilir

### Okundu Bilgisi
- `PUT /api/messages/:userId/read` → Belirli bir kullanıcıyla olan tüm okunmamış mesajları "okundu" yapar
- `isRead = true` güncellenir → Socket.io ile karşı tarafa `message:read` event'i gönderilir

### Konuşma Listesi
- Her konuşma: karşı tarafın bilgileri + son mesaj + okunmamış sayı
- Sıralama: Son mesaj tarihine göre (en yeni üstte)

---

## TTS (Text-to-Speech) Kuralları
- Gemini API ile bölüm metni seslendirilir
- Çıktı formatı: PCM → WAV dönüşümü (backend'de)
- Rate limit: Dakikada 5 istek
- Uzun metinler desteklenir (Gemini'nin token limitine kadar)

---

## PDF Export Kuralları
- Puppeteer (Headless Chromium) ile PDF üretilir
- Hikayenin tüm bölümleri tek PDF'te birleştirilir
- Dockerfile'da Chromium önceden kurulur (Alpine)
- Mobile'da platform-aware PDF indirme (native/web/stub)

---

## Story Codex / Ansiklopedi Kuralları

### Genel
- `GET /api/stories/:id/codex` → Hikaye dünyasının ansiklopedi görünümü
- Sadece hikaye sahibi kendi hikayesinin codex'ine erişebilir

### Entity Görüntüleme
- Entity'ler türe göre gruplanır: `character`, `location`, `object`, `faction`
- Her entity: isim, açıklama, önem skoru (0-1), durum (active/dead/missing/transformed), ilk/son görülme bölümü
- Prisma `groupBy` sorgusu ile tür bazlı sayımlar

### Lore Kuralları
- Hikaye dünyasının kuralları, tarihi, canon bilgileri
- StoryWorldState üzerinden takip (bölüm bazlı dünya snapshot'ları)

### Karakter İlişkileri
- relationshipGraphService ile otomatik extraction (Gemini Function Calling)
- İlişki türleri: ally, enemy, family, romantic, neutral, rival, mentor, student
- İlişkilerin bölüm bazlı değişimi takip edilir

### UI
- **Mobile:** `codex_screen.dart` — 4 tab (Characters, Locations, Items, Lore)
- **Web:** `story.ejs` sidebar panel — codex bilgileri hikaye okuma yanında

---

## Story Timeline Kuralları

### Genel
- `GET /api/stories/:id/timeline` → Olayların kronolojik sırayla listesi
- Bölüm bazlı gruplama (`chapterNum` sıralaması)

### Olay Sınıflandırma
- **major:** Hikayeyi önemli ölçüde etkileyen olaylar
- **minor:** Küçük detaylar ve yan olaylar
- **twist:** Beklenmedik dönüm noktaları

### Veri Kaynağı
- StoryEvent tablosu (RAG entity extraction ile dolduruluyor)
- Her olay: açıklama, etki seviyesi, ilişkili entity'ler, bölüm numarası

---

## Reading Stats Kuralları

### Genel
- `GET /api/stats/reading` → Kullanıcının okuma istatistikleri

### Metrikler
- **totalStories:** Toplam hikaye sayısı (tamamlanmış + devam eden)
- **totalChapters:** Toplam okunan bölüm sayısı
- **estimatedWords:** Tahmini kelime sayısı (bölüm × 1000)
- **genreDistribution:** Tür dağılımı (UserStats.genreCounts)
- **dailyStreak:** Günlük streak bilgisi
- **level / xp:** Seviye ve XP bilgileri

---

## Mood Dynamic Theme Sistemi

### Genel
- Her hikaye türü için farklı accent renk paleti
- Hikaye okuma ekranında tür bazlı renk temalandırma

### Renk Paleti
| Tür | Renk | Hex |
|-----|------|-----|
| fantasy | Mor/Altın | #9C27B0 |
| scifi | Cyan/Neon | #00BCD4 |
| horror | Kırmızı | #F44336 |
| romance | Pembe | #E91E63 |
| mystery | Amber | #FF9800 |
| adventure | Yeşil | #4CAF50 |
| Varsayılan | Mavi | #2196F3 |

### Uygulama
- **Mobile:** `story_screen.dart`'ta `_accent` getter ile runtime tür bazlı renk seçimi
- **Web:** `story.ejs`'de CSS custom property ile dinamik renk uygulaması
- Accent renk: Seçenek kartları, başlıklar, butonlar ve vurgu elementlerinde kullanılır
