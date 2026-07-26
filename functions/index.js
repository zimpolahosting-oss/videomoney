const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const functionsV1 = require("firebase-functions/v1");
const {setGlobalOptions} = require("firebase-functions/v2");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");

admin.initializeApp();
setGlobalOptions({region: "europe-west1"});

const db = admin.firestore();
const playersAreGamersApiKey = defineSecret("PLAYERS_ARE_GAMERS_API_KEY");
const PLAYERS_ARE_GAMERS_BASE_URLS = [
  "https://playersaregamers.nl/api/integration",
  "http://playersaregamers.nl:3000/api/integration",
  "http://34.144.184.237:3000/api/integration",
];
const PLAYERS_ARE_GAMERS_PUBLIC_URL = "https://playersaregamers.nl";

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

exports.dispatchAdminNotification = functionsV1
  .region("europe-west1")
  .firestore.document("adminNotifications/{notificationId}")
  .onCreate(async (snapshot, context) => {
    if (!snapshot) {
      logger.warn("dispatchAdminNotification received no snapshot data", context);
      return;
    }

    const notificationId = context.params.notificationId;
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
      {merge: true}
    );

    if (!title || !message) {
      await snapshot.ref.set(
        {
          status: "failed",
          errorMessage: "Missing title or message.",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
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
        {merge: true}
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
        {merge: true}
      );
    }
  });

exports.dispatchInboxPush = functionsV1
  .region("europe-west1")
  .firestore.document("inboxMessages/{messageId}")
  .onCreate(async (snapshot, context) => {
    if (!snapshot) {
      logger.warn("dispatchInboxPush received no snapshot data", context);
      return;
    }

    const messageId = context.params.messageId;
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
        {merge: true}
      );
    } catch (error) {
      logger.error("dispatchInboxPush failed", error);
      await snapshot.ref.set(
        {
          pushError:
            error instanceof Error ? error.message : String(error),
        },
        {merge: true}
      );
    }
  });

// Presence counter is implemented client-side via Realtime Database `/status`.
// We intentionally do not use RTDB-triggered functions so the online counter
// can be used without requiring a billing-enabled (Blaze) plan.

function requireAuth(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  return {
    uid: request.auth.uid,
    email: String(request.auth.token.email || "").trim(),
  };
}

function sanitizeString(value) {
  return String(value || "").trim();
}

function sanitizePagUsername(value) {
  return sanitizeString(value)
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .replace(/_+/g, "_");
}

function buildPagUsernameCandidates(uid, email) {
  const uidPart = sanitizePagUsername(uid).slice(0, 8) || "player";
  const emailPrefix = sanitizePagUsername(email.split("@")[0] || "");
  const base = (emailPrefix || `videomoney_${uidPart}`).slice(0, 20);
  const candidates = [
    base,
    `vm_${uidPart}`,
    `${base.slice(0, 15)}_${uidPart.slice(0, 4)}`,
    `videomoney_${uidPart.slice(0, 6)}`,
  ];
  return [...new Set(candidates.filter((item) => item.length >= 3).map((item) => item.slice(0, 20)))];
}

function normalizePagError(status, payload) {
  const message = sanitizeString(payload?.message || payload?.error || "PlayersAreGamers request failed.");
  if (status === 400) {
    return new HttpsError("invalid-argument", message, payload);
  }
  if (status === 401 || status === 403) {
    return new HttpsError("permission-denied", message, payload);
  }
  if (status === 404) {
    return new HttpsError("not-found", message, payload);
  }
  if (status === 409) {
    return new HttpsError("already-exists", message, payload);
  }
  return new HttpsError("internal", message, payload);
}

async function parseJsonResponse(response) {
  const text = await response.text();
  if (!text) {
    return {};
  }

  try {
    return JSON.parse(text);
  } catch (error) {
    return {raw: text};
  }
}

async function pagRequest(apiKey, path, options = {}) {
  let lastError = null;

  for (const baseUrl of PLAYERS_ARE_GAMERS_BASE_URLS) {
    try {
      const response = await fetch(`${baseUrl}${path}`, {
        method: options.method || "GET",
        headers: {
          "Content-Type": "application/json",
          "X-API-Key": apiKey,
          ...(options.headers || {}),
        },
        body: options.body ? JSON.stringify(options.body) : undefined,
      });

      const payload = await parseJsonResponse(response);
      return {response, payload, baseUrl};
    } catch (error) {
      lastError = error;
      logger.warn("PlayersAreGamers request failed, trying next base URL", {
        baseUrl,
        path,
        message: error instanceof Error ? error.message : String(error),
      });
    }
  }

  throw new HttpsError(
    "unavailable",
    `PlayersAreGamers API is currently unreachable: ${
      lastError instanceof Error ? lastError.message : "unknown error"
    }`
  );
}

async function pagPublicRequest(path, body) {
  const response = await fetch(`${PLAYERS_ARE_GAMERS_PUBLIC_URL}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const payload = await parseJsonResponse(response);
  return {response, payload};
}

exports.pagGetPlayer = onCall(
  {secrets: [playersAreGamersApiKey]},
  async (request) => {
    const {uid} = requireAuth(request);
    const {response, payload} = await pagRequest(
      playersAreGamersApiKey.value(),
      `/player/${encodeURIComponent(uid)}`
    );

    if (response.status === 404) {
      return {
        linked: false,
        exists: false,
        player: null,
      };
    }

    if (!response.ok) {
      throw normalizePagError(response.status, payload);
    }

    return {
      linked: true,
      ...payload,
    };
  }
);

exports.pagGetStats = onCall(
  {secrets: [playersAreGamersApiKey]},
  async (request) => {
    const {uid} = requireAuth(request);
    const {response, payload} = await pagRequest(
      playersAreGamersApiKey.value(),
      `/player/${encodeURIComponent(uid)}/stats`
    );

    if (!response.ok) {
      throw normalizePagError(response.status, payload);
    }

    return payload;
  }
);

exports.pagLinkAccount = onCall(
  {secrets: [playersAreGamersApiKey]},
  async (request) => {
    const {uid} = requireAuth(request);
    const username = sanitizeString(request.data?.username);
    const password = String(request.data?.password || "");

    if (!username || !password) {
      throw new HttpsError(
        "invalid-argument",
        "Username and password are required."
      );
    }

    const apiKey = playersAreGamersApiKey.value();
    const linkResult = await pagRequest(apiKey, "/link-account", {
      method: "PUT",
      body: {
        firebaseUid: uid,
        username,
        password,
      },
    });

    if (!linkResult.response.ok) {
      throw normalizePagError(linkResult.response.status, linkResult.payload);
    }

    const playerResult = await pagRequest(
      apiKey,
      `/player/${encodeURIComponent(uid)}`
    );
    if (!playerResult.response.ok) {
      throw normalizePagError(playerResult.response.status, playerResult.payload);
    }

    const statsResult = await pagRequest(
      apiKey,
      `/player/${encodeURIComponent(uid)}/stats`
    );

    return {
      linked: true,
      ...playerResult.payload,
      stats: statsResult.response.ok ? statsResult.payload : {},
    };
  }
);

exports.pagCreateAndLinkAccount = onCall(
  {secrets: [playersAreGamersApiKey]},
  async (request) => {
    const {uid, email} = requireAuth(request);
    const username = sanitizeString(request.data?.username);
    const password = String(request.data?.password || "");

    if (!email) {
      throw new HttpsError(
        "failed-precondition",
        "A verified email is required to create a PlayersAreGamers account."
      );
    }

    if (!username || username.length < 3) {
      throw new HttpsError(
        "invalid-argument",
        "Choose a username with at least 3 characters."
      );
    }

    if (password.length < 6) {
      throw new HttpsError(
        "invalid-argument",
        "Choose a password with at least 6 characters."
      );
    }

    const registrationResult = await pagPublicRequest("/api/auth/register", {
      username,
      email,
      password,
      refCode: "",
    });

    if (!registrationResult.response.ok) {
      throw normalizePagError(
        registrationResult.response.status,
        registrationResult.payload
      );
    }

    const apiKey = playersAreGamersApiKey.value();
    const linkResult = await pagRequest(apiKey, "/link-account", {
      method: "PUT",
      body: {
        firebaseUid: uid,
        username,
        password,
      },
    });

    if (!linkResult.response.ok) {
      throw normalizePagError(linkResult.response.status, linkResult.payload);
    }

    const playerResult = await pagRequest(
      apiKey,
      `/player/${encodeURIComponent(uid)}`
    );
    if (!playerResult.response.ok) {
      throw normalizePagError(playerResult.response.status, playerResult.payload);
    }

    const statsResult = await pagRequest(
      apiKey,
      `/player/${encodeURIComponent(uid)}/stats`
    );

    return {
      linked: true,
      ...playerResult.payload,
      stats: statsResult.response.ok ? statsResult.payload : {},
    };
  }
);

exports.pagCreateAutomaticAccount = onCall(
  {secrets: [playersAreGamersApiKey]},
  async (request) => {
    const {uid, email} = requireAuth(request);
    if (!email) {
      throw new HttpsError(
        "failed-precondition",
        "A verified email is required to create a PlayersAreGamers account."
      );
    }

    const apiKey = playersAreGamersApiKey.value();
    const usernameCandidates = buildPagUsernameCandidates(uid, email);
    let createResult = null;
    let lastConflictPayload = null;

    for (const username of usernameCandidates) {
      const result = await pagRequest(apiKey, "/player", {
        method: "POST",
        body: {
          firebaseUid: uid,
          username,
          email,
        },
      });

      if (result.response.ok) {
        createResult = result;
        break;
      }

      if (
        result.response.status === 409 &&
        sanitizeString(result.payload?.message).toLowerCase().includes("username")
      ) {
        lastConflictPayload = result.payload;
        continue;
      }

      if (
        result.response.status === 409 &&
        sanitizeString(result.payload?.message).toLowerCase().includes("firebase uid")
      ) {
        const playerResult = await pagRequest(apiKey, `/player/${encodeURIComponent(uid)}`);
        if (!playerResult.response.ok) {
          throw normalizePagError(playerResult.response.status, playerResult.payload);
        }

        const statsResult = await pagRequest(
          apiKey,
          `/player/${encodeURIComponent(uid)}/stats`
        );

        return {
          linked: true,
          ...playerResult.payload,
          stats: statsResult.response.ok ? statsResult.payload : {},
        };
      }

      throw normalizePagError(result.response.status, result.payload);
    }

    if (!createResult) {
      throw normalizePagError(409, lastConflictPayload || {
        message: "Unable to reserve a PlayersAreGamers username automatically.",
      });
    }

    const playerResult = await pagRequest(apiKey, `/player/${encodeURIComponent(uid)}`);
    if (!playerResult.response.ok) {
      throw normalizePagError(playerResult.response.status, playerResult.payload);
    }

    const statsResult = await pagRequest(
      apiKey,
      `/player/${encodeURIComponent(uid)}/stats`
    );

    return {
      linked: true,
      ...playerResult.payload,
      token: sanitizeString(createResult.payload?.token),
      stats: statsResult.response.ok ? statsResult.payload : {},
    };
  }
);

exports.pagSubmitScore = onCall(
  {secrets: [playersAreGamersApiKey]},
  async (request) => {
    const {uid} = requireAuth(request);
    const gameId = sanitizeString(request.data?.gameId);
    const score = Number(request.data?.score || 0);
    const playTime = Number(request.data?.playTime || 0);

    if (!gameId) {
      throw new HttpsError("invalid-argument", "gameId is required.");
    }

    if (!Number.isFinite(score) || !Number.isFinite(playTime)) {
      throw new HttpsError(
        "invalid-argument",
        "score and playTime must be numeric values."
      );
    }

    const {response, payload} = await pagRequest(
      playersAreGamersApiKey.value(),
      "/score",
      {
        method: "POST",
        body: {
          firebaseUid: uid,
          gameId,
          score,
          playTime,
        },
      }
    );

    if (!response.ok) {
      throw normalizePagError(response.status, payload);
    }

    return payload;
  }
);

exports.pagRewardCoins = onCall(
  {secrets: [playersAreGamersApiKey]},
  async (request) => {
    const {uid} = requireAuth(request);
    const adId = sanitizeString(request.data?.adId);
    const rewardType = sanitizeString(request.data?.rewardType || "rewarded_ad");
    const coins = Number(request.data?.coins || 0);

    if (!adId) {
      throw new HttpsError("invalid-argument", "adId is required.");
    }

    if (!Number.isFinite(coins) || coins <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "coins must be a positive number."
      );
    }

    const {response, payload} = await pagRequest(
      playersAreGamersApiKey.value(),
      "/reward-coins",
      {
        method: "POST",
        body: {
          firebaseUid: uid,
          adId,
          coins,
          rewardType,
        },
      }
    );

    if (!response.ok) {
      throw normalizePagError(response.status, payload);
    }

    return payload;
  }
);

exports.pagPurchaseCoins = onCall(
  {secrets: [playersAreGamersApiKey]},
  async (request) => {
    const {uid} = requireAuth(request);
    const coins = Number(request.data?.coins || 0);
    const amount = Number(request.data?.amount || 0);
    const currency = sanitizeString(request.data?.currency || "USD");
    const transactionId = sanitizeString(request.data?.transactionId);
    const paymentMethod = sanitizeString(request.data?.paymentMethod);

    if (!transactionId || !paymentMethod) {
      throw new HttpsError(
        "invalid-argument",
        "transactionId and paymentMethod are required."
      );
    }

    if (!Number.isFinite(coins) || coins <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "coins must be a positive number."
      );
    }

    if (!Number.isFinite(amount) || amount <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "amount must be a positive number."
      );
    }

    const {response, payload} = await pagRequest(
      playersAreGamersApiKey.value(),
      "/purchase-coins",
      {
        method: "POST",
        body: {
          firebaseUid: uid,
          coins,
          amount,
          currency,
          transactionId,
          paymentMethod,
        },
      }
    );

    if (!response.ok) {
      throw normalizePagError(response.status, payload);
    }

    return payload;
  }
);
