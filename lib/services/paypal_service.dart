import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class PaypalService {
  // Singleton instance
  static final PaypalService _instance = PaypalService._internal();

  // Factory constructor to return the singleton instance
  factory PaypalService() {
    return _instance;
  }

  // Private internal constructor
  PaypalService._internal();

  // TODO: Replace with your actual Cloud Function URL
  final String _createSubscriptionUrl =
      'https://us-central1-epl-3-the-brief.cloudfunctions.net/createPaypalSubscription';

  // Maps your UI offer IDs to PayPal Plan IDs
  // TODO: Replace with your actual PayPal Plan IDs
  final Map<String, String> _planIds = {
    'monthly_mock': 'P-9YT393282A868115SNCSSOSQ',
    'six_months_mock': 'P-5NF68931P45223030NCSWB7I',
    'annual_mock': 'P-85A08894HN724960VNCZY5MQ',
  };

  Map<String, String> get offerToPlanId => Map.unmodifiable(_planIds);

  Map<String, String> get planIdToOffer => Map.unmodifiable({
        for (final entry in _planIds.entries) entry.value: entry.key,
      });

  Future<String?> createSubscription(String offerId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to subscribe.');
    }

    final planId = _planIds[offerId];
    if (planId == null) {
      throw Exception('Invalid offer selected.');
    }

    try {
      final response = await http.post(
        Uri.parse(_createSubscriptionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': user.uid,
          'planId': planId,
          // These URLs are placeholders. PayPal uses them to redirect the user.
          // The actual subscription state is handled by your webhook.
          'returnUrl': 'https://example.com/success',
          'cancelUrl': 'https://example.com/cancel',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['approvalUrl'] as String?;
      } else {
        print('Failed to create PayPal subscription: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error calling createSubscription function: $e');
      return null;
    }
  }
}
