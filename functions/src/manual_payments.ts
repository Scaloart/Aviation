import * as functionsV1 from "firebase-functions/v1";
import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

/**
 * Approve manual bank transfer submissions.
 * Trigger: Firestore update on manual_payments/{paymentId}
 * When status transitions to 'approved', set the user's subscription to active
 * for durationMonths (default 12). Never reduce an existing later expiry.
 *
 * Firestore doc shape (manual_payments/{id}):
 * - uid: string
 * - status: 'pending' | 'approved' | 'rejected'
 * - durationMonths?: number (default 12)
 * - proofUrl?: string
 * - createdAt: Timestamp
 * - approvedAt?: Timestamp
 */
export const onManualPaymentStatusChange = functionsV1
  .region("us-central1")
  .firestore.document("manual_payments/{paymentId}")
  .onWrite(async (
    change: functionsV1.Change<FirebaseFirestore.DocumentSnapshot>,
    context: functionsV1.EventContext
  ) => {
    const before = change.before.exists ? (change.before.data() || ({} as any)) : ({} as any);
    const after = change.after.exists ? (change.after.data() || ({} as any)) : ({} as any);

    const prevStatusRaw = (before.status as string | undefined) || undefined;
    const newStatusRaw = (after.status as string | undefined) || undefined;
    const prevStatus = prevStatusRaw ? prevStatusRaw.toLowerCase() : undefined;
    const newStatus = newStatusRaw ? newStatusRaw.toLowerCase() : undefined;
    const uid = after.uid as string | undefined;

    if (!uid) {
      functionsV1.logger.warn("manual_payments doc missing uid", { id: context.params.paymentId });
      return;
    }

    // Only act when transitioning into approved (case-insensitive)
    const isApprovedTransition = newStatus === "approved" && prevStatus !== "approved";
    if (!isApprovedTransition) {
      functionsV1.logger.info("Manual payment write ignored (status not transitioned to approved)", { prevStatus, newStatus });
      return;
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);

    // Compute expiry by durationMonths (default 12 months)
    const months = Number.isFinite(after.durationMonths) && after.durationMonths > 0 ? after.durationMonths : 12;
    const computed = new Date();
    computed.setMonth(computed.getMonth() + months);
    let derivedExpiry = admin.firestore.Timestamp.fromDate(computed);

    // Never reduce existing later expiry
    try {
      const userSnap = await userRef.get();
      const existing: FirebaseFirestore.Timestamp | undefined = userSnap.data()?.subscription?.expiryDate;
      if (existing && existing.toMillis() > derivedExpiry.toMillis()) {
        functionsV1.logger.info("Keeping existing later expiry on manual approval", {
          existing: existing.toDate().toISOString(),
          newComputed: derivedExpiry.toDate().toISOString(),
        });
        derivedExpiry = existing;
      }
    } catch (e) {
      functionsV1.logger.warn("Failed reading existing user subscription before manual approval write", {
        error: (e as any)?.message,
      });
    }

    // Choose a planId label based on months
    const planId = months >= 12 ? "BANK_TRANSFER_ANNUAL" : months >= 6 ? "BANK_TRANSFER_6M" : "BANK_TRANSFER_1M";

    const subscriptionData = {
      type: "premium",
      provider: "manual",
      planId,
      status: "active",
      expiryDate: derivedExpiry,
    };

    await userRef.set({ subscription: subscriptionData }, { merge: true });

    // Stamp approval time
    if (change.after.exists) {
      await change.after.ref.set({ approvedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    }

    functionsV1.logger.info("Manual payment approved and subscription updated", {
      uid,
      months,
      expiry: derivedExpiry.toDate().toISOString(),
    });
  });
