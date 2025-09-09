import { onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

/**
 * Helpers
 */
function requireAuth(context: any) {
  if (!context.auth) {
    throw new Error("UNAUTHENTICATED");
  }
}

async function isAdminOrSuper(email?: string, uid?: string): Promise<boolean> {
  try {
    if (email && email.toLowerCase() === "slw.dwc@gmail.com") return true; // super admin by email
    if (!uid) return false;
    const user = await admin.auth().getUser(uid);
    const roles = (user.customClaims?.roles as Record<string, unknown> | undefined) || undefined;
    return roles != null && roles["admin"] === true;
  } catch (e) {
    logger.warn("Failed isAdminOrSuper check", { error: (e as any)?.message });
    return false;
  }
}

/**
 * Callable: set or remove admin role via custom claims
 * Restricted to super admin (email match) or existing admin.
 * data: { uid: string, value: boolean }
 */
export const adminSetUserAdminRole = onCall({ region: "us-central1" }, async (request) => {
  requireAuth(request);
  const callerEmail = request.auth?.token?.email as string | undefined;
  const callerUid = request.auth?.uid as string | undefined;
  const allowed = await isAdminOrSuper(callerEmail, callerUid);
  if (!allowed) throw new Error("PERMISSION_DENIED");

  const uid = (request.data?.uid as string | undefined) || undefined;
  const value = Boolean(request.data?.value);
  if (!uid) throw new Error("invalid-argument: uid required");

  const user = await admin.auth().getUser(uid);
  const existingClaims = (user.customClaims || {}) as Record<string, unknown>;
  const existingRoles = (existingClaims["roles"] as Record<string, unknown> | undefined) || {};
  const newRoles = { ...existingRoles, admin: value } as Record<string, unknown>;
  const newClaims = { ...existingClaims, roles: newRoles } as Record<string, unknown>;
  await admin.auth().setCustomUserClaims(uid, newClaims);

  // Invalidate tokens
  await admin.auth().revokeRefreshTokens(uid);

  // Mirror to Firestore so clients can read admin flag without privileged callable
  try {
    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    await userRef.set({ roles: { admin: value } }, { merge: true });
  } catch (e) {
    logger.warn("Failed mirroring roles.admin to Firestore", { error: (e as any)?.message, uid, value });
  }

  return { ok: true, uid, value };
});

/**
 * Callable: approve or reject a manual payment
 * data: { paymentId: string, approved: boolean }
 * Side effect: updates manual_payments/{id}.status; onWrite trigger will adjust subscription
 */
export const adminApproveManualPayment = onCall({ region: "us-central1" }, async (request) => {
  requireAuth(request);
  const callerEmail = request.auth?.token?.email as string | undefined;
  const callerUid = request.auth?.uid as string | undefined;
  const allowed = await isAdminOrSuper(callerEmail, callerUid);
  if (!allowed) throw new Error("PERMISSION_DENIED");

  const paymentId = (request.data?.paymentId as string | undefined) || undefined;
  const approved = Boolean(request.data?.approved);
  if (!paymentId) throw new Error("invalid-argument: paymentId required");

  const db = admin.firestore();
  const ref = db.collection("manual_payments").doc(paymentId);
  await ref.set(
    {
      status: approved ? "approved" : "rejected",
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { ok: true, paymentId, status: approved ? "approved" : "rejected" };
});

/**
 * Callable: adjust a user's subscription
 * data: { uid: string, action: 'extend'|'cancel'|'setExpiry', months?: number, expiryDateIso?: string }
 */
export const adminAdjustSubscription = onCall({ region: "us-central1" }, async (request) => {
  requireAuth(request);
  const callerEmail = request.auth?.token?.email as string | undefined;
  const callerUid = request.auth?.uid as string | undefined;
  const allowed = await isAdminOrSuper(callerEmail, callerUid);
  if (!allowed) throw new Error("PERMISSION_DENIED");

  const uid = (request.data?.uid as string | undefined) || undefined;
  const action = (request.data?.action as string | undefined) || undefined;
  if (!uid || !action) throw new Error("invalid-argument: uid and action required");

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const snap = await userRef.get();
  const userData = snap.data() || {};
  const sub = (userData["subscription"] as Record<string, any> | undefined) || {};

  if (action === "cancel") {
    const newSub = { ...sub, status: "canceled" };
    await userRef.set({ subscription: newSub }, { merge: true });
    return { ok: true, action };
  }

  if (action === "extend") {
    const months = Number(request.data?.months) || 1;
    const now = new Date();
    let base = sub["expiryDate"]?.toDate?.() as Date | undefined;
    if (!base || base < now) base = now;
    const target = new Date(base);
    target.setMonth(target.getMonth() + months);
    const ts = admin.firestore.Timestamp.fromDate(target);
    const newSub = { ...sub, status: "active", type: sub.type || "premium", provider: sub.provider || "admin", expiryDate: ts };
    await userRef.set({ subscription: newSub }, { merge: true });
    return { ok: true, action, months, expiry: target.toISOString() };
  }

  if (action === "setExpiry") {
    const iso = (request.data?.expiryDateIso as string | undefined) || undefined;
    if (!iso) throw new Error("invalid-argument: expiryDateIso required");
    const date = new Date(iso);
    if (isNaN(date.getTime())) throw new Error("invalid-argument: invalid ISO date");
    const ts = admin.firestore.Timestamp.fromDate(date);
    const newSub = { ...sub, status: "active", type: sub.type || "premium", provider: sub.provider || "admin", expiryDate: ts };
    await userRef.set({ subscription: newSub }, { merge: true });
    return { ok: true, action, expiry: date.toISOString() };
  }

  throw new Error("invalid-argument: unknown action");
});

/**
 * Callable: get a user's admin role status
 * data: { uid: string }
 */
export const adminGetUserAdminRole = onCall({ region: "us-central1" }, async (request) => {
  requireAuth(request);
  const callerEmail = request.auth?.token?.email as string | undefined;
  const callerUid = request.auth?.uid as string | undefined;
  const allowed = await isAdminOrSuper(callerEmail, callerUid);
  if (!allowed) throw new Error("PERMISSION_DENIED");

  const uid = (request.data?.uid as string | undefined) || undefined;
  if (!uid) throw new Error("invalid-argument: uid required");

  const user = await admin.auth().getUser(uid);
  const roles = (user.customClaims?.roles as Record<string, unknown> | undefined) || undefined;
  const isAdmin = roles != null && roles["admin"] === true;
  return { ok: true, uid, isAdmin };
});

/**
 * Callable: delete a user (Auth account) and remove users/{uid} document.
 * data: { uid: string }
 */
export const adminDeleteUser = onCall({ region: "us-central1" }, async (request) => {
  requireAuth(request);
  const callerEmail = request.auth?.token?.email as string | undefined;
  const callerUid = request.auth?.uid as string | undefined;
  const allowed = await isAdminOrSuper(callerEmail, callerUid);
  if (!allowed) throw new Error("PERMISSION_DENIED");

  const uid = (request.data?.uid as string | undefined) || undefined;
  if (!uid) throw new Error("invalid-argument: uid required");

  const db = admin.firestore();
  // Best-effort Firestore cleanup
  try {
    await db.collection("users").doc(uid).delete();
  } catch (e) {
    logger.warn("Failed deleting users/{uid} doc", { error: (e as any)?.message, uid });
  }

  // Delete auth user
  await admin.auth().deleteUser(uid);
  return { ok: true, uid };
});
