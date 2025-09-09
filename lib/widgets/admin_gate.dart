import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminGate extends StatefulWidget {
  final Widget child;
  final Widget? notAdmin;
  const AdminGate({super.key, required this.child, this.notAdmin});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  bool? _isAdmin;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isAdmin = false;
          _loading = false;
        });
        return;
      }
      // Super admin email bypass (convenience)
      final email = user.email?.toLowerCase();
      if (email == 'slw.dwc@gmail.com') {
        setState(() {
          _isAdmin = true;
          _loading = false;
        });
        return;
      }
      final result = await user.getIdTokenResult(true);
      final claims = result.claims ?? {};
      final roles = claims['roles'] as Map<String, dynamic>?;
      setState(() {
        _isAdmin = roles != null && roles['admin'] == true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _isAdmin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Erreur: $_error', style: const TextStyle(color: Colors.redAccent)));
    }
    if (_isAdmin == true) return widget.child;
    if (widget.notAdmin != null) return widget.notAdmin!;
    final email = FirebaseAuth.instance.currentUser?.email ?? '—';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Accès administrateur requis'),
          const SizedBox(height: 8),
          Text('Connecté en tant que: '+email, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _loadClaims,
            child: const Text('Re-vérifier l\'accès'),
          ),
        ],
      ),
    );
  }
}
