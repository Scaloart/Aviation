import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import axios from "axios";

// Ensure Admin SDK initialized (in case this module loads before others)
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Environment/config
// Environment variables should be set in a .env file for local testing
// and configured in the Google Cloud console for deployment.
const getPaypalBaseUrl = () => {
  const env = (process.env.PAYPAL_ENV || "sandbox").toLowerCase();
  return env === "live"
    ? "https://api-m.paypal.com"
    : "https://api-m.sandbox.paypal.com";
};

async function getAccessToken(): Promise<string> {
  // Prefer env vars, fallback to Firebase Functions config
  let clientId = process.env.PAYPAL_CLIENT_ID;
  let clientSecret = process.env.PAYPAL_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    try {
      const cfg = (functions.config()?.paypal as any) || {};
      clientId = clientId || cfg.client_id || cfg.clientid;
      clientSecret = clientSecret || cfg.client_secret || cfg.clientsecret;
    } catch (_) {
      // ignore
    }
  }
  if (!clientId || !clientSecret) {
    throw new Error("Missing PayPal credentials in functions config.");
  }
  const base = getPaypalBaseUrl();
  const resp = await axios.post(
    `${base}/v1/oauth2/token`,
    new URLSearchParams({grant_type: "client_credentials"}).toString(),
    {
      auth: {username: clientId, password: clientSecret},
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      timeout: 10000,
    },
  );
  return resp.data.access_token as string;
}

/**
 * Creates a PayPal subscription for a plan and returns the approval URL.
 * Body: { uid: string, planId: string, returnUrl: string, cancelUrl: string }
 */
export const createPaypalSubscription = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }
  try {
    const {uid, planId, returnUrl, cancelUrl} = req.body || {};
    if (!uid || !planId || !returnUrl || !cancelUrl) {
      res.status(400).send("Missing uid, planId, returnUrl or cancelUrl");
      return;
    }

    const accessToken = await getAccessToken();
    const base = getPaypalBaseUrl();

    const createBody = {
      plan_id: planId,
      custom_id: uid, // we use this to map webhook events to the user
      application_context: {
        brand_name: "BrieFly",
        return_url: returnUrl,
        cancel_url: cancelUrl,
        user_action: "SUBSCRIBE_NOW",
      },
    };

    const resp = await axios.post(`${base}/v1/billing/subscriptions`, createBody, {
      headers: {Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json"},
      timeout: 15000,
    });

    const links: Array<{rel: string; href: string}> = resp.data.links || [];
    const approve = links.find((l) => l.rel === "approve");
    if (!approve) {
      res.status(500).send("No approval link returned from PayPal");
      return;
    }

    res.status(200).json({approvalUrl: approve.href, id: resp.data.id});
  } catch (e: any) { // eslint-disable-line @typescript-eslint/no-explicit-any
    console.error("Error creating PayPal subscription:", e);

    // Log detailed error information if available from Axios
    if (e.response) {
      console.error("PayPal API Error Response:", e.response.data);
      res.status(e.response.status || 500).send(e.response.data);
    } else {
      console.error("Non-API Error in createPaypalSubscription:", e.message);
      res.status(500).send({error: "Internal Server Error", detail: e.message});
    }
  }
});

/**
 * Admin utility: Fix a user's subscription expiry by planId.
 * Usage: GET .../fixUserExpiry?uid=<uid>
 * Recomputes expiry as now + (1m|6m|12m) based on planId and never reduces expiry.
 */
export const fixUserExpiry = functions.https.onRequest(async (req, res) => {
  try {
    const uid = (req.query.uid as string) || "";
    if (!uid) {
      res.status(400).send("Missing uid");
      return;
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const snap = await userRef.get();
    const sub = (snap.data()?.subscription as any) || {};
    const planId: string | undefined = sub.planId;
    if (!planId) {
      res.status(400).send("No subscription.planId for user");
      return;
    }

    // Plan IDs must match those used elsewhere
    const oneMonthPlanId = "P-9YT393282A868115SNCSSOSQ";
    const sixMonthPlanId = "P-5NF68931P45223030NCSWB7I";
    const oneYearPlanId = "P-85A08894HN724960VNCZY5MQ";

    const computed = new Date();
    if (planId === oneMonthPlanId) {
      computed.setMonth(computed.getMonth() + 1);
    } else if (planId === sixMonthPlanId) {
      computed.setMonth(computed.getMonth() + 6);
    } else if (planId === oneYearPlanId) {
      computed.setFullYear(computed.getFullYear() + 1);
    } else {
      res.status(400).send(`Unknown planId: ${planId}`);
      return;
    }

    let derivedExpiry = admin.firestore.Timestamp.fromDate(computed);

    // Never reduce expiry
    const existing: FirebaseFirestore.Timestamp | undefined = sub.expiryDate;
    if (existing && existing.toMillis() > derivedExpiry.toMillis()) {
      derivedExpiry = existing;
    }

    await userRef.set(
      {
        subscription: {
          ...sub,
          type: "premium",
          provider: "paypal",
          status: "active",
          expiryDate: derivedExpiry,
        },
      },
      { merge: true }
    );

    res.status(200).json({
      uid,
      planId,
      expiryDate: derivedExpiry.toDate().toISOString(),
    });
  } catch (e: any) {
    console.error("fixUserExpiry error", e?.message);
    res.status(500).send("Internal Server Error");
  }
});

/**
 * PayPal Webhook receiver. Configure this URL in PayPal dashboard.
 * We expect events like BILLING.SUBSCRIPTION.ACTIVATED, BILLING.SUBSCRIPTION.CANCELLED, BILLING.SUBSCRIPTION.EXPIRED
 */
export const paypalWebhook = functions.https.onRequest(async (req, res) => {
  // TODO: Verify webhook signature (PayPal-Transmission-* headers) for security.
  // For MVP, process without verification.
  try {
    const event = req.body;
    const eventType: string = event?.event_type;
    const resource = event?.resource || {};
    const uid: string | undefined = resource?.custom_id;
    const WEBHOOK_VERSION = "v2.1"; // bump when logic changes

    if (!eventType || !uid) {
      res.status(400).send("Missing event_type or custom_id(uid)");
      return;
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);

    // Derive expiry if available
    // PayPal subscription resource has billing_info.next_billing_time/last_payment time etc.
    let expiryDate: FirebaseFirestore.Timestamp | null = null;
    const nextBilling = resource?.billing_info?.next_billing_time;
    if (nextBilling) {
      const ms = Date.parse(nextBilling);
      if (!Number.isNaN(ms)) expiryDate = admin.firestore.Timestamp.fromMillis(ms);
    }

    const planId: string | undefined = resource?.plan_id;

    // Define Plan IDs from your PayPal product setup (aligned with client)
    const oneMonthPlanId = "P-9YT393282A868115SNCSSOSQ";
    const sixMonthPlanId = "P-5NF68931P45223030NCSWB7I";
    const oneYearPlanId = "P-85A08894HN724960VNCZY5MQ";

    functions.logger.info(`[${WEBHOOK_VERSION}] PayPal webhook received`, {
      eventType,
      uid,
      planId: resource?.plan_id,
      next_billing_time: resource?.billing_info?.next_billing_time,
    });

    switch (eventType) {
      case "BILLING.SUBSCRIPTION.ACTIVATED":
      case "BILLING.SUBSCRIPTION.RE-ACTIVATED":
        // Compute expiry strictly by plan ID to ensure stable durations.
        if (nextBilling) {
          functions.logger.info("Ignoring PayPal next_billing_time in favor of plan-based computation", { nextBilling });
        }

        const computed = new Date();
        if (planId === oneMonthPlanId) {
          computed.setMonth(computed.getMonth() + 1);
        } else if (planId === sixMonthPlanId) {
          computed.setMonth(computed.getMonth() + 6);
        } else if (planId === oneYearPlanId) {
          computed.setFullYear(computed.getFullYear() + 1);
        } else {
          // Default or error case if plan is unknown -> 1 month
          computed.setMonth(computed.getMonth() + 1);
          functions.logger.warn(`Unknown PayPal planId: ${planId}. Defaulting to 1 month.`);
        }
        let derivedExpiry = admin.firestore.Timestamp.fromDate(computed);

        // Never reduce expiry if an existing later expiry is already stored
        try {
          const existingSnap = await userRef.get();
          const existing = existingSnap.data()?.subscription?.expiryDate as FirebaseFirestore.Timestamp | undefined;
          if (existing && existing.toMillis() > derivedExpiry.toMillis()) {
            functions.logger.info(`[${WEBHOOK_VERSION}] Keeping existing later expiry`, {
              existingExpiry: existing.toDate().toISOString(),
              newComputed: derivedExpiry.toDate().toISOString(),
            });
            derivedExpiry = existing;
          }
        } catch (e) {
          functions.logger.warn(`[${WEBHOOK_VERSION}] Failed to read existing expiry before write`, { error: (e as any)?.message });
        }

        const subscriptionData = {
          type: "premium",
          provider: "paypal",
          planId: planId,
          status: "active",
          expiryDate: derivedExpiry,
        };

        functions.logger.info(`[${WEBHOOK_VERSION}] Writing subscription to Firestore`, {
          uid,
          subscriptionData,
        });

        await userRef.set(
          {
            subscription: subscriptionData,
          },
          { merge: true }
        );

        functions.logger.info(`[${WEBHOOK_VERSION}] Successfully wrote to Firestore for user ${uid}.`);
        break;
      case "BILLING.SUBSCRIPTION.PAYMENT.SUCCEEDED":
      case "PAYMENT.SALE.COMPLETED": {
        // Guard: only act if resource includes planId. Some payment events don't include it.
        if (!planId) {
          functions.logger.warn(`[${WEBHOOK_VERSION}] Skipping payment event without planId`, { eventType });
          break;
        }

        const computed = new Date();
        if (planId === oneMonthPlanId) {
          computed.setMonth(computed.getMonth() + 1);
        } else if (planId === sixMonthPlanId) {
          computed.setMonth(computed.getMonth() + 6);
        } else if (planId === oneYearPlanId) {
          computed.setFullYear(computed.getFullYear() + 1);
        } else {
          computed.setMonth(computed.getMonth() + 1);
          functions.logger.warn(`[${WEBHOOK_VERSION}] Unknown planId on payment event; defaulting to 1 month`, { planId });
        }

        let derivedExpiry = admin.firestore.Timestamp.fromDate(computed);

        // Never reduce expiry
        try {
          const existingSnap = await userRef.get();
          const existing = existingSnap.data()?.subscription?.expiryDate as FirebaseFirestore.Timestamp | undefined;
          if (existing && existing.toMillis() > derivedExpiry.toMillis()) {
            functions.logger.info(`[${WEBHOOK_VERSION}] Payment event: keeping existing later expiry`, {
              existingExpiry: existing.toDate().toISOString(),
              newComputed: derivedExpiry.toDate().toISOString(),
            });
            derivedExpiry = existing;
          }
        } catch (e) {
          functions.logger.warn(`[${WEBHOOK_VERSION}] Payment event: failed to read existing expiry`, { error: (e as any)?.message });
        }

        const subscriptionData = {
          type: "premium",
          provider: "paypal",
          planId: planId,
          status: "active",
          expiryDate: derivedExpiry,
        };

        await userRef.set({ subscription: subscriptionData }, { merge: true });
        functions.logger.info(`[${WEBHOOK_VERSION}] Payment event write complete`, { uid });
        break;
      }
      case "BILLING.SUBSCRIPTION.CANCELLED":
      case "BILLING.SUBSCRIPTION.EXPIRED":
        await userRef.set({
          subscription: {
            type: "free",
            provider: "paypal",
            planId,
            expiryDate,
          },
        }, {merge: true});
        break;
      default:
        // ignore other events
        break;
    }

    res.status(200).send("OK");
  } catch (e: any) {
    console.error("paypalWebhook error", e?.message);
    res.status(500).send("Internal Server Error");
  }
});
