import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:brie_fly/models/app_user.dart';
import 'package:brie_fly/services/auth_service.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/screens/settings_screen.dart';
import 'package:brie_fly/screens/subscription_screen.dart';
import 'package:brie_fly/widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import 'package:brie_fly/auth_wrapper.dart';

class ProfileScreen extends StatefulWidget {
  final AppUser user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthService _authService;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
  }


  @override
  Widget build(BuildContext context) {
    // We use a StreamBuilder to get real-time updates for the user, including the bio
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.user.uid).snapshots(),
      builder: (context, snapshot) {
        // Handle loading and error states
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // Create an AppUser from the latest data
        final updatedUser = AppUser.fromFirestore(snapshot.data!);

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          body: BackgroundContainer(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        // In-body header row below custom window bar
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.of(context).maybePop(),
                              tooltip: 'Retour',
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Mon Profil',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings_outlined, color: Colors.white),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => SettingsScreen(user: updatedUser)),
                              ),
                              tooltip: 'Paramètres',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildProfileHeader(updatedUser),
                        const SizedBox(height: 30),
                        _buildSubscriptionInfo(context, updatedUser),
                      ],
                    ),
                    _buildLogoutButton(context),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildProfileHeader(AppUser user) {
    return Column(
      children: [
        UserAvatar(
          avatarUrl: user.avatarUrl,
          userId: user.uid,
          radius: 50,
        ),
        const SizedBox(height: 20),
        Text(user.name, style: GoogleFonts.montserrat(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(user.email, style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white70)),
      ],
    );
  }

  Widget _buildSubscriptionInfo(BuildContext context, AppUser user) {
    final sub = user.subscription;
    final plan = sub['type'] ?? 'free';
    final provider = sub['provider'] ?? '—';
    final expiry = sub['expiryDate'] as Timestamp?;
    final expiryStr = expiry != null ? DateFormat('dd/MM/yyyy').format(expiry.toDate()) : '—';

    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 24),
              const SizedBox(width: 12),
              Text('Abonnement', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          _buildSubDetailRow('Plan actuel:', _translatePlan(plan).toUpperCase()),
          const SizedBox(height: 8),
          _buildSubDetailRow('Fournisseur:', provider.toUpperCase()),
          const SizedBox(height: 8),
          _buildSubDetailRow('Expire le:', expiryStr),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF50E3C2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Gérer l\'abonnement', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  String _translatePlan(String plan) {
    switch (plan.toLowerCase()) {
      case 'free':
        return 'Gratuit';
      case 'premium':
        return 'Premium';
      default:
        return plan;
    }
  }

  Widget _buildSubDetailRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.montserrat(fontSize: 15, color: Colors.white.withOpacity(0.7))),
        Text(value, style: GoogleFonts.montserrat(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _signingOut
            ? null
            : () async {
                setState(() => _signingOut = true);
                try {
                  await _authService.signOut();
                  if (!mounted) return;
                  // Clear entire stack and route via AuthWrapper so mobile resets properly
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthWrapper()),
                    (route) => false,
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Échec de la déconnexion: $e')),
                  );
                } finally {
                  if (mounted) setState(() => _signingOut = false);
                }
              },
        icon: _signingOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.logout, color: Colors.white),
        label: Text(
          _signingOut ? 'DÉCONNEXION…' : 'DÉCONNEXION',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent.withOpacity(0.8),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5,
          shadowColor: Colors.black.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      ),
      child: child,
    );
  }
}

