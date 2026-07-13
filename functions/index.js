const admin = require("firebase-admin");
const functions = require("firebase-functions/v1");
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

function shouldRemoveToken(errorCode) {
  return (
    errorCode === "messaging/invalid-registration-token" ||
    errorCode === "messaging/registration-token-not-registered"
  );
}

async function removeInvalidTokens(tokenOwners) {
  if (tokenOwners.length === 0) {
    return;
  }

  const batch = db.batch();
  for (const tokenOwner of tokenOwners) {
    batch.set(
      db.collection("users").doc(tokenOwner.userId),
      {
        fcmTokens: admin.firestore.FieldValue.arrayRemove(tokenOwner.token),
        lastFcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  await batch.commit();
}

async function resolveRecipients(audience, targetUserId) {
  if (audience === "user") {
    if (!targetUserId) {
      throw new Error("Missing targetUserId for USER notification.");
    }

    const userDoc = await db.collection("users").doc(targetUserId).get();
    if (!userDoc.exists) {
      throw new Error(`Target user not found: ${targetUserId}`);
    }

    return [
      {
        uid: userDoc.id,
        ...userDoc.data(),
      },
    ];
  }

  const userSnapshot = await db.collection("users").get();
  return userSnapshot.docs.map((doc) => ({
    uid: doc.id,
    ...doc.data(),
  }));
}

function buildTokenOwners(users) {
  const entries = [];
  for (const user of users) {
    if ((user.settings || {}).notificationsEnabled === false) {
      continue;
    }

    const tokens = Array.isArray(user.fcmTokens) ? user.fcmTokens : [];
    for (const token of tokens) {
      if (!token || typeof token !== "string") {
        continue;
      }

      entries.push({
        userId: user.uid,
        token: token.trim(),
      });
    }
  }

  const seen = new Set();
  return entries.filter((entry) => {
    const key = `${entry.userId}:${entry.token}`;
    if (!entry.token || seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}

exports.dispatchAdminNotification = functions
  .region("europe-west1")
  .firestore.document("adminNotifications/{notificationId}")
  .onCreate(async (snapshot) => {
    const notificationId = snapshot.id;
    const data = snapshot.data() || {};
    const title = String(data.title || "").trim();
    const message = String(data.message || "").trim();
    const type = String(data.type || "announcement").trim();
    const audience = String(data.audience || "all").trim().toLowerCase();
    const targetUserId = String(data.targetUserId || "").trim();

    await snapshot.ref.set(
      {
        status: "processing",
        errorMessage: "",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    if (!title || !message) {
      await snapshot.ref.set(
        {
          status: "failed",
          errorMessage: "Missing title or message.",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return;
    }

    try {
      const recipients = await resolveRecipients(audience, targetUserId);
      if (recipients.length === 0) {
        throw new Error("No recipient users found with valid fcmTokens.");
      }

      await writeInboxMessages(
        recipients,
        title,
        message,
        type,
        notificationId
      );

      const tokenOwners = buildTokenOwners(recipients);
      const tokens = tokenOwners.map((item) => item.token);
      let successCount = 0;
      let failureCount = 0;
      const invalidTokens = [];

      if (tokens.length > 0) {
        for (const tokenChunk of chunk(tokens, 500)) {
          const chunkOwners = tokenOwners.filter((owner) =>
            tokenChunk.includes(owner.token)
          );

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
              audience,
            },
            android: {
              priority: "high",
              notification: {
                channelId: "videomoney_general",
              },
            },
          });

          successCount += response.successCount;
          failureCount += response.failureCount;

          response.responses.forEach((result, index) => {
            if (!result.success && shouldRemoveToken(result.error?.code)) {
              const owner = chunkOwners[index];
              if (owner) {
                invalidTokens.push(owner);
              }
            }
          });
        }
      }

      await removeInvalidTokens(invalidTokens);

      await snapshot.ref.set(
        {
          status: "sent",
          errorMessage: "",
          recipientCount: recipients.length,
          tokenCount: tokens.length,
          successCount,
          failureCount,
          inboxOnly: tokens.length === 0,
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
          errorMessage:
            error instanceof Error ? error.message : String(error),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  });

exports.cleanupExpiredActiveUsers = functions
  .region("europe-west1")
  .pubsub.schedule("every 1 minutes")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const maxBatchSize = 400;
    let deletedCount = 0;

    while (true) {
      const snapshot = await db
        .collection("activeUsers")
        .where("expiresAt", "<=", now)
        .limit(maxBatchSize)
        .get();

      if (snapshot.empty) {
        break;
      }

      const batch = db.batch();
      for (const doc of snapshot.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
      deletedCount += snapshot.size;
    }

    logger.info("cleanupExpiredActiveUsers completed", {
      deletedCount,
    });
    return null;
  });

const rtdb = admin.database();

function onlineCountRef() {
  return rtdb.ref("onlineUsersCount");
}

function statusMetaConnectionsRef(uid) {
  return rtdb.ref(`statusMeta/${uid}/connections`);
}

exports.trackPresenceConnection = functions
  .region("europe-west1")
  .database.ref("/status/{uid}/{connId}")
  .onWrite(async (change, context) => {
    const { uid } = context.params;
    const beforeExists = change.before.exists();
    const afterExists = change.after.exists();

    if (beforeExists === afterExists) {
      return null;
    }

    if (!beforeExists && afterExists) {
      const tx = await statusMetaConnectionsRef(uid).transaction((current) => {
        const base = typeof current === "number" ? current : 0;
        return base + 1;
      });
      const connections = tx.snapshot.val() || 0;
      if (connections === 1) {
        await onlineCountRef().transaction((current) => {
          const base = typeof current === "number" ? current : 0;
          return base + 1;
        });
      }
      return null;
    }

    const tx = await statusMetaConnectionsRef(uid).transaction((current) => {
      const base = typeof current === "number" ? current : 0;
      return base <= 1 ? 0 : base - 1;
    });
    const connections = tx.snapshot.val() || 0;
    if (connections === 0) {
      await statusMetaConnectionsRef(uid).parent.remove();
      await onlineCountRef().transaction((current) => {
        const base = typeof current === "number" ? current : 0;
        return base <= 0 ? 0 : base - 1;
      });
    }
    return null;
  });
