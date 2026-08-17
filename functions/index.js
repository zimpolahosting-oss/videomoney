const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const functionsV1 = require("firebase-functions/v1");
const {setGlobalOptions} = require("firebase-functions/v2");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const crypto = require("crypto");

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

const VM_MINIMUM_BUILD_NUMBER = 59;
const VM_SESSION_TTL_MS = 90 * 1000;
const VM_SESSION_STALE_MS = 10 * 60 * 1000;
const VM_REWARD_WINDOW_MS = 5 * 60 * 1000;
const VM_REWARD_MAX_IN_WINDOW = 8;
const VM_MINIMUM_PAYOUT_COINS = 1000;
const VM_PAYOUT_PROCESSING_DAYS = 5;
const VM_MINIMUM_PAYOUT_VERSION = "1.0.1+59";
const VM_ALLOWED_PAYOUT_METHODS = new Set(["paypal", "revolut", "btc", "usdc"]);
const VM_ALLOWED_PAYOUT_CURRENCIES = new Set(["EUR", "GBP", "USD", "BTC", "USDC"]);
const VM_AD_TRANSFER_DAILY_LIMIT = 2000;

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

function sanitizeInteger(value, fallback = 0) {
  const num = Number(value);
  if (!Number.isFinite(num)) return fallback;
  return Math.trunc(num);
}

function utcDayKey(date = new Date()) {
  const year = date.getUTCFullYear();
  const month = `${date.getUTCMonth() + 1}`.padStart(2, "0");
  const day = `${date.getUTCDate()}`.padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function buildLeaderboardPublicName(email, customName) {
  const trimmedCustomName = sanitizeString(customName);
  if (trimmedCustomName) return trimmedCustomName;

  const trimmedEmail = sanitizeString(email).toLowerCase();
  if (!trimmedEmail.includes("@")) return "User";
  return `${trimmedEmail.split("@")[0]}***`;
}

function generateSessionId() {
  if (typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `${Date.now()}_${Math.random().toString(16).slice(2)}`;
}

function requiresMinimumBuild(buildNumber) {
  if (!Number.isFinite(buildNumber)) {
    throw new HttpsError("invalid-argument", "buildNumber must be a number.");
  }
  if (buildNumber < VM_MINIMUM_BUILD_NUMBER) {
    throw new HttpsError(
      "failed-precondition",
      `Update required. Build ${VM_MINIMUM_BUILD_NUMBER}+ is required.`
    );
  }
}

async function requireAdminAuth(request) {
  const auth = requireAuth(request);
  const userSnap = await db.collection("users").doc(auth.uid).get();
  const isAdmin = userSnap.exists && userSnap.data()?.isAdmin === true;
  if (!isAdmin) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }
  return auth;
}

async function ensureAdsTransferEnabled() {
  const configSnap = await db.collection("appConfig").doc("features").get();
  const enabled = configSnap.exists && configSnap.data()?.adsTransferEnabled === true;
  if (!enabled) {
    throw new HttpsError(
      "failed-precondition",
      "Ads transfer is currently disabled."
    );
  }
}

async function findUserByEmail(email) {
  const normalized = sanitizeString(email);
  if (!normalized) return null;
  const candidates = [...new Set([normalized, normalized.toLowerCase()])];
  for (const candidate of candidates) {
    const snap = await db
      .collection("users")
      .where("email", "==", candidate)
      .limit(1)
      .get();
    if (!snap.empty) {
      const doc = snap.docs[0];
      return {
        uid: doc.id,
        ...doc.data(),
      };
    }
  }
  return null;
}

function buildLeaderboardPayload({uid, email, customName, views, videosWatched}) {
  return {
    uid,
    customName,
    publicName: buildLeaderboardPublicName(email, customName),
    views,
    videosWatched,
    estimatedEarnings: Number((views * 0.001).toFixed(6)),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function ensureSingleSession(uid, sessionId) {
  const userRef = db.collection("users").doc(uid);
  const now = Date.now();
  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const data = snap.data() || {};
    const storedSessionId = sanitizeString(data.activeSessionId);
    const updatedAt = data.activeSessionUpdatedAt?.toMillis
      ? data.activeSessionUpdatedAt.toMillis()
      : 0;

    if (
      storedSessionId &&
      storedSessionId !== sessionId &&
      updatedAt &&
      now - updatedAt < VM_SESSION_TTL_MS
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Account is active on another device. Sign out there first."
      );
    }

    tx.set(
      userRef,
      {
        activeSessionId: sessionId,
        activeSessionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
    return {storedSessionId};
  });
  return result;
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

async function fetchPagPlayerAndStats(apiKey, uid, token = "") {
  const playerResult = await pagRequest(
    apiKey,
    `/player/${encodeURIComponent(uid)}`,
    token
      ? {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        }
      : {}
  );
  if (!playerResult.response.ok) {
    throw normalizePagError(playerResult.response.status, playerResult.payload);
  }

  const statsResult = await pagRequest(
    apiKey,
    `/player/${encodeURIComponent(uid)}/stats`,
    token
      ? {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        }
      : {}
  );

  return {
    playerPayload: playerResult.payload,
    statsPayload: statsResult.response.ok ? statsResult.payload : {},
  };
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

    const {
      playerPayload,
      statsPayload,
    } = await fetchPagPlayerAndStats(apiKey, uid, sanitizeString(linkResult.payload?.token));

    return {
      linked: true,
      ...playerPayload,
      token: sanitizeString(linkResult.payload?.token),
      stats: statsPayload,
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

    const {
      playerPayload,
      statsPayload,
    } = await fetchPagPlayerAndStats(apiKey, uid, sanitizeString(registrationResult.payload?.token));

    return {
      linked: true,
      ...playerPayload,
      token: sanitizeString(registrationResult.payload?.token),
      stats: statsPayload,
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
        const generatedTokenResult = await pagRequest(apiKey, "/generate-token", {
          method: "POST",
          body: {
            firebaseUid: uid,
          },
        });
        if (!generatedTokenResult.response.ok) {
          throw normalizePagError(
            generatedTokenResult.response.status,
            generatedTokenResult.payload
          );
        }

        const generatedToken = sanitizeString(generatedTokenResult.payload?.token);
        const {
          playerPayload,
          statsPayload,
        } = await fetchPagPlayerAndStats(apiKey, uid, generatedToken);

        return {
          linked: true,
          ...playerPayload,
          token: generatedToken,
          stats: statsPayload,
        };
      }

      throw normalizePagError(result.response.status, result.payload);
    }

    if (!createResult) {
      throw normalizePagError(409, lastConflictPayload || {
        message: "Unable to reserve a PlayersAreGamers username automatically.",
      });
    }

    const {
      playerPayload,
      statsPayload,
    } = await fetchPagPlayerAndStats(apiKey, uid, sanitizeString(createResult.payload?.token));

    return {
      linked: true,
      ...playerPayload,
      token: sanitizeString(createResult.payload?.token),
      stats: statsPayload,
    };
  }
);

exports.pagGenerateToken = onCall(
  {secrets: [playersAreGamersApiKey]},
  async (request) => {
    const {uid} = requireAuth(request);
    const apiKey = playersAreGamersApiKey.value();
    const tokenResult = await pagRequest(apiKey, "/generate-token", {
      method: "POST",
      body: {
        firebaseUid: uid,
      },
    });

    if (!tokenResult.response.ok) {
      throw normalizePagError(tokenResult.response.status, tokenResult.payload);
    }

    const generatedToken = sanitizeString(tokenResult.payload?.token);
    const {
      playerPayload,
      statsPayload,
    } = await fetchPagPlayerAndStats(apiKey, uid, generatedToken);

    return {
      linked: true,
      ...playerPayload,
      token: generatedToken,
      stats: statsPayload,
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
      "/bonus-coins",
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
    const packageId = sanitizeString(request.data?.packageId);
    const amount = Number(request.data?.amount || 0);
    const currency = sanitizeString(request.data?.currency || "USD");
    const transactionId = sanitizeString(request.data?.transactionId);
    const coins = Number(request.data?.coins || 0);

    if (!transactionId || !packageId) {
      throw new HttpsError(
        "invalid-argument",
        "transactionId and packageId are required."
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
          packageId,
          amount,
          currency,
          transactionId,
          ...(Number.isFinite(coins) && coins > 0 ? {coins} : {}),
        },
      }
    );

    if (!response.ok) {
      throw normalizePagError(response.status, payload);
    }

    return payload;
  }
);

exports.vmClaimSession = onCall(async (request) => {
  const {uid} = requireAuth(request);
  const buildNumber = sanitizeInteger(request.data?.buildNumber, 0);
  const appVersion = sanitizeString(request.data?.appVersion);

  requiresMinimumBuild(buildNumber);

  const sessionId = generateSessionId();
  await ensureSingleSession(uid, sessionId);

  const userRef = db.collection("users").doc(uid);
  await userRef.set(
    {
      activeBuildNumber: buildNumber,
      activeAppVersion: appVersion,
      activeSessionId: sessionId,
      activeSessionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true}
  );

  return {
    sessionId,
    minimumBuildNumber: VM_MINIMUM_BUILD_NUMBER,
  };
});

exports.vmApplyProgress = onCall(async (request) => {
  const {uid} = requireAuth(request);
  const sessionId = sanitizeString(request.data?.sessionId);
  const buildNumber = sanitizeInteger(request.data?.buildNumber, 0);
  const appVersion = sanitizeString(request.data?.appVersion);
  const coinsDelta = sanitizeInteger(request.data?.coinsDelta, 0);
  const videosWatchedDelta = sanitizeInteger(request.data?.videosWatchedDelta, 0);
  const reason = sanitizeString(request.data?.reason || "progress");

  if (!sessionId) {
    throw new HttpsError("invalid-argument", "sessionId is required.");
  }
  requiresMinimumBuild(buildNumber);

  if (coinsDelta < 0 || videosWatchedDelta < 0) {
    throw new HttpsError(
      "invalid-argument",
      "coinsDelta/videosWatchedDelta must be >= 0."
    );
  }
  if (coinsDelta > 3 || videosWatchedDelta > 3) {
    throw new HttpsError(
      "invalid-argument",
      "Delta too large."
    );
  }

  const userRef = db.collection("users").doc(uid);
  const leaderboardRef = db.collection("leaderboard").doc(uid);
  const now = Date.now();

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const data = snap.data() || {};

    const storedSessionId = sanitizeString(data.activeSessionId);
    const updatedAtMs = data.activeSessionUpdatedAt?.toMillis
      ? data.activeSessionUpdatedAt.toMillis()
      : 0;
    if (!storedSessionId || storedSessionId !== sessionId) {
      throw new HttpsError(
        "failed-precondition",
        "Session invalid. Please reopen the app."
      );
    }
    if (updatedAtMs && now - updatedAtMs > VM_SESSION_STALE_MS) {
      throw new HttpsError(
        "failed-precondition",
        "Session expired. Please reopen the app."
      );
    }

    // Rate-limit coin rewards to stop farms.
    const windowStartMs = data.rewardWindowStartAt?.toMillis
      ? data.rewardWindowStartAt.toMillis()
      : 0;
    const windowCount = sanitizeInteger(data.rewardWindowCount, 0);
    const inSameWindow = windowStartMs && now - windowStartMs < VM_REWARD_WINDOW_MS;
    const nextWindowStart = inSameWindow ? windowStartMs : now;
    const nextWindowCount = inSameWindow
      ? windowCount + (coinsDelta > 0 ? 1 : 0)
      : (coinsDelta > 0 ? 1 : 0);

    if (coinsDelta > 0 && nextWindowCount > VM_REWARD_MAX_IN_WINDOW) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many rewards too fast. Slow down."
      );
    }

    const currentCoins = sanitizeInteger(data.coins, 0);
    const currentVideos = sanitizeInteger(data.videosWatched, 0);
    const nextCoins = currentCoins + coinsDelta;
    const nextVideos = currentVideos + videosWatchedDelta;

    const updates = {
      activeBuildNumber: buildNumber,
      activeAppVersion: appVersion,
      activeSessionId: sessionId,
      activeSessionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      rewardWindowStartAt: admin.firestore.Timestamp.fromMillis(nextWindowStart),
      rewardWindowCount: nextWindowCount,
      lastRewardReason: reason,
      lastRewardAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (coinsDelta !== 0) updates.coins = admin.firestore.FieldValue.increment(coinsDelta);
    if (videosWatchedDelta !== 0) updates.videosWatched = admin.firestore.FieldValue.increment(videosWatchedDelta);

    tx.set(userRef, updates, {merge: true});

    // Keep leaderboard in sync (best-effort).
    const email = sanitizeString(data.email);
    const customName = sanitizeString(data.leaderboardDisplayName);
    const publicName = customName || (email ? `${email.split("@")[0]}***` : "User");
    tx.set(
      leaderboardRef,
      {
        uid,
        customName,
        publicName,
        views: nextCoins,
        videosWatched: nextVideos,
        estimatedEarnings: Number((nextCoins * 0.001).toFixed(6)),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
  });

  return {ok: true};
});

exports.vmCreatePayoutRequest = onCall(async (request) => {
  const {uid, email: authEmail} = requireAuth(request);
  const buildNumber = sanitizeInteger(request.data?.buildNumber, 0);
  const appVersion = sanitizeString(request.data?.appVersion);
  const versionName = sanitizeString(request.data?.versionName);
  const coinsRequested = sanitizeInteger(request.data?.coinsRequested, 0);
  const payoutMethod = sanitizeString(request.data?.payoutMethod).toLowerCase();
  const payPalEmail = sanitizeString(request.data?.payPalEmail);
  const revolutUsername = sanitizeString(request.data?.revolutUsername);
  const accountHolderName = sanitizeString(request.data?.accountHolderName);
  const payoutCurrency = sanitizeString(request.data?.payoutCurrency).toUpperCase();
  const bankName = sanitizeString(request.data?.bankName);
  const iban = sanitizeString(request.data?.iban);
  const bankAccountNumber = sanitizeString(request.data?.bankAccountNumber);
  const cryptoAddress = sanitizeString(request.data?.cryptoAddress);

  requiresMinimumBuild(buildNumber);

  if (coinsRequested <= 0) {
    throw new HttpsError("invalid-argument", "Requested ads must be greater than zero.");
  }
  if (coinsRequested < VM_MINIMUM_PAYOUT_COINS) {
    throw new HttpsError(
      "failed-precondition",
      `Minimum payout is ${VM_MINIMUM_PAYOUT_COINS} ads.`
    );
  }
  if (!accountHolderName) {
    throw new HttpsError("invalid-argument", "Account holder name is required.");
  }
  if (!VM_ALLOWED_PAYOUT_METHODS.has(payoutMethod)) {
    throw new HttpsError("invalid-argument", "Select a payout method.");
  }
  if (!VM_ALLOWED_PAYOUT_CURRENCIES.has(payoutCurrency)) {
    throw new HttpsError("invalid-argument", "Select a payout currency.");
  }
  if (payoutMethod === "paypal" && !payPalEmail) {
    throw new HttpsError("invalid-argument", "Enter a PayPal email.");
  }
  if (payoutMethod === "revolut" && !revolutUsername) {
    throw new HttpsError("invalid-argument", "Enter your Revolut username.");
  }
  if ((payoutMethod === "btc" || payoutMethod === "usdc") && !cryptoAddress) {
    throw new HttpsError("invalid-argument", "Enter your crypto wallet address.");
  }

  const payoutRef = db.collection("payouts").doc();
  const userRef = db.collection("users").doc(uid);
  const leaderboardRef = db.collection("leaderboard").doc(uid);

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }

    const userData = userSnap.data() || {};
    const currentCoins = sanitizeInteger(userData.coins, 0);
    if (currentCoins < coinsRequested) {
      throw new HttpsError("failed-precondition", "Not enough ads available.");
    }

    const userEmail = sanitizeString(userData.email || authEmail);
    const customName = sanitizeString(userData.leaderboardDisplayName);
    const currentVideosWatched = sanitizeInteger(userData.videosWatched, 0);
    const remainingViews = currentCoins - coinsRequested;
    const legacyBankValue = iban || bankAccountNumber;

    tx.set(
      userRef,
      {
        coins: remainingViews,
      },
      {merge: true}
    );

    tx.set(
      leaderboardRef,
      {
        uid,
        customName,
        publicName: buildLeaderboardPublicName(userEmail, customName),
        views: remainingViews,
        videosWatched: currentVideosWatched,
        estimatedEarnings: Number((remainingViews * 0.001).toFixed(6)),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    tx.set(payoutRef, {
      userId: uid,
      userEmail,
      coinsRequested,
      payoutMethod,
      payoutCurrency,
      status: "pending",
      payPalEmail,
      ibanOrBankAccount: payoutMethod === "revolut" ? revolutUsername : legacyBankValue,
      revolutUsername,
      accountHolderName,
      bankName,
      iban,
      bankAccountNumber,
      cryptoAddress,
      appVersion,
      versionName,
      buildNumber,
      minimumRequiredVersion: VM_MINIMUM_PAYOUT_VERSION,
      minimumRequiredBuildNumber: VM_MINIMUM_BUILD_NUMBER,
      minimumPayoutCoins: VM_MINIMUM_PAYOUT_COINS,
      processingDays: VM_PAYOUT_PROCESSING_DAYS,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return {
    ok: true,
    payoutId: payoutRef.id,
  };
});

exports.vmCreateAdsTransfer = onCall(async (request) => {
  const {uid, email: authEmail} = requireAuth(request);
  await ensureAdsTransferEnabled();

  const buildNumber = sanitizeInteger(request.data?.buildNumber, VM_MINIMUM_BUILD_NUMBER);
  const appVersion = sanitizeString(request.data?.appVersion);
  const recipientEmail = sanitizeString(request.data?.recipientEmail).toLowerCase();
  const amountAds = sanitizeInteger(request.data?.amountAds, 0);
  requiresMinimumBuild(buildNumber);

  if (!recipientEmail || !recipientEmail.includes("@")) {
    throw new HttpsError("invalid-argument", "Enter a valid recipient email.");
  }
  if (amountAds <= 0) {
    throw new HttpsError("invalid-argument", "Enter a valid ads amount.");
  }
  if (amountAds > VM_AD_TRANSFER_DAILY_LIMIT) {
    throw new HttpsError(
      "failed-precondition",
      `Daily transfer limit is ${VM_AD_TRANSFER_DAILY_LIMIT} ads.`
    );
  }

  const recipient = await findUserByEmail(recipientEmail);
  if (!recipient || !recipient.uid) {
    throw new HttpsError("not-found", "Recipient account not found.");
  }
  if (recipient.uid === uid) {
    throw new HttpsError("failed-precondition", "You cannot send ads to yourself.");
  }

  const senderRef = db.collection("users").doc(uid);
  const recipientRef = db.collection("users").doc(recipient.uid);
  const senderLeaderboardRef = db.collection("leaderboard").doc(uid);
  const transferRef = db.collection("adTransfers").doc();
  const recipientInboxRef = db.collection("inboxMessages").doc();
  const todayKey = utcDayKey();

  await db.runTransaction(async (tx) => {
    const senderSnap = await tx.get(senderRef);
    const recipientSnap = await tx.get(recipientRef);

    if (!senderSnap.exists) {
      throw new HttpsError("not-found", "Sender account not found.");
    }
    if (!recipientSnap.exists) {
      throw new HttpsError("not-found", "Recipient account not found.");
    }

    const senderData = senderSnap.data() || {};
    const recipientData = recipientSnap.data() || {};
    const senderCoins = sanitizeInteger(senderData.coins, 0);
    if (senderCoins < amountAds) {
      throw new HttpsError("failed-precondition", "Not enough ads available.");
    }

    const senderSentDayKey = sanitizeString(senderData.adsTransferSentDayKey);
    const senderSentToday = senderSentDayKey === todayKey
      ? sanitizeInteger(senderData.adsTransferSentToday, 0)
      : 0;
    if (senderSentToday + amountAds > VM_AD_TRANSFER_DAILY_LIMIT) {
      throw new HttpsError(
        "failed-precondition",
        `You can send max ${VM_AD_TRANSFER_DAILY_LIMIT} ads per day.`
      );
    }

    const senderEmail = sanitizeString(senderData.email || authEmail).toLowerCase();
    const senderCustomName = sanitizeString(senderData.leaderboardDisplayName);
    const senderVideosWatched = sanitizeInteger(senderData.videosWatched, 0);
    const recipientStoredEmail = sanitizeString(recipientData.email || recipientEmail).toLowerCase();

    tx.set(
      senderRef,
      {
        coins: senderCoins - amountAds,
        adsTransferSentDayKey: todayKey,
        adsTransferSentToday: senderSentToday + amountAds,
      },
      {merge: true}
    );
    tx.set(
      senderLeaderboardRef,
      buildLeaderboardPayload({
        uid,
        email: senderEmail,
        customName: senderCustomName,
        views: senderCoins - amountAds,
        videosWatched: senderVideosWatched,
      }),
      {merge: true}
    );

    tx.set(transferRef, {
      senderUid: uid,
      senderEmail,
      recipientUid: recipient.uid,
      recipientEmail: recipientStoredEmail,
      amountAds,
      status: "pending",
      participants: [uid, recipient.uid],
      senderBuildNumber: buildNumber,
      senderAppVersion: appVersion,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(recipientInboxRef, {
      userId: recipient.uid,
      title: "Ads transfer request",
      message: `${senderEmail} wants to send you ${amountAds} ads. Open Wallet to accept or reject.`,
      type: "transfer",
      read: false,
      transferId: transferRef.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return {
    ok: true,
    transferId: transferRef.id,
  };
});

exports.vmAcceptAdsTransfer = onCall(async (request) => {
  const {uid} = requireAuth(request);
  const transferId = sanitizeString(request.data?.transferId);
  if (!transferId) {
    throw new HttpsError("invalid-argument", "Missing transfer id.");
  }

  const transferRef = db.collection("adTransfers").doc(transferId);
  const senderInboxRef = db.collection("inboxMessages").doc();

  await db.runTransaction(async (tx) => {
    const transferSnap = await tx.get(transferRef);
    if (!transferSnap.exists) {
      throw new HttpsError("not-found", "Transfer not found.");
    }

    const transfer = transferSnap.data() || {};
    const status = sanitizeString(transfer.status).toLowerCase();
    const recipientUid = sanitizeString(transfer.recipientUid);
    if (recipientUid !== uid) {
      throw new HttpsError("permission-denied", "Only the recipient can accept.");
    }
    if (status !== "pending") {
      throw new HttpsError("failed-precondition", "Transfer is no longer pending.");
    }

    const amountAds = sanitizeInteger(transfer.amountAds, 0);
    const recipientRef = db.collection("users").doc(recipientUid);
    const recipientLeaderboardRef = db.collection("leaderboard").doc(recipientUid);
    const recipientSnap = await tx.get(recipientRef);
    if (!recipientSnap.exists) {
      throw new HttpsError("not-found", "Recipient account not found.");
    }

    const recipientData = recipientSnap.data() || {};
    const recipientCoins = sanitizeInteger(recipientData.coins, 0);
    const recipientVideosWatched = sanitizeInteger(recipientData.videosWatched, 0);
    const recipientEmail = sanitizeString(recipientData.email || transfer.recipientEmail).toLowerCase();
    const recipientCustomName = sanitizeString(recipientData.leaderboardDisplayName);

    tx.set(
      recipientRef,
      {
        coins: recipientCoins + amountAds,
      },
      {merge: true}
    );
    tx.set(
      recipientLeaderboardRef,
      buildLeaderboardPayload({
        uid: recipientUid,
        email: recipientEmail,
        customName: recipientCustomName,
        views: recipientCoins + amountAds,
        videosWatched: recipientVideosWatched,
      }),
      {merge: true}
    );
    tx.set(
      transferRef,
      {
        status: "accepted",
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
    tx.set(senderInboxRef, {
      userId: sanitizeString(transfer.senderUid),
      title: "Ads transfer accepted",
      message: `${sanitizeString(transfer.recipientEmail)} accepted your ${amountAds} ads transfer.`,
      type: "transfer",
      read: false,
      transferId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return {ok: true};
});

exports.vmRejectAdsTransfer = onCall(async (request) => {
  const {uid} = requireAuth(request);
  const transferId = sanitizeString(request.data?.transferId);
  if (!transferId) {
    throw new HttpsError("invalid-argument", "Missing transfer id.");
  }

  const transferRef = db.collection("adTransfers").doc(transferId);
  const senderInboxRef = db.collection("inboxMessages").doc();

  await db.runTransaction(async (tx) => {
    const transferSnap = await tx.get(transferRef);
    if (!transferSnap.exists) {
      throw new HttpsError("not-found", "Transfer not found.");
    }

    const transfer = transferSnap.data() || {};
    const status = sanitizeString(transfer.status).toLowerCase();
    const recipientUid = sanitizeString(transfer.recipientUid);
    if (recipientUid !== uid) {
      throw new HttpsError("permission-denied", "Only the recipient can reject.");
    }
    if (status !== "pending") {
      throw new HttpsError("failed-precondition", "Transfer is no longer pending.");
    }

    const amountAds = sanitizeInteger(transfer.amountAds, 0);
    const senderUid = sanitizeString(transfer.senderUid);
    const senderRef = db.collection("users").doc(senderUid);
    const senderLeaderboardRef = db.collection("leaderboard").doc(senderUid);
    const senderSnap = await tx.get(senderRef);
    if (!senderSnap.exists) {
      throw new HttpsError("not-found", "Sender account not found.");
    }

    const senderData = senderSnap.data() || {};
    const senderCoins = sanitizeInteger(senderData.coins, 0);
    const senderVideosWatched = sanitizeInteger(senderData.videosWatched, 0);
    const senderEmail = sanitizeString(senderData.email || transfer.senderEmail).toLowerCase();
    const senderCustomName = sanitizeString(senderData.leaderboardDisplayName);

    tx.set(
      senderRef,
      {
        coins: senderCoins + amountAds,
      },
      {merge: true}
    );
    tx.set(
      senderLeaderboardRef,
      buildLeaderboardPayload({
        uid: senderUid,
        email: senderEmail,
        customName: senderCustomName,
        views: senderCoins + amountAds,
        videosWatched: senderVideosWatched,
      }),
      {merge: true}
    );
    tx.set(
      transferRef,
      {
        status: "rejected",
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
    tx.set(senderInboxRef, {
      userId: senderUid,
      title: "Ads transfer rejected",
      message: `${sanitizeString(transfer.recipientEmail)} rejected your ${amountAds} ads transfer.`,
      type: "transfer",
      read: false,
      transferId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return {ok: true};
});
