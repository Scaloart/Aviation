import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

// Define an interface for the RevenueCat event for type safety
interface RevenueCatEvent {
  app_user_id: string;
  type: string;
  product_id: string;
  expiration_at_ms?: number;
}

// Initialize Firebase Admin SDK if not already done
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Handles incoming webhooks from RevenueCat.
 */
export const revenuecatWebhook = functions.https.onRequest(async (req, res) => {
  logger.info("Received RevenueCat webhook");

  // TODO: Add webhook signature verification for security.
  const event = req.body.event as RevenueCatEvent;

  if (!event || !event.app_user_id) {
    logger.error("Invalid webhook payload.", {body: req.body});
    res.status(400).send("Bad Request: Missing event or app_user_id");
    return;
  }

  const userId = event.app_user_id;
  const userRef = db.collection("users").doc(userId);

  logger.info(`Processing event: ${event.type} for user: ${userId}`);

  try {
    const subData = mapEventToSubscription(event);

    if (subData) {
      await userRef.set({subscription: subData}, {merge: true});
      logger.info(`Updated subscription for ${userId}`, {subData});
    } else {
      logger.info(`No update needed for event: ${event.type}`);
    }

    res.status(200).send("Webhook processed.");
  } catch (error) {
    logger.error(`Webhook error for ${userId}`, {error, event});
    res.status(500).send("Internal Server Error");
  }
});

/**
 * Maps a RevenueCat event to a Firestore subscription object.
 * @param {RevenueCatEvent} event The RevenueCat event.
 * @return {object | null} A subscription object or null.
 */
function mapEventToSubscription(event: RevenueCatEvent): object | null {
  const expiry = event.expiration_at_ms ?
    admin.firestore.Timestamp.fromMillis(event.expiration_at_ms) :
    null;

  switch (event.type) {
  case "INITIAL_PURCHASE":
  case "RENEWAL":
  case "UNCANCELLATION":
  case "PRODUCT_CHANGE":
    return {
      type: event.product_id,
      expiryDate: expiry,
    };
  case "CANCELLATION":
  case "EXPIRATION":
    return {
      type: "free",
      expiryDate: expiry,
    };
  default:
    return null;
  }
}
