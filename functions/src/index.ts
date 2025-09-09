import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { Request, Response } from "express";
admin.initializeApp();

export const registerDevice = functions.https.onCall(async (data: any, context: any) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Not signed in");
  }
  const uid = context.auth.uid;
  const { installationId, platform, deviceName } = (data as any) || {};
  if (!installationId || typeof installationId !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "installationId required");
  }

  const devicesCol = admin.firestore().collection("users").doc(uid).collection("devices");
  const deviceRef = devicesCol.doc(installationId);
  const now = admin.firestore.FieldValue.serverTimestamp();

  // If already registered, just update lastSeen
  const existing = await deviceRef.get();
  if (existing.exists) {
    await deviceRef.update({ lastSeen: now, platform: platform || "unknown", deviceName: deviceName || "" });
    return { status: "ok", registered: true };
  }

  // Enforce two-device limit with auto-eviction of the oldest device
  const snap = await devicesCol.get();
  const count = snap.size;
  if (count >= 2) {
    // Strict 2-device policy: block registration of a third device
    throw new functions.https.HttpsError("failed-precondition", "device_limit_reached");
  }

  await deviceRef.set({
    platform: platform || "unknown",
    deviceName: deviceName || "",
    createdAt: now,
    lastSeen: now,
  });

  return { status: "ok", registered: true };
});

export const removeDevice = functions.https.onCall(async (data: any, context: any) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Not signed in");
  const uid = context.auth.uid;
  const { installationId } = (data as any) || {};
  if (!installationId) throw new functions.https.HttpsError("invalid-argument", "installationId required");

  await admin.firestore().collection("users").doc(uid).collection("devices").doc(installationId).delete();
  return { status: "ok" };
});

// Shared logic for device registration (used by HTTP fallback)
async function doRegisterDevice(uid: string, installationId: string, platform?: string, deviceName?: string) {
  const devicesCol = admin.firestore().collection("users").doc(uid).collection("devices");
  const deviceRef = devicesCol.doc(installationId);
  const now = admin.firestore.FieldValue.serverTimestamp();

  const existing = await deviceRef.get();
  if (existing.exists) {
    await deviceRef.update({ lastSeen: now, platform: platform || "unknown", deviceName: deviceName || "" });
    return;
  }

  const snap = await devicesCol.get();
  const count = snap.size;
  if (count >= 2) {
    // Strict 2-device policy for REST helper as well
    throw new functions.https.HttpsError("failed-precondition", "device_limit_reached");
  }

  await deviceRef.set({
    platform: platform || "unknown",
    deviceName: deviceName || "",
    createdAt: now,
    lastSeen: now,
  });
}

// HTTP fallback endpoint for desktop clients (Windows/Linux)
export const registerDeviceHttp = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }
  if (req.method !== "POST") {
    res.status(405).json({ error: "method_not_allowed" });
    return;
  }
  try {
    const auth = req.headers.authorization || "";
    const match = auth.match(/^Bearer\s+(.*)$/i);
    if (!match) {
      res.status(401).json({ error: { message: "Missing Authorization header", status: "UNAUTHENTICATED" } });
      return;
    }
    const idToken = match[1];
    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const { installationId, platform, deviceName } = (req.body || {}) as any;
    if (!installationId || typeof installationId !== "string") {
      res.status(400).json({ error: { message: "installationId required", status: "INVALID_ARGUMENT" } });
      return;
    }

    try {
      await doRegisterDevice(uid, installationId, platform, deviceName);
      res.json({ status: "ok", registered: true });
    } catch (e: any) {
      if (e instanceof functions.https.HttpsError && e.code === "failed-precondition") {
        res.status(409).json({ error: { message: "device_limit_reached", status: "FAILED_PRECONDITION" } });
        return;
      }
      throw e;
    }
  } catch (e: any) {
    console.error("registerDeviceHttp error", e);
    res.status(500).json({ error: { message: e?.message || String(e), status: "INTERNAL" } });
  }
});

// HTTP version of removeDevice for desktop/Windows REST clients
export const removeDeviceHttp = functions.https.onRequest(async (req: Request, res: Response) => {
  setCors(res);
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  if (req.method !== "POST") { res.status(405).json({ error: "method_not_allowed" }); return; }
  try {
    const uid = await verifyBearerIdToken(req);
    const installationId = (req.body?.installationId as string) || "";
    if (!installationId) { res.status(400).json({ error: { message: "installationId required", status: "INVALID_ARGUMENT" } }); return; }
    const devicesCol = admin.firestore().collection("users").doc(uid).collection("devices");
    await devicesCol.doc(installationId).delete();
    res.json({ status: "ok" });
  } catch (e: any) {
    const msg = e?.message || String(e);
    if (e instanceof functions.https.HttpsError) {
      res.status(e.code === "permission-denied" ? 403 : 401).json({ error: { message: e.message, status: e.code.toUpperCase().replace(/-/g, "_") } });
      return;
    }
    res.status(401).json({ error: { message: msg, status: "UNAUTHENTICATED" } });
  }
});

// ---------- Admin helpers ----------
async function isAdminUser(uid: string): Promise<boolean> {
  try {
    const user = await admin.auth().getUser(uid);
    if ((user.customClaims as any)?.admin === true) return true;
  } catch (_) {
    // ignore
  }
  try {
    const doc = await admin.firestore().collection("users").doc(uid).get();
    const roles = (doc.data() as any)?.roles || {};
    if (roles && roles.admin === true) return true;
  } catch (_) {
    // ignore
  }
  return false;
}

export const adminGetUserAdminRole = functions.https.onCall(async (data: any, context: any) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Not signed in");
  // Only admins may query roles
  const callerUid = context.auth.uid;
  const callerIsAdmin = await isAdminUser(callerUid);
  if (!callerIsAdmin) throw new functions.https.HttpsError("permission-denied", "Admins only");

  const targetUid = (data?.uid as string) || "";
  if (!targetUid) throw new functions.https.HttpsError("invalid-argument", "uid required");
  const targetIsAdmin = await isAdminUser(targetUid);
  return { isAdmin: targetIsAdmin };
});

export const adminSetUserAdminRole = functions.https.onCall(async (data: any, context: any) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Not signed in");
  const callerUid = context.auth.uid;
  const callerIsAdmin = await isAdminUser(callerUid);
  if (!callerIsAdmin) throw new functions.https.HttpsError("permission-denied", "Admins only");

  const targetUid = (data?.uid as string) || "";
  const value = data?.value as boolean | undefined;
  if (!targetUid || typeof value !== "boolean") {
    throw new functions.https.HttpsError("invalid-argument", "uid and boolean value required");
  }
  // Update Firestore roles
  const userRef = admin.firestore().collection("users").doc(targetUid);
  await userRef.set({ roles: { admin: value } }, { merge: true });
  // Update custom claims for faster checks across platforms
  const rec = await admin.auth().getUser(targetUid).catch(() => null);
  const currentClaims = (rec?.customClaims as any) || {};
  const nextClaims = { ...currentClaims, admin: value };
  await admin.auth().setCustomUserClaims(targetUid, nextClaims);
  return { status: "ok", uid: targetUid, admin: value };
});

export const adminDeleteUser = functions.https.onCall(async (data: any, context: any) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Not signed in");
  const callerUid = context.auth.uid;
  const callerIsAdmin = await isAdminUser(callerUid);
  if (!callerIsAdmin) throw new functions.https.HttpsError("permission-denied", "Admins only");

  const targetUid = (data?.uid as string) || "";
  if (!targetUid) throw new functions.https.HttpsError("invalid-argument", "uid required");
  if (targetUid === callerUid) throw new functions.https.HttpsError("failed-precondition", "Cannot delete your own account");

  // Clean up user's devices subcollection (best-effort)
  const devicesCol = admin.firestore().collection("users").doc(targetUid).collection("devices");
  const devs = await devicesCol.get();
  const batch = admin.firestore().batch();
  devs.forEach((d) => batch.delete(d.ref));
  await batch.commit().catch(() => undefined);

  // Delete Firestore user doc (subcollections already handled above)
  await admin.firestore().collection("users").doc(targetUid).delete().catch(() => undefined);

  // Delete Auth user (idempotent)
  try {
    await admin.auth().deleteUser(targetUid);
  } catch (e: any) {
    // If already deleted, consider it success
    if (e?.code !== "auth/user-not-found") {
      throw new functions.https.HttpsError("internal", e?.message || String(e));
    }
  }
  return { status: "ok", uid: targetUid };
});

// HTTP Admin endpoints (for Windows/desktop REST clients)
function setCors(res: Response) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
}

async function verifyBearerIdToken(req: Request): Promise<string> {
  const auth = req.headers.authorization || "";
  const match = auth.match(/^Bearer\s+(.*)$/i);
  if (!match) throw new functions.https.HttpsError("unauthenticated", "Missing Authorization header");
  const idToken = match[1];
  const decoded = await admin.auth().verifyIdToken(idToken);
  return decoded.uid;
}

export const adminGetUserAdminRoleHttp = functions.https.onRequest(async (req: Request, res: Response) => {
  setCors(res);
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  if (req.method !== "POST") { res.status(405).json({ error: "method_not_allowed" }); return; }
  try {
    const callerUid = await verifyBearerIdToken(req);
    const callerIsAdmin = await isAdminUser(callerUid);
    if (!callerIsAdmin) { res.status(403).json({ error: { message: "Admins only", status: "PERMISSION_DENIED" } }); return; }
    const targetUid = (req.body?.uid as string) || "";
    if (!targetUid) { res.status(400).json({ error: { message: "uid required", status: "INVALID_ARGUMENT" } }); return; }
    const targetIsAdmin = await isAdminUser(targetUid);
    res.json({ isAdmin: targetIsAdmin });
  } catch (e: any) {
    const msg = e?.message || String(e);
    const code = e?.code === "auth/argument-error" ? 400 : 401;
    if (e instanceof functions.https.HttpsError) {
      res.status(e.code === "permission-denied" ? 403 : 401).json({ error: { message: e.message, status: e.code.toUpperCase().replace(/-/g, "_") } });
      return;
    }
    res.status(code).json({ error: { message: msg, status: code === 401 ? "UNAUTHENTICATED" : "INVALID_ARGUMENT" } });
  }
});

export const adminSetUserAdminRoleHttp = functions.https.onRequest(async (req: Request, res: Response) => {
  setCors(res);
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  if (req.method !== "POST") { res.status(405).json({ error: "method_not_allowed" }); return; }
  try {
    const callerUid = await verifyBearerIdToken(req);
    const callerIsAdmin = await isAdminUser(callerUid);
    if (!callerIsAdmin) { res.status(403).json({ error: { message: "Admins only", status: "PERMISSION_DENIED" } }); return; }
    const targetUid = (req.body?.uid as string) || "";
    const value = req.body?.value;
    if (!targetUid || typeof value !== "boolean") { res.status(400).json({ error: { message: "uid and boolean value required", status: "INVALID_ARGUMENT" } }); return; }
    const userRef = admin.firestore().collection("users").doc(targetUid);
    await userRef.set({ roles: { admin: value } }, { merge: true });
    const rec = await admin.auth().getUser(targetUid).catch(() => null);
    const currentClaims = (rec?.customClaims as any) || {};
    const nextClaims = { ...currentClaims, admin: value };
    await admin.auth().setCustomUserClaims(targetUid, nextClaims);
    res.json({ status: "ok", uid: targetUid, admin: value });
  } catch (e: any) {
    const msg = e?.message || String(e);
    if (e instanceof functions.https.HttpsError) {
      res.status(e.code === "permission-denied" ? 403 : 401).json({ error: { message: e.message, status: e.code.toUpperCase().replace(/-/g, "_") } });
      return;
    }
    res.status(401).json({ error: { message: msg, status: "UNAUTHENTICATED" } });
  }
});

export const adminDeleteUserHttp = functions.https.onRequest(async (req: Request, res: Response) => {
  setCors(res);
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }
  if (req.method !== "POST") { res.status(405).json({ error: "method_not_allowed" }); return; }
  try {
    const callerUid = await verifyBearerIdToken(req);
    const callerIsAdmin = await isAdminUser(callerUid);
    if (!callerIsAdmin) { res.status(403).json({ error: { message: "Admins only", status: "PERMISSION_DENIED" } }); return; }
    const targetUid = (req.body?.uid as string) || "";
    if (!targetUid) { res.status(400).json({ error: { message: "uid required", status: "INVALID_ARGUMENT" } }); return; }
    if (targetUid === callerUid) { res.status(400).json({ error: { message: "Cannot delete your own account", status: "FAILED_PRECONDITION" } }); return; }
    const devicesCol = admin.firestore().collection("users").doc(targetUid).collection("devices");
    const devs = await devicesCol.get();
    const batch = admin.firestore().batch();
    devs.forEach((d) => batch.delete(d.ref));
    await batch.commit().catch(() => undefined);
    await admin.firestore().collection("users").doc(targetUid).delete().catch(() => undefined);
    try {
      await admin.auth().deleteUser(targetUid);
    } catch (e: any) {
      if (e?.code !== "auth/user-not-found") {
        // Unknown error from Auth delete
        res.status(500).json({ error: { message: e?.message || String(e), status: "INTERNAL" } });
        return;
      }
      // user-not-found -> already deleted, continue as success
    }
    res.json({ status: "ok", uid: targetUid });
  } catch (e: any) {
    const msg = e?.message || String(e);
    if (e instanceof functions.https.HttpsError) {
      res.status(e.code === "permission-denied" ? 403 : 401).json({ error: { message: e.message, status: e.code.toUpperCase().replace(/-/g, "_") } });
      return;
    }
    // Non-auth error bubbled up; surface as 500 to avoid misleading UNAUTHENTICATED
    res.status(500).json({ error: { message: msg, status: "INTERNAL" } });
  }
});

// ---------- PayPal endpoints ----------
// Re-export PayPal-related HTTPS functions so that Firebase deploys them.
export { createPaypalSubscription, paypalWebhook, fixUserExpiry } from "./paypal";

// ---------- Admin (v2) endpoints not defined above ----------
// Only export functions that are not already declared in this file to avoid name collisions.
export { adminApproveManualPayment, adminAdjustSubscription } from "./admin";

// ---------- Firestore triggers ----------
export { onManualPaymentStatusChange } from "./manual_payments";