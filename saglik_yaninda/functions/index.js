const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

// For cost control, limit concurrent containers for this project.
setGlobalOptions({ maxInstances: 10 });

// notification_requests/{requestId} doküman alanları:
//   type: "medicine_taken" | "sos" | "nudge"
//   caregiverId, elderId: ilgili elder-caregiver ilişkisinin taraf uid'leri
//   elderName: elder'ın görünen adı
//   callerName: bildirimi tetikleyen kişinin adı (medicine_taken/sos için elder, nudge için caregiver)
//   medicineName: sadece "medicine_taken" için dolu
//   timestamp: serverTimestamp()
const MESSAGE_BUILDERS = {
  medicine_taken: (data) => ({
    // elder ilacını aldı -> caregiver'a bildirilir
    recipientId: data.caregiverId,
    title: "💊 İlaç Alındı",
    body: `${data.callerName || data.elderName || "Yakınınız"}, "${
      data.medicineName || "ilacını"
    }" adlı ilacını içti!`,
    urgent: false,
  }),
  sos: (data) => ({
    // elder acil yardım istedi -> caregiver'a bildirilir
    recipientId: data.caregiverId,
    title: "🚨 ACİL DURUM YARDIMI!",
    body: `${
      data.callerName || data.elderName || "Yakınınız"
    } acil yardım çağrısında bulundu! Lütfen hemen iletişime geçin.`,
    urgent: true,
  }),
  nudge: (data) => ({
    // caregiver, elder'ı dürtüyor -> elder'a bildirilir (yön ters)
    recipientId: data.elderId,
    title: "🔔 İlaç Hatırlatması",
    body: `${
      data.callerName || "Yakınınız"
    }, ilaçlarını kontrol etmeni istiyor. Lütfen unutma!`,
    urgent: false,
  }),
};

/**
 * SOS gibi kritik bildirimler geçici ağ/servis hatalarına karşı
 * birkaç kez denenerek gönderilir; standart bildirimler tek seferde denenir.
 */
async function sendWithRetry(message, attempts) {
  let lastError;
  for (let i = 0; i < attempts; i++) {
    try {
      return await admin.messaging().send(message);
    } catch (error) {
      lastError = error;
      logger.warn(`Gönderim denemesi ${i + 1}/${attempts} başarısız:`, error);
      if (i < attempts - 1) {
        await new Promise((resolve) => setTimeout(resolve, 500 * (i + 1)));
      }
    }
  }
  throw lastError;
}

// --- resolveConnectionCode -------------------------------------------------
//
// "users" koleksiyonunda connectionCode alanına doğrudan client sorgusu
// bilinçli olarak kapalı (firestore.rules): bir kod, elder'ı bulmak için
// caregiver'a bir kerelik "davetiye" gibi işlev görüyor ve elder'ın tam
// profiline (kan grubu, ilaçlar vb.) rastgele erişimi açmamalı. Bu yüzden
// çözümleme Admin SDK ile burada yapılır; sadece {elderId, elderName}
// döner, başka hiçbir alan sızdırılmaz.

const RATE_LIMIT_MAX_ATTEMPTS = 5;
const RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 dakika

/**
 * Basit sabit-pencereli rate limit: kullanıcı başına dakikada en fazla
 * RATE_LIMIT_MAX_ATTEMPTS deneme. Firestore transaction'ı ile eşzamanlı
 * çağrılara karşı korunur.
 */
async function checkAndConsumeRateLimit(uid) {
  const ref = admin
    .firestore()
    .collection("rate_limits")
    .doc(`resolveConnectionCode_${uid}`);

  return admin.firestore().runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const now = Date.now();

    if (!doc.exists) {
      tx.set(ref, { count: 1, windowStart: now });
      return true;
    }

    const data = doc.data();
    const windowStart = data.windowStart || 0;
    const count = data.count || 0;

    if (now - windowStart > RATE_LIMIT_WINDOW_MS) {
      tx.set(ref, { count: 1, windowStart: now });
      return true;
    }

    if (count >= RATE_LIMIT_MAX_ATTEMPTS) {
      return false;
    }

    tx.update(ref, { count: count + 1 });
    return true;
  });
}

exports.resolveConnectionCode = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Bu işlem için giriş yapmış olmanız gerekiyor."
    );
  }

  const uid = request.auth.uid;
  const code = (request.data && request.data.code
    ? String(request.data.code)
    : ""
  ).trim();

  if (!code) {
    throw new HttpsError("invalid-argument", "Kod boş olamaz.");
  }

  const allowed = await checkAndConsumeRateLimit(uid);
  if (!allowed) {
    throw new HttpsError(
      "resource-exhausted",
      "Çok fazla deneme yaptınız. Lütfen bir dakika sonra tekrar deneyin."
    );
  }

  const snap = await admin
    .firestore()
    .collection("users")
    .where("connectionCode", "==", code)
    .where("role", "==", "elder")
    .limit(1)
    .get();

  if (snap.empty) {
    throw new HttpsError("not-found", "Kod bulunamadı.");
  }

  const elderDoc = snap.docs[0];
  const elderData = elderDoc.data();

  // Sadece bu iki alan döner — başka hiçbir alan (kan grubu, ilaçlar,
  // fcmToken vb.) client'a asla sızdırılmaz.
  return {
    elderId: elderDoc.id,
    elderName: elderData.name || "",
  };
});

exports.onNotificationRequestCreated = onDocumentCreated(
  "notification_requests/{requestId}",
  async (event) => {
    const requestId = event.params.requestId;
    const snap = event.data;
    if (!snap) {
      logger.error(`notification_requests/${requestId}: doküman verisi yok.`);
      return;
    }

    const data = snap.data();
    const { type, caregiverId, elderId } = data;
    const builder = MESSAGE_BUILDERS[type];

    if (!builder || !caregiverId || !elderId) {
      logger.error(
        `notification_requests/${requestId}: geçersiz/eksik veri.`,
        data
      );
      return;
    }

    const { recipientId, title, body, urgent } = builder(data);

    try {
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(recipientId)
        .get();

      if (!userDoc.exists) {
        logger.error(`Alıcı kullanıcı bulunamadı: ${recipientId}`);
        return;
      }

      const fcmToken = userDoc.data().fcmToken;
      if (!fcmToken) {
        logger.warn(
          `Alıcının (${recipientId}) fcmToken'ı yok, bildirim gönderilemedi. [${type}]`
        );
        return;
      }

      const message = {
        token: fcmToken,
        notification: { title, body },
        android: {
          priority: "high",
          notification: {
            icon: "ic_stat_name",
            color: "#4DB6AC",
            sound: "default",
            ...(urgent ? { channelId: "channel_alarm" } : {}),
          },
        },
        apns: {
          headers: { "apns-priority": "10" },
          payload: {
            aps: {
              sound: "default",
              ...(urgent ? { "interruption-level": "time-sensitive" } : {}),
            },
          },
        },
      };

      const attempts = urgent ? 3 : 1;
      const response = await sendWithRetry(message, attempts);

      logger.info(
        `✅ Bildirim gönderildi [${type}] -> ${recipientId}`,
        response
      );
    } catch (error) {
      logger.error(`❌ Bildirim gönderilemedi [${type}] -> ${recipientId}:`, error);

      // Token artık geçersizse (uygulama silinmiş, verisi temizlenmiş, token
      // rotasyona uğramış vb.) veritabanında biriktirmemek için temizle —
      // bir sonraki senkronizasyonda (main.dart _syncFcmToken/onTokenRefresh)
      // geçerli token otomatik olarak tekrar yazılacak.
      if (error.code === "messaging/registration-token-not-registered") {
        try {
          await admin
            .firestore()
            .collection("users")
            .doc(recipientId)
            .update({ fcmToken: admin.firestore.FieldValue.delete() });
          logger.info(
            `🧹 Geçersiz fcmToken temizlendi: ${recipientId}`
          );
        } catch (cleanupError) {
          logger.error(
            `fcmToken temizlenemedi: ${recipientId}:`,
            cleanupError
          );
        }
      }
    }
  }
);
