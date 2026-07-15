const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const {setGlobalOptions} = require("firebase-functions/v2");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");

admin.initializeApp();
setGlobalOptions({region: "europe-west1"});

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

async function getUserById(userId) {
  const userDoc = await db.collection("users").doc(userId).get();
  if (!userDoc.exists) {
    throw new Error(`Target user not found: ${userId}`);
  }

  return {
    uid: userDoc.id,
    ...userDoc.data(),
  };
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

async function sendPushToUsers(users, payload) {
  const tokenOwners = buildTokenOwners(users);
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
          title: payload.title,
          body: payload.message,
        },
        data: {
          title: payload.title,
          message: payload.message,
          type: payload.type,
          notificationId: payload.notificationId || "",
          ticketId: payload.ticketId || "",
          audience: payload.audience || "",
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
  return {
    successCount,
    failureCount,
    tokenCount: tokens.length,
    inboxOnly: tokens.length === 0,
  };
}

exports.dispatchAdminNotification = onDocumentCreated(
  "adminNotifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("dispatchAdminNotification received no snapshot data", event);
      return;
    }

    const notificationId = event.params.notificationId;
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

      await snapshot.ref.set(
        {
          status: "sent",
          errorMessage: "",
          recipientCount: recipients.length,
          tokenCount: 0,
          successCount: 0,
          failureCount: 0,
          inboxOnly: true,
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
  }
);

exports.dispatchInboxPush = onDocumentCreated(
  "inboxMessages/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("dispatchInboxPush received no snapshot data", event);
      return;
    }

    const messageId = event.params.messageId;
    const data = snapshot.data() || {};
    const userId = String(data.userId || "").trim();
    const title = String(data.title || "VideoMoney").trim();
    const message = String(data.message || "").trim();
    const type = String(data.type || "info").trim();
    const notificationId = String(data.notificationId || "").trim();
    const ticketId = String(data.ticketId || "").trim();

    if (!userId || !message) {
      logger.warn("dispatchInboxPush skipped due to missing userId or message", {
        messageId,
      });
      return;
    }

    try {
      const user = await getUserById(userId);
      const result = await sendPushToUsers([user], {
        title: title || "VideoMoney",
        message,
        type,
        notificationId,
        ticketId,
        audience: "user",
      });

      await snapshot.ref.set(
        {
          pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
          pushSuccessCount: result.successCount,
          pushFailureCount: result.failureCount,
          pushTokenCount: result.tokenCount,
          pushInboxOnly: result.inboxOnly,
        },
        { merge: true }
      );
    } catch (error) {
      logger.error("dispatchInboxPush failed", error);
      await snapshot.ref.set(
        {
          pushError:
            error instanceof Error ? error.message : String(error),
        },
        { merge: true }
      );
    }
  }
);

// Presence counter is implemented client-side via Realtime Database `/status`.
// We intentionally do not use RTDB-triggered functions so the online counter
// can be used without requiring a billing-enabled (Blaze) plan.
