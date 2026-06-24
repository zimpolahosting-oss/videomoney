const admin = require("firebase-admin");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");

admin.initializeApp();

const db = admin.firestore();

function uniqueTokens(users) {
  return [...new Set(users.flatMap((user) => user.fcmTokens || []).filter(Boolean))];
}

function chunk(array, size) {
  const chunks = [];
  for (let index = 0; index < array.length; index += size) {
    chunks.push(array.slice(index, index + size));
  }
  return chunks;
}

async function writeInboxMessages(users, title, message, type, notificationId) {
  const userChunks = chunk(users, 400);
  for (const usersChunk of userChunks) {
    const batch = db.batch();
    for (const user of usersChunk) {
      const docRef = db.collection("inboxMessages").doc();
      batch.set(docRef, {
        userId: user.uid,
        title,
        message,
        type,
        read: false,
        notificationId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

exports.dispatchAdminNotification = onDocumentCreated(
  "adminNotifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }

    const notificationId = snapshot.id;
    const data = snapshot.data() || {};
    const title = String(data.title || "").trim();
    const message = String(data.message || "").trim();
    const type = String(data.type || "announcement").trim();
    const audience = String(data.audience || "all").trim();
    const targetUserId = String(data.targetUserId || "").trim();

    if (!title || !message) {
      await snapshot.ref.set(
        {
          status: "failed",
          error: "Missing title or message.",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return;
    }

    try {
      let userDocs = [];
      if (audience === "user" && targetUserId) {
        const userDoc = await db.collection("users").doc(targetUserId).get();
        if (userDoc.exists) {
          userDocs = [userDoc];
        }
      } else {
        const userSnapshot = await db.collection("users").get();
        userDocs = userSnapshot.docs;
      }

      const users = userDocs.map((doc) => ({
        uid: doc.id,
        ...doc.data(),
      }));

      await writeInboxMessages(users, title, message, type, notificationId);

      const pushUsers = users.filter(
        (user) => (user.settings || {}).notificationsEnabled !== false
      );
      const tokens = uniqueTokens(pushUsers);
      let successCount = 0;
      let failureCount = 0;

      for (const tokenChunk of chunk(tokens, 500)) {
        if (tokenChunk.length === 0) {
          continue;
        }

        const response = await admin.messaging().sendEachForMulticast({
          tokens: tokenChunk,
          notification: {
            title,
            body: message,
          },
          data: {
            title,
            message,
            type,
            notificationId,
          },
          android: {
            priority: "high",
          },
        });

        successCount += response.successCount;
        failureCount += response.failureCount;
      }

      await snapshot.ref.set(
        {
          status: "sent",
          recipientCount: users.length,
          tokenCount: tokens.length,
          successCount,
          failureCount,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    } catch (error) {
      logger.error("dispatchAdminNotification failed", error);
      await snapshot.ref.set(
        {
          status: "failed",
          error: error instanceof Error ? error.message : String(error),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  }
);
