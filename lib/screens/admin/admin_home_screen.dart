import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:brie_fly/services/firebase_callable_fallback.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:brie_fly/widgets/background_container.dart';
import 'package:brie_fly/widgets/admin_gate.dart';
import 'manual_payments_admin_screen.dart';
import 'users_admin_screen.dart';
import 'subscriptions_admin_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: BackgroundContainer(
        child: SafeArea(
          child: AdminGate(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final titleSize = isNarrow ? 20.0 : 28.0;
                final horizontalPad = isNarrow ? 12.0 : 24.0;
                final verticalPad = isNarrow ? 12.0 : 16.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalPad),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).maybePop(),
                            tooltip: 'Retour',
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Panneau d\'administration',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: titleSize,
                              ),
                            ),
                          ),
                          // TEMP: Grant-admin button for super email
                          Builder(builder: (context) {
                            final u = FirebaseAuth.instance.currentUser;
                            final email = u?.email?.toLowerCase();
                            if (email != 'slw.dwc@gmail.com') {
                              return SizedBox(width: isNarrow ? 0 : 48);
                            }
                            return Visibility(
                              visible: !isNarrow,
                              replacement: const SizedBox.shrink(),
                              child: Row(children: [
                                TextButton.icon(
                                  onPressed: () async {
                                    try {
                                      final uid = u?.uid;
                                      if (uid == null) return;
                                      await CallableHelper.callAdminSetUserAdminRole(uid: uid, value: true);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Admin claim accordé. Veuillez vous déconnecter/reconnecter.')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.verified_user, color: Colors.white),
                                  label: const Text('Me donner admin', style: TextStyle(color: Colors.white)),
                                ),
                                const SizedBox(width: 8),
                              ]),
                            );
                          }),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8.0 : 16.0),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: isNarrow,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        indicatorColor: Colors.white,
                        tabs: const [
                          Tab(icon: Icon(Icons.receipt_long), text: 'Paiements'),
                          Tab(icon: Icon(Icons.people_alt), text: 'Utilisateurs'),
                          Tab(icon: Icon(Icons.workspace_premium), text: 'Abonnements'),
                        ],
                      ),
                    ),
                    SizedBox(height: isNarrow ? 4 : 8),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: const [
                          AdminManualPaymentsScreen(),
                          AdminUsersScreen(),
                          AdminSubscriptionsScreen(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
