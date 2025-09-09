/// RevenueCat configuration placeholders.
/// TODO: Replace with your real RevenueCat API keys and entitlement identifier.

import 'dart:io' show Platform;

class RevenueCatConfig {
  // Put your public SDK keys from RevenueCat dashboard.
  static const String androidSdkKey = 'REVENUECAT_PUBLIC_SDK_KEY_ANDROID';
  static const String iosSdkKey = 'REVENUECAT_PUBLIC_SDK_KEY_IOS';

  // The entitlement identifier you configured in RevenueCat (e.g., "pro" or "premium").
  static const String entitlementId = 'pro';

  static String get currentSdkKey => Platform.isAndroid ? androidSdkKey : iosSdkKey;
}
