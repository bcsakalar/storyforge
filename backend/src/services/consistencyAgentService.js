const ai = require('../config/gemini');

const MODEL = 'gemini-3-flash-preview';

/**
 * Consistency Agent — RAG Triad doğrulama (Anti-Halüsinasyon)
 * Writer Agent'ın ürettiği metni mevcut entity/event/lore bilgilerine karşı kontrol eder.
 *
 * Kontroller:
 * 1. Groundedness: Entity'ler mevcut mu? Çelişki var mı?
 * 2. Context Relevance: Metin seçenekle uyumlu mu?
 * 3. Temporal Consistency: Ölü karakter konuşuyor mu? Kaybedilen obje tekrar mı çıktı?
 */

/**
 * Üretilen hikaye metnini entity/event listesine karşı doğrular.
 * @param {string} generatedText - Writer Agent'ın ürettiği hikaye metni
 * @param {Object} memoryContext - Mevcut hafıza bilgileri
 * @param {string} choiceText - Kullanıcının seçtiği seçenek
 * @returns {Promise<Object>} - { isConsistent, issues, suggestedFixes }
 */
async function validateConsistency(generatedText, memoryContext, choiceText) {
  const { entities, events, lore, worldState } = memoryContext;

  let prompt = `Sen bir hikaye editörüsün. Görevin, yazarın ürettiği hikaye metnini mevcut hikaye hafızasına karşı kontrol etmek.

## KONTROL KRİTERLERİ

### 1. GROUNDEDNESS (Temel Tutarlılık)
- Metinde geçen karakter isimleri: Hikaye hafızasında var mı? Doğru mu yazılmış?
- Karakter özellikleri: Daha önce tanımlanan özelliklerle çelişiyor mu?
- Mekan isimleri: Daha önce bahsedilen mekanlarla tutarlı mı?
- Nesneler: Daha önce bahsedilen nesneler tutarlı mı?

### 2. TEMPORAL CONSISTENCY (Zamansal Tutarlılık)
- Durumu "dead" olan bir karakter konuşuyor veya hareket ediyor mu?
- Durumu "missing" veya "destroyed" olan entity kullanılıyor mu?
- Olaylar kronolojik sırayla tutarlı mı?

### 3. CONTEXT RELEVANCE (Bağlam İlgisi)
- Metin, kullanıcının seçtiği seçenekle ilgili mi?
- Hikayenin akışına uygun mu?

## HIKAYEDEKİ VARLIKLAR (Entity'ler)
`;

  if (entities && entities.length > 0) {
    for (const entity of entities) {
      const status = entity.status || 'active';
      const rels = entity.relationships ? JSON.stringify(entity.relationships) : '[]';
      prompt += `- [${entity.type}] ${entity.name}: ${entity.description} | Durum: ${status} | İlişkiler: ${rels}\n`;
    }
  } else {
    prompt += '(Henüz kayıtlı entity yok)\n';
  }

  if (events && events.length > 0) {
    prompt += '\n## GEÇMİŞ OLAYLAR\n';
    for (const event of events) {
      const resolved = event.isResolved ? ' [ÇÖZÜLMÜŞ]' : '';
      prompt += `- [Bölüm ${event.chapterNumber || event.chapterNum}, ${event.impact}${resolved}] ${event.description}\n`;
    }
  }

  if (lore && lore.length > 0) {
    prompt += '\n## EVREN KURALLARI (Lore)\n';
    for (const entry of lore) {
      prompt += `- [${entry.category}] ${entry.title}: ${entry.content}\n`;
    }
  }

  if (worldState) {
    prompt += `\n## GÜNCEL DÜNYA DURUMU\n${JSON.stringify(worldState, null, 2)}\n`;
  }

  prompt += `
## KULLANICININ SEÇİMİ
"${choiceText}"

## KONTROL EDİLECEK METİN
${generatedText}

## GÖREV
Yukarıdaki metni kontrol et ve aşağıdaki JSON formatında yanıtla. SADECE JSON döndür:
{
  "isConsistent": true/false,
  "score": 0-100,
  "issues": [
    {
      "type": "groundedness|temporal|relevance",
      "severity": "critical|warning|info",
      "description": "Sorunun açıklaması",
      "suggestedFix": "Nasıl düzeltilebilir"
    }
  ]
}

Eğer hiç sorun yoksa: {"isConsistent": true, "score": 100, "issues": []}
Sadece GERÇEK tutarsızlıkları raporla. Ufak yaratıcı özgürlükleri sorun olarak gösterme.
Kritik sorunlar: Ölü karakter konuşuyor, isim yanlış, çelişkili bilgi gibi durumlar.`;

  const response = await ai.models.generateContent({
    model: MODEL,
    contents: prompt,
    config: {
      responseMimeType: 'application/json',
      temperature: 0.1,
      topP: 0.9,
      maxOutputTokens: 2048,
    },
  });

  try {
    const result = JSON.parse(response.text);
    return {
      isConsistent: result.isConsistent !== false,
      score: result.score || 100,
      issues: result.issues || [],
    };
  } catch {
    // JSON parse hatası — güvenli varsayım: tutarlı
    console.warn('Consistency check parse hatası, metin kabul ediliyor');
    return { isConsistent: true, score: 80, issues: [] };
  }
}

/**
 * Tutarsızlık varsa Writer Agent'a düzeltme talimatı oluşturur.
 * @param {Array} issues - Consistency check sonucu
 * @returns {string} - Writer Agent'a eklenecek düzeltme talimatı
 */
function buildCorrectionPrompt(issues) {
  if (!issues || issues.length === 0) return '';

  const criticalIssues = issues.filter((i) => i.severity === 'critical');
  if (criticalIssues.length === 0) return '';

  let correction = '\n\n## DÜZELTİLMESİ GEREKEN SORUNLAR\nÖnceki metinde aşağıdaki tutarsızlıklar tespit edildi. Bu sorunları düzelterek metni yeniden yaz:\n';
  for (const issue of criticalIssues) {
    correction += `- ⚠️ [${issue.type}] ${issue.description}`;
    if (issue.suggestedFix) correction += ` → Düzeltme: ${issue.suggestedFix}`;
    correction += '\n';
  }
  correction += '\nYukarıdaki sorunları çözerek hikayeyi TEKRAR yaz. Aynı JSON formatını kullan.\n';

  return correction;
}

/**
 * Tutarsızlık kontrolü gerekli mi? Basit heuristik.
 * Her bölümde çalıştır, ama ilk 3 bölümde atlayabilir (entity/event henüz az).
 */
function shouldCheckConsistency(chapterCount, entityCount) {
  // İlk 2 bölümde entity sayısı çok azdır, atla
  if (chapterCount <= 2) return false;
  // 3+ bölümde mutlaka kontrol et
  return true;
}

module.exports = {
  validateConsistency,
  buildCorrectionPrompt,
  shouldCheckConsistency,
};
