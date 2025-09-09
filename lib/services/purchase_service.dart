import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  static String? _revenueCatApiKey;
  final StreamController<CustomerInfo> _customerInfoController =
      StreamController<CustomerInfo>.broadcast();

  bool get _isPurchasesSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  // TODO: Set your RevenueCat API keys here
  static void setApiKey(String apiKey) {
    _revenueCatApiKey = apiKey;
  }

  Future<void> init() async {
    // Skip initialization on unsupported platforms (e.g., Windows/Web)
    if (!_isPurchasesSupported) {
      // ignore: avoid_print
      print('Purchases SDK not supported on this platform. Skipping init.');
      return;
    }
    if (_revenueCatApiKey == null) {
      // It's better to fetch this from a secure location or a config file
      // For now, please ensure you call setApiKey at app startup.
      print("RevenueCat API Key is not set. Please call setApiKey.");
      return;
    }
    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(PurchasesConfiguration(_revenueCatApiKey!));

    // Emit initial customer info
    try {
      final info = await Purchases.getCustomerInfo();
      _customerInfoController.add(info);
    } catch (e) {
      // ignore: avoid_print
      print('Failed to get initial CustomerInfo: $e');
    }

    // Listen for subsequent updates
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _customerInfoController.add(customerInfo);
    });
  }

  Future<List<Offering>> getOfferings() async {
    if (!_isPurchasesSupported) {
      return [];
    }
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.all.values.toList();
    } on PlatformException catch (e) {
      print("Error fetching offerings: ${e.message}");
      return [];
    }
  }

  Future<bool> purchasePackage(Package package) async {
    if (!_isPurchasesSupported) {
      // Use your external checkout flow on desktop and return false here.
      return false;
    }
    try {
      await Purchases.purchasePackage(package);
      return true;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        print("Error purchasing package: ${e.message}");
      }
      return false;
    }
  }

  Stream<CustomerInfo> get customerInfoStream => _customerInfoController.stream;

  Future<void> login(String appUserID) async {
    if (!_isPurchasesSupported) return;
    await Purchases.logIn(appUserID);
  }

  Future<void> logout() async {
    if (!_isPurchasesSupported) return;
    try {
      // Skip logout if current RC user is anonymous to avoid noisy errors
      bool isAnon = false;
      try {
        // Primary API
        isAnon = await Purchases.isAnonymous;
      } catch (_) {
        // Fallback: infer from originalAppUserId prefix
        try {
          final info = await Purchases.getCustomerInfo();
          final id = info.originalAppUserId;
          if (id != null && id.startsWith(r"$RCAnonymousID:")) {
            isAnon = true;
          }
        } catch (_) {}
      }

      if (isAnon) return;
      await Purchases.logOut();
    } catch (e) {
      // ignore error to keep logout flow smooth
    }
  }

  Future<CustomerInfo?> restorePurchases() async {
    if (!_isPurchasesSupported) return null;
    try {
      final info = await Purchases.restorePurchases();
      _customerInfoController.add(info);
      return info;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _customerInfoController.close();
  }
}
