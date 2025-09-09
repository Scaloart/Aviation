import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:brie_fly/services/firebase_callable_fallback.dart';
import 'package:flutter/material.dart';
import 'package:brie_fly/screens/admin/proof_preview_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminManualPaymentsScreen extends StatelessWidget {
  const AdminManualPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Paiements manuels', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('manual_payments')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

  Widget _emailCell(String uid) {
    if (uid.isEmpty) return const Text('');
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(width: 80, height: 16, child: LinearProgressIndicator(minHeight: 2));
        }
        if (!snap.hasData || !snap.data!.exists) return const Text('');
        final email = snap.data!.data()?['email'] as String?;
        return Text(email ?? '');
      },
    );
  }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Aucun paiement trouvé', style: TextStyle(color: Colors.white70)));
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('UID')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Durée(mois)')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Créé le')),
                      DataColumn(label: Text('Preuve')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: docs.map((d) {
                      final data = d.data();
                      return DataRow(cells: [
                        DataCell(SelectableText(d.id)),
                        DataCell(SelectableText(data['uid'] ?? '')),
                        DataCell(_emailCell(data['uid'] ?? '')),
                        DataCell(Text('${data['durationMonths'] ?? ''}')),
                        DataCell(Text('${data['status'] ?? ''}')),
                        DataCell(Text('${(data['createdAt'] as Timestamp?)?.toDate()}')),
                        DataCell(
                          TextButton(
                            onPressed: data['proofUrl'] != null ? () => _openUrl(context, data['proofUrl']) : null,
                            child: const Text('Ouvrir'),
                          ),
                        ),
                        DataCell(Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => _approve(context, d.id, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade400, foregroundColor: Colors.black),
                              child: const Text('Approuver'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _approve(context, d.id, false),
                              child: const Text('Refuser'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _remove(context, d.id),
                              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                              label: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                              ),
                            ),
                          ],
                        )),
                      ]);
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openUrl(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProofPreviewScreen(url: url, title: 'Preuve de paiement'),
      ),
    );
  }

  Future<void> _remove(BuildContext context, String paymentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Supprimer le paiement ?'),
          content: const Text('Cette action est définitive. Voulez-vous vraiment supprimer cet enregistrement ?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent))),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('manual_payments').doc(paymentId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paiement supprimé')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _approve(BuildContext context, String paymentId, bool approved) async {
    try {
      await CallableHelper.callFunction('adminApproveManualPayment', {
        'paymentId': paymentId,
        'approved': approved,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approved ? 'Approuvé' : 'Refusé')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}
