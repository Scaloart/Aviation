import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:brie_fly/services/purchase_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _loading = true;
  List<Offering> _offerings = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = context.read<PurchaseService>();
      final offerings = await service.getOfferings();
      if (!mounted) return;
      setState(() {
        _offerings = offerings;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load products';
        _loading = false;
      });
    }
  }

  Future<void> _purchase(Package package) async {
    final service = context.read<PurchaseService>();
    setState(() => _loading = true);
    final ok = await service.purchasePackage(package);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      if (mounted) Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase not completed')),
      );
    }
  }

  Future<void> _restore() async {
    final service = context.read<PurchaseService>();
    setState(() => _loading = true);
    await service.restorePurchases();
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bool mobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Unlock all features',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Subscribe to access all modules and updates. You can cancel anytime in your store settings.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (_offerings.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(mobile
                            ? 'No products available. Ensure products are configured in RevenueCat/Play Console.'
                            : 'Purchases not available on this platform.'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: _offerings
                            .expand((o) => o.availablePackages)
                            .map((pkg) => Card(
                                  child: ListTile(
                                    title: Text(pkg.storeProduct.title),
                                    subtitle: Text(pkg.storeProduct.description),
                                    trailing: Text(pkg.storeProduct.priceString),
                                    onTap: () => _purchase(pkg),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(onPressed: _restore, child: const Text('Restore')),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Not now'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
