import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/models/subscription_offer.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/widgets/subscription_card.dart';
import 'package:provider/provider.dart';
import 'package:brie_fly/services/purchase_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:brie_fly/services/paypal_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brie_fly/screens/paypal_webview_screen.dart';
import 'package:brie_fly/screens/manual_payment_screen.dart';
import 'package:brie_fly/screens/admin/admin_home_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionOffer? _selectedOffer;
  late Future<List<SubscriptionOffer>> _offersFuture;
  List<rc.Package> _originalPackages = []; // To hold RevenueCat packages
  final PaypalService _paypalService = PaypalService();
  bool _isProcessingPayment = false;
  String? _boughtOfferId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubListener;
  Timer? _pollTimer; // Windows polling workaround

  @override
  void initState() {
    super.initState();
    _offersFuture = _getOffers();

    // On Windows/desktop, listen to Firestore for subscription changes and update badge live
    if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      // Windows/Linux: avoid Firestore snapshots due to platform channel thread error.
      // Poll document periodically from main isolate instead.
      _startPollingSubscription();
    }
  }

  @override
  void dispose() {
    _userSubListener?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  bool get _isPlatformSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<List<SubscriptionOffer>> _getOffers() async {
    // For phones (Android/iOS): show static offers only (no payment wiring for now)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _originalPackages = [];
      return [
        SubscriptionOffer(
          id: 'monthly_mobile',
          title: 'Mensuel',
          price: '50 MAD/mois',
          features: [
            'Accès complet à toutes les fonctionnalités',
            'Support standard'
          ],
          isRecommended: false,
        ),
        SubscriptionOffer(
          id: 'six_months_mobile',
          title: '6 Mois',
          price: '100 MAD/6 mois',
          features: [
            'Accès complet à toutes les fonctionnalités',
            'Support par email',
            'Économisez plus de 65%'
          ],
          isRecommended: false,
        ),
        SubscriptionOffer(
          id: 'annual_mobile',
          title: 'Annuel',
          price: '200 MAD/an',
          features: [
            'Accès complet à toutes les fonctionnalités',
            'Aucune annonce diffusée',
            'Économisez 75%'
          ],
          isRecommended: true,
        ),
      ];
    } else if (_isPlatformSupported) {
      // Fetch from RevenueCat for supported non-phone platforms (e.g., macOS)
      final purchaseService = Provider.of<PurchaseService>(context, listen: false);
      final offerings = await purchaseService.getOfferings();
      final packages = offerings.expand((offering) => offering.availablePackages).toList();

      _originalPackages = packages;

      return packages.map((package) {
        final product = package.storeProduct;
        return SubscriptionOffer(
          id: product.identifier,
          title: product.title,
          price: product.priceString,
          features: product.identifier.contains('monthly')
              ? ['Accès complet à toutes les fonctionnalités', 'Support par email 24/7']
              : [
                  'Accès complet à toutes les fonctionnalités',
                  'Support prioritaire',
                  'Économisez 25%'
                ],
          isRecommended: product.identifier.contains('annual'),
        );
      }).toList();
    } else {
      // Windows: derive purchased offer from Firestore (PayPal)
      // Reset marker by default; it will be set only if an active, non-expired subscription exists
      _boughtOfferId = null;
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _refreshBoughtFromFirestore(user.uid);
        } else {
          _boughtOfferId = null;
        }
      } catch (_) {
        // On error, avoid showing purchased badge erroneously
        _boughtOfferId = null;
      }

      // Return mock data for Windows/Unsupported platforms
      return [
        SubscriptionOffer(
          id: 'monthly_mock',
          title: 'Mensuel',
          price: '50 MAD/mois',
          features: [
            'Accès complet à toutes les fonctionnalités',
            'Support standard'
          ],
          isRecommended: false,
        ),
        SubscriptionOffer(
          id: 'six_months_mock',
          title: '6 Mois',
          price: '100 MAD/6 mois',
          features: [
            'Accès complet à toutes les fonctionnalités',
            'Support par email',
            'Économisez plus de 65%'
          ],
          isRecommended: false,
        ),
        SubscriptionOffer(
          id: 'annual_mock',
          title: 'Annuel',
          price: '200 MAD/an',
          features: [
            'Accès complet à toutes les fonctionnalités',
            'Aucune annonce diffusée',
            'Économisez 75%'
          ],
          isRecommended: true,
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: BackgroundContainer(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Retour',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Nos Offres',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                    // Admin nav button (only for specific admin email)
                    Builder(
                      builder: (context) {
                        final email = FirebaseAuth.instance.currentUser?.email ?? '';
                        if (email.toLowerCase() != 'slw.dwc@gmail.com') {
                          return const SizedBox(width: 48);
                        }
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: 'Admin',
                              child: IconButton(
                                icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildContent(),
              ],
            ),
          ),
        ),
      ),
      // Show purchase options. On Windows/Linux, offer PayPal or Virement Bancaire.
      bottomNavigationBar: _selectedOffer != null
          ? SafeArea(
              top: false,
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                height: (!kIsWeb && !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) ? 140 : 88,
                child: (!kIsWeb && !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS))
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 56,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isProcessingPayment ? null : _handlePurchase, // PayPal
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF50E3C2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 8,
                                shadowColor: Colors.black.withOpacity(0.4),
                              ),
                              child: DefaultTextStyle(
                                style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isProcessingPayment)
                                      const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
                                    if (_isProcessingPayment) const SizedBox(width: 10),
                                    const Text('Payer avec PayPal'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 56,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_selectedOffer == null) return;
                                final months = _monthsForOffer(_selectedOffer!);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ManualPaymentScreen(
                                      months: months,
                                      priceLabel: _selectedOffer!.price,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 8,
                                shadowColor: Colors.black.withOpacity(0.4),
                              ),
                              child: Text(
                                'Virement Bancaire (Téléverser une preuve)',
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: SizedBox(
                          height: 64,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (Platform.isAndroid || Platform.isIOS)
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                      content: Text('Le paiement mobile sera ajouté prochainement.'),
                                      backgroundColor: Colors.amber,
                                    ));
                                  }
                                : _handlePurchase,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF50E3C2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 8,
                              shadowColor: Colors.black.withOpacity(0.4),
                            ),
                            child: DefaultTextStyle(
                              style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isProcessingPayment)
                                    const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                                    ),
                                  if (_isProcessingPayment) const SizedBox(width: 12),
                                  Text(_isProcessingPayment ? 'Traitement…' : 'Confirmer et payer'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            )
          : null,
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        Text(
          'Choisissez votre plan',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Accédez à toutes les fonctionnalités et devenez un pilote plus sûr.',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 16,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 40),
        _buildOfferList(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildOfferList() {
    return FutureBuilder<List<SubscriptionOffer>>(
      future: _offersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Erreur: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text('Aucune offre disponible.',
                  style: TextStyle(color: Colors.white)));
        }

        final offers = snapshot.data!;

        return ListView.separated(
          itemCount: offers.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (context, index) => const SizedBox(height: 24),
          itemBuilder: (context, index) {
            final offer = offers[index];

            return SubscriptionCard(
              title: offer.title,
              price: offer.price,
              features: offer.features,
              isSelected: _selectedOffer?.id == offer.id,
              isRecommended: offer.isRecommended,
              isBought: _boughtOfferId == offer.id,
              onSelected: () => setState(() => _selectedOffer = offer),
            );
          },
        );
      },
    );
  }

  // --- Windows/Linux helpers: polling subscription to avoid snapshots thread issue ---
  void _startPollingSubscription() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Initial fetch
    _refreshBoughtFromFirestore(user.uid);
    // Poll periodically
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshBoughtFromFirestore(user.uid);
    });
  }

  Future<void> _refreshBoughtFromFirestore(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data();
      final sub = (data?['subscription'] as Map<String, dynamic>?) ?? {};
      final String? status = sub['status'] as String?;
      final String? type = sub['type'] as String?;
      final String? planId = sub['planId'] as String?;
      final Timestamp? expiryTs = sub['expiryDate'] as Timestamp?;

      bool isActive = (type == 'premium') && status == 'active';
      if (isActive && expiryTs != null) {
        isActive = expiryTs.toDate().isAfter(DateTime.now());
      }

      String? newBought;
      if (isActive && planId != null) {
        newBought = _paypalService.planIdToOffer[planId];
      }

      if (mounted) {
        setState(() {
          _boughtOfferId = newBought; // null hides the ACHETÉ badge
        });
      }
    } catch (_) {
      // ignore polling errors
    }
  }

  Future<void> _handlePurchase() async {
    if (_selectedOffer == null || _isProcessingPayment) return;

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      if (_isPlatformSupported) {
        // RevenueCat flow for mobile
        final packageToPurchase = _originalPackages.firstWhere(
          (p) => p.storeProduct.identifier == _selectedOffer!.id,
          orElse: () => throw Exception('Selected offer not found'),
        );
        final purchaseService = Provider.of<PurchaseService>(context, listen: false);
        final isSuccess = await purchaseService.purchasePackage(packageToPurchase);

        if (isSuccess && mounted) {
          setState(() {
            _boughtOfferId = _selectedOffer!.id;
          });
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Achat non complété.'),
            backgroundColor: Colors.redAccent,
          ));
        }
      } else {
        // PayPal flow for Windows/desktop (embedded WebView)
        final approvalUrl = await _paypalService.createSubscription(_selectedOffer!.id);
        if (approvalUrl != null && mounted) {
          // Must match the returnUrl/cancelUrl used in PaypalService
          const successUrl = 'https://example.com/success';
          const cancelUrl = 'https://example.com/cancel';

          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => PaypalWebViewScreen(
                approvalUrl: approvalUrl,
                successUrl: successUrl,
                cancelUrl: cancelUrl,
              ),
            ),
          );

          if (mounted) {
            if (result == true) {
              // Mark as bought immediately and write provisional subscription so UI reflects instantly
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final planId = _paypalService.offerToPlanId[_selectedOffer!.id];
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                    'subscription': {
                      'type': 'premium',
                      'provider': 'paypal',
                      'planId': planId,
                    }
                  }, SetOptions(merge: true));
                }
              } catch (_) {}

              setState(() {
                _boughtOfferId = _selectedOffer!.id;
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Paiement réussi !'),
                backgroundColor: Colors.green,
              ));
              // Navigate to home
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else if (result == false) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Paiement annulé.'),
                backgroundColor: Colors.amber,
              ));
            }
          }
        } else {
          throw Exception('Failed to create PayPal subscription.');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  // Determine months for selected offer by id/title
  int _monthsForOffer(SubscriptionOffer offer) {
    final id = offer.id.toLowerCase();
    final title = offer.title.toLowerCase();
    if (id.contains('annual') || title.contains('annuel') || title.contains('an')) {
      return 12;
    }
    if (id.contains('six') || title.contains('6')) {
      return 6;
    }
    return 1; // default to monthly
  }

}
