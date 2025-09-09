import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:brie_fly/services/firebase_callable_fallback.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Utilisateurs', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 480;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 140),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher par email ou UID',
                      filled: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: isNarrow ? double.infinity : 120,
                  child: ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Rechercher'),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: _queryUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Aucun utilisateur trouvé', style: TextStyle(color: Colors.white70)));
                }
                return LayoutBuilder(builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 480;
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white24),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final data = d.data();
                      final sub = (data['subscription'] as Map<String, dynamic>?) ?? {};
                      final roles = (data['roles'] as Map<String, dynamic>?) ?? {};
                      final docHasFlag = roles.containsKey('admin');
                      final isAdminFromDoc = (roles['admin'] == true);

                      if (docHasFlag) {
                        return _UserCard(
                          uid: d.id,
                          email: (data['email'] as String?) ?? d.id,
                          status: (sub['status'] as String?) ?? '—',
                          planId: (sub['planId'] as String?) ?? '—',
                          isAdmin: isAdminFromDoc,
                          isNarrow: isNarrow,
                          onToggleAdmin: (value) => _toggleAdmin(context, d.id, value),
                          onDelete: () => _confirmDeleteUser(context, d.id, data['email'] as String?),
                        );
                      }

                      // Fallback to callable check if Firestore flag not present yet
                      return FutureBuilder<dynamic>(
                        future: CallableHelper.callFunction('adminGetUserAdminRole', {'uid': d.id}),
                        builder: (context, roleSnap) {
                          final isLoading = roleSnap.connectionState == ConnectionState.waiting;
                          bool isAdmin = false;
                          if (roleSnap.hasData) {
                            final m = roleSnap.data;
                            if (m is Map && m['isAdmin'] is bool) {
                              isAdmin = m['isAdmin'] as bool;
                            } else if (m is Map<String, dynamic> && m['isAdmin'] is bool) {
                              isAdmin = m['isAdmin'] as bool;
                            }
                          }
                          return _UserCard(
                            uid: d.id,
                            email: (data['email'] as String?) ?? d.id,
                            status: (sub['status'] as String?) ?? '—',
                            planId: (sub['planId'] as String?) ?? '—',
                            isAdmin: isAdmin,
                            isNarrow: isNarrow,
                            loading: isLoading,
                            onToggleAdmin: (value) => _toggleAdmin(context, d.id, value),
                            onDelete: () => _confirmDeleteUser(context, d.id, data['email'] as String?),
                          );
                        },
                      );
                    },
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _queryUsers() {
    final q = _searchCtrl.text.trim();
    final col = FirebaseFirestore.instance.collection('users');
    if (q.isEmpty) return col.limit(50).get();
    // naive search over email or id prefix
    return col.where('email', isGreaterThanOrEqualTo: q).where('email', isLessThan: '$q\uf8ff').limit(50).get();
  }

  Future<void> _toggleAdmin(BuildContext context, String uid, bool value) async {
    try {
      await CallableHelper.callAdminSetUserAdminRole(uid: uid, value: value);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value ? 'Admin accordé' : 'Admin retiré')),
        );
        setState(() {});
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _confirmDeleteUser(BuildContext context, String uid, String? email) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous ne pouvez pas supprimer votre propre compte.'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text('Supprimer définitivement l\'utilisateur\n${email ?? uid}?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await CallableHelper.callFunction('adminDeleteUser', {'uid': uid});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur supprimé')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}

class _UserDevices extends StatelessWidget {
  final String uid;
  final bool isNarrow;
  const _UserDevices({required this.uid, required this.isNarrow});

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('devices');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: col.orderBy('lastSeen', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 28, child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))));
        }
        if (snap.hasError) {
          return Text('Devices error: ${snap.error}', style: const TextStyle(color: Colors.redAccent));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text('No devices', style: TextStyle(color: Colors.white54, fontSize: 12));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Devices (${docs.length}/2)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 6),
            ...docs.map((d) {
              final data = d.data();
              final installationId = d.id;
              final platform = (data['platform'] as String?) ?? 'unknown';
              final deviceName = (data['deviceName'] as String?) ?? '';
              final lastSeen = data['lastSeen'];
              String lastSeenStr = '';
              if (lastSeen is Timestamp) {
                lastSeenStr = lastSeen.toDate().toLocal().toString();
              } else if (lastSeen is String) {
                lastSeenStr = lastSeen;
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(deviceName.isEmpty ? installationId : deviceName, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('platform: $platform  •  lastSeen: $lastSeenStr', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Remove device'),
                                content: Text('Remove this device from $uid?\n\nID: $installationId'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
                                ],
                              ),
                            ) ??
                            false;
                        if (!ok) return;
                        try {
                          await CallableHelper.callFunction('adminRemoveDevice', {'uid': uid, 'installationId': installationId});
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device removed')));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                        }
                      },
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final String uid;
  final String email;
  final String status;
  final String planId;
  final bool isAdmin;
  final bool isNarrow;
  final bool loading;
  final void Function(bool newValue) onToggleAdmin;
  final VoidCallback onDelete;

  const _UserCard({
    required this.uid,
    required this.email,
    required this.status,
    required this.planId,
    required this.isAdmin,
    required this.isNarrow,
    required this.onToggleAdmin,
    required this.onDelete,
    this.loading = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = TextStyle(color: Colors.white70, fontSize: isNarrow ? 12 : 14);
    final titleStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: isNarrow ? 14 : 16);

    return Container
        (
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(email, style: titleStyle, overflow: TextOverflow.ellipsis)),
              if (!isNarrow)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: _AdminBadge(isAdmin: isAdmin),
                ),
            ],
          ),
          if (isNarrow) ...[
            const SizedBox(height: 4),
            _AdminBadge(isAdmin: isAdmin),
          ],
          const SizedBox(height: 4),
          Text('status: $status  |  plan: $planId', style: subtitleStyle),
          const SizedBox(height: 8),
          if (loading)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => onToggleAdmin(!isAdmin),
                  child: Text(isAdmin ? 'Remove Admin' : 'Set Admin'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  onPressed: onDelete,
                  child: const Text('Delete'),
                ),
              ],
            ),
          const SizedBox(height: 8),
          _UserDevices(uid: uid, isNarrow: isNarrow),
        ],
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  final bool isAdmin;
  const _AdminBadge({required this.isAdmin});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin ? Colors.green.withOpacity(0.2) : Colors.white12,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isAdmin ? Colors.greenAccent : Colors.white24),
      ),
      child: Text(isAdmin ? 'Admin' : 'User', style: TextStyle(color: isAdmin ? Colors.greenAccent : Colors.white70, fontSize: 12)),
    );
  }
}
