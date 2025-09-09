import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:brie_fly/services/paypal_service.dart';

/// Central gate to decide whether ads should be shown.
/// Policy: show ads for everyone EXCEPT users with an active ANNUAL subscription.
class AdsGate {
  AdsGate._();

  static const bool _enableLog = true; // flip to false to silence
  static void _log(String message) {
    if (_enableLog) debugPrint('[AdsGate] ' + message);
  }

  /// Returns true if ads should be shown.
  static Future<bool> shouldShowAds() async {
    // Web: now honors Firestore + manual payments as well
    if (kIsWeb) {
      _log('Platform: Web');
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          _log('No user -> show ads');
          return true;
        }
        final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = snap.data();
        final Map<String, dynamic> sub = (data?['subscription'] as Map<String, dynamic>?) ?? {};
        final String? status = sub['status'] as String?; // expected 'active'
        final String? type = sub['type'] as String?; // expected 'premium'
        final String? planId = sub['planId'] as String?; // may be BANK_TRANSFER_ANNUAL, etc.
        final Timestamp? expiryTs = sub['expiryDate'] as Timestamp?;
        _log('Sub(web): status=' + (status?.toString() ?? 'null') + ', type=' + (type?.toString() ?? 'null') + ', planId=' + (planId?.toString() ?? 'null') + ', expiryTs=' + (expiryTs?.toDate().toIso8601String() ?? 'null'));

        final bool expired = expiryTs != null && expiryTs.toDate().isBefore(DateTime.now());
        if (!expired) {
          final bool isAnnual = _isAnnualKeyword(planId ?? '');
          final bool active = (type == 'premium' && status == 'active');
          if (active && isAnnual) {
            _log('Web -> active manual annual -> no ads');
            return false; // no ads
          }
        }

        // Manual payments fallback
        final q = await FirebaseFirestore.instance
            .collection('manual_payments')
            .where('uid', isEqualTo: user.uid)
            .where('status', isEqualTo: 'approved')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          final d = q.docs.first.data();
          final int months = (d['durationMonths'] as int?) ?? 0;
          final Timestamp? createdAt = d['createdAt'] as Timestamp?;
          if (months > 0 && createdAt != null) {
            final expiry = createdAt.toDate().add(Duration(days: 30 * months));
            final bool manualActive = expiry.isAfter(DateTime.now());
            final bool manualAnnual = months >= 12;
            if (manualActive && manualAnnual) {
              _log('Web -> manual payments annual active -> no ads');
              return false;
            }
          }
        }
      } catch (_) {}
      _log('Web -> default show ads');
      return true;
    }

    // Platforms where RevenueCat is supported: Android, iOS, macOS
    final bool purchasesSupported = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

    try {
      if (purchasesSupported) {
        _log('Platform: Mobile/macOS');
        try {
          final info = await rc.Purchases.getCustomerInfo();
          // Prefer explicit entitlements if configured
          final activeEntitlements = info.entitlements.active.values.map((e) => e.identifier.toLowerCase()).toList();
          final hasAnnualEntitlement = activeEntitlements.any((id) => _isAnnualKeyword(id));
          _log('RC entitlements=' + activeEntitlements.join(','));
          if (hasAnnualEntitlement) { _log('RC annual entitlement -> no ads'); return false; }

          // Fallback: check product identifiers of active subscriptions/purchases
          final activeProductIds = <String>{
            ...info.activeSubscriptions.map((e) => e.toLowerCase()),
            ...info.allPurchasedProductIdentifiers.map((e) => e.toLowerCase()),
          };
          final hasAnnualProduct = activeProductIds.any((id) => _isAnnualKeyword(id));
          _log('RC productIds=' + activeProductIds.join(','));
          if (hasAnnualProduct) { _log('RC annual product -> no ads'); return false; }
        } catch (_) {}

        // Additional fallback for users who paid via PayPal/manual but run the app on mobile/macOS
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
            final data = snap.data();
            final Map<String, dynamic> sub = (data?['subscription'] as Map<String, dynamic>?) ?? {};
            final String? status = sub['status'] as String?; // expected 'active'
            final String? type = sub['type'] as String?; // expected 'premium'
            final String? planId = sub['planId'] as String?; // PayPal plan ID
            final Timestamp? expiryTs = sub['expiryDate'] as Timestamp?;
            _log('Sub(mobile): status=' + (status?.toString() ?? 'null') + ', type=' + (type?.toString() ?? 'null') + ', planId=' + (planId?.toString() ?? 'null') + ', expiryTs=' + (expiryTs?.toDate().toIso8601String() ?? 'null'));

            // Map planId to offerId, detect annual (also accept planId keywords)
            String? offerId;
            try { offerId = PaypalService().planIdToOffer[planId]; } catch (_) {}
            final bool isAnnualPlan = _isAnnualKeyword(offerId ?? planId ?? '');

            // If expiryDate exists and is past -> show ads; if active and annual -> no ads
            final bool expired = expiryTs != null && expiryTs.toDate().isBefore(DateTime.now());
            if (!expired) {
              final bool active = (type == 'premium' && status == 'active') || (isAnnualPlan && status == null && expiryTs == null);
              if (active && isAnnualPlan) { _log('Mobile -> manual/PayPal annual active -> no ads'); return false; }
            }

            // Manual payments fallback
            final q = await FirebaseFirestore.instance
                .collection('manual_payments')
                .where('uid', isEqualTo: user.uid)
                .where('status', isEqualTo: 'approved')
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get();
            if (q.docs.isNotEmpty) {
              final d = q.docs.first.data();
              final int months = (d['durationMonths'] as int?) ?? 0;
              final Timestamp? createdAt = d['createdAt'] as Timestamp?;
              if (months > 0 && createdAt != null) {
                final expiry = createdAt.toDate().add(Duration(days: 30 * months));
                final bool manualActive = expiry.isAfter(DateTime.now());
                final bool manualAnnual = months >= 12;
                if (manualActive && manualAnnual) { _log('Mobile -> manual payments annual active -> no ads'); return false; }
              }
            }
          }
        } catch (_) {}

        // If not annual by any method, show ads
        _log('Mobile -> default show ads');
        return true;
      }

      // Desktop Windows/Linux: derive from Firestore (PayPal manual subs)
      if (Platform.isWindows || Platform.isLinux) {
        _log('Platform: Windows/Linux');
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) { _log('No user -> show ads'); return true; } // not logged in -> show ads
        try {
          final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final data = snap.data();
          final Map<String, dynamic> sub = (data?['subscription'] as Map<String, dynamic>?) ?? {};
          final String? status = sub['status'] as String?; // expected 'active'
          final String? type = sub['type'] as String?; // expected 'premium'
          final String? planId = sub['planId'] as String?; // PayPal plan ID
          final Timestamp? expiryTs = sub['expiryDate'] as Timestamp?;
          _log('Sub(desktop): status=' + (status?.toString() ?? 'null') + ', type=' + (type?.toString() ?? 'null') + ', planId=' + (planId?.toString() ?? 'null') + ', expiryTs=' + (expiryTs?.toDate().toIso8601String() ?? 'null'));

          // Annual-only exemption: map planId -> offerId via PaypalService, then detect annual (or via planId keywords)
          String? offerId;
          try {
            offerId = PaypalService().planIdToOffer[planId];
          } catch (_) {}
          final bool isAnnual = _isAnnualKeyword(offerId ?? planId ?? '');

          // Determine activity:
          // - If expiryDate exists and is in the past -> treat as inactive regardless of planId.
          // - Else if status/type indicate active -> active.
          // - Else if annual planId is present but status/expiry missing -> treat as active for ad gating.
          final bool expired = expiryTs != null && expiryTs.toDate().isBefore(DateTime.now());
          if (expired) { _log('Desktop -> expired -> show ads'); return true; } // expired -> show ads

          bool active = (type == 'premium' && status == 'active');
          if (!active && isAnnual && (status == null && expiryTs == null)) {
            active = true; // provisional active based on annual plan mapping
          }

          if (!active) {
            // Check manual payment approvals fallback: latest approved receipt
            try {
              final q = await FirebaseFirestore.instance
                  .collection('manual_payments')
                  .where('uid', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'approved')
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .get();
              if (q.docs.isNotEmpty) {
                final d = q.docs.first.data();
                final int months = (d['durationMonths'] as int?) ?? 0;
                final Timestamp? createdAt = d['createdAt'] as Timestamp?;
                if (months > 0 && createdAt != null) {
                  final expiry = createdAt.toDate().add(Duration(days: 30 * months));
                  final bool manualActive = expiry.isAfter(DateTime.now());
                  final bool manualAnnual = months >= 12; // treat 12+ months as annual
                  if (manualActive && manualAnnual) { _log('Desktop -> manual payments annual active -> no ads'); return false; }
                }
              }
            } catch (_) {}
            _log('Desktop -> not active by any means -> show ads');
            return true; // not active by any means -> show ads
          }

          final res = !isAnnual;
          _log('Desktop -> active=' + active.toString() + ', isAnnual=' + isAnnual.toString() + ' -> showAds=' + res.toString());
          return res; // active and annual -> no ads; other plans -> show ads
        } catch (_) {
          _log('Desktop -> error -> show ads');
          return true; // on error, default to showing ads
        }
      }

      // Other platforms: default to showing ads
      _log('Other platform -> show ads');
      return true;
    } catch (_) {
      _log('Global error -> show ads');
      return true;
    }
  }

  static bool _isAnnualKeyword(String s) {
    final v = s.toLowerCase();
    return v.contains('annual') || v.contains('year') || v.contains('yearly') || v.contains('annuel');
  }
}
