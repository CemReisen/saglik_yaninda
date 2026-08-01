/**
 * Tek seferlik migration: relations/{autoId} dokümanlarını
 * relations/{elderId}_{caregiverId} deterministik ID'sine taşır.
 *
 * NEDEN: Yeni firestore.rules, bir elder-caregiver ilişkisinin onaylı olup
 * olmadığını exists()/get() ile SADECE bu deterministik yoldan
 * doğrulayabiliyor (Firestore kuralları where() sorgusu çalıştıramaz).
 * Eski rastgele ID'li dokümanlar bu script çalışmadan/kurallar deploy
 * edilmeden önce taşınmazsa, yeni kurallar devreye girdiğinde uygulama
 * tarafından görünmez hale gelirler (silinmezler, sadece client'tan
 * okunamaz olurlar).
 *
 * KULLANIM:
 *   1) Kimlik bilgisi sağla (ikisinden biri):
 *        - GOOGLE_APPLICATION_CREDENTIALS=/path/to/valid-service-account.json
 *        - veya `gcloud auth application-default login` yapılmış olsun
 *   2) Önce KURU ÇALIŞTIRMA (hiçbir şey yazmaz, sadece rapor basar):
 *        node functions/migrate_relations_to_deterministic_id.js
 *   3) Rapor gözden geçirildikten sonra gerçekten uygulamak için:
 *        node functions/migrate_relations_to_deterministic_id.js --commit
 *
 * NE YAPAR:
 *   - relations koleksiyonundaki TÜM dokümanları okur.
 *   - ID'si zaten "{elderId}_{caregiverId}" olanlara dokunmaz (idempotent).
 *   - Aynı (elderId, caregiverId) çiftine ait birden fazla eski-ID doküman
 *     varsa: "approved" olanı, yoksa en yeni "createdAt"a sahip olanı
 *     "kazanan" seçer; taşır. Diğerlerini SİLMEZ, rapor sonunda
 *     "MANUEL İNCELEME GEREKİYOR" başlığı altında listeler.
 *   - Kazanan her doküman için --commit modunda ATOMIK bir batch ile:
 *       (a) relations/{elderId}_{caregiverId} dokümanını aynı verilerle
 *           oluşturur/üzerine yazar,
 *       (b) eski rastgele-ID dokümanı SİLER.
 *     Böylece hem eski hem yeni doküman aynı anda var olup uygulamada
 *     mükerrer satır göstermez.
 */

const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();
const DRY_RUN = !process.argv.includes("--commit");

function isDeterministicId(id, elderId, caregiverId) {
  return id === `${elderId}_${caregiverId}`;
}

async function main() {
  const snap = await db.collection("relations").get();
  console.log(`Toplam relations dokümanı: ${snap.size}`);
  console.log(`Mod: ${DRY_RUN ? "KURU ÇALIŞTIRMA (hiçbir şey yazılmayacak)" : "COMMIT (gerçekten yazılacak)"}\n`);

  const byPair = new Map(); // "elderId_caregiverId" -> [{id, data}]
  const alreadyOk = [];

  snap.forEach((doc) => {
    const data = doc.data();
    const { elderId, caregiverId } = data;

    if (!elderId || !caregiverId) {
      console.warn(`⚠️  Atlanıyor (elderId/caregiverId eksik): ${doc.id}`);
      return;
    }

    if (isDeterministicId(doc.id, elderId, caregiverId)) {
      alreadyOk.push(doc.id);
      return;
    }

    const key = `${elderId}_${caregiverId}`;
    if (!byPair.has(key)) byPair.set(key, []);
    byPair.get(key).push({ id: doc.id, data });
  });

  console.log(`Zaten deterministik ID'li (dokunulmayacak): ${alreadyOk.length}`);
  console.log(`Taşınması gereken benzersiz çift sayısı: ${byPair.size}\n`);

  const toMigrate = [];
  const needsManualReview = [];

  for (const [key, docs] of byPair.entries()) {
    let winner;
    if (docs.length === 1) {
      winner = docs[0];
    } else {
      const approved = docs.filter((d) => d.data.status === "approved");
      const pool = approved.length > 0 ? approved : docs;
      winner = pool.sort((a, b) => {
        const ta = a.data.createdAt ? a.data.createdAt.toMillis() : 0;
        const tb = b.data.createdAt ? b.data.createdAt.toMillis() : 0;
        return tb - ta; // en yeni önce
      })[0];

      const losers = docs.filter((d) => d.id !== winner.id);
      needsManualReview.push({ key, winner: winner.id, losers: losers.map((l) => l.id) });
    }
    toMigrate.push({ key, old: winner });
  }

  console.log("--- TAŞINACAKLAR ---");
  toMigrate.forEach(({ key, old }) => {
    console.log(`  ${old.id}  ->  relations/${key}   (status=${old.data.status})`);
  });

  if (needsManualReview.length > 0) {
    console.log("\n--- MANUEL İNCELEME GEREKİYOR (aynı çift için birden fazla eski doküman, otomatik silinmez) ---");
    needsManualReview.forEach(({ key, winner, losers }) => {
      console.log(`  ${key}: kazanan=${winner}, taşınmayacak/silinmeyecek diğerleri=[${losers.join(", ")}]`);
    });
  }

  if (DRY_RUN) {
    console.log("\nKuru çalıştırma tamamlandı. Uygulamak için --commit ile tekrar çalıştırın.");
    return;
  }

  console.log("\nCommit ediliyor...");
  for (const { key, old } of toMigrate) {
    const newRef = db.collection("relations").doc(key);
    const oldRef = db.collection("relations").doc(old.id);
    const batch = db.batch();
    batch.set(newRef, old.data);
    batch.delete(oldRef);
    await batch.commit();
    console.log(`✅ Taşındı: ${old.id} -> relations/${key}`);
  }
  console.log(`\nTamamlandı. ${toMigrate.length} doküman taşındı.`);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("HATA:", e);
    process.exit(1);
  });
