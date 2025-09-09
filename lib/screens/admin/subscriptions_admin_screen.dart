import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:brie_fly/services/firebase_callable_fallback.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminSubscriptionsScreen extends StatelessWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Abonnements', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').limit(100).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Aucun utilisateur', style: TextStyle(color: Colors.white70)));
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('UID')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Provider')),
                      DataColumn(label: Text('PlanId')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Expiry')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: docs.map((d) {
                      final data = d.data();
                      final sub = (data['subscription'] as Map<String, dynamic>?) ?? {};
                      return DataRow(cells: [
                        DataCell(SelectableText(d.id)),
                        DataCell(Text('${data['email'] ?? ''}')),
                        DataCell(Text('${sub['type'] ?? ''}')),
                        DataCell(Text('${sub['provider'] ?? ''}')),
                        DataCell(Text('${sub['planId'] ?? ''}')),
                        DataCell(Text('${sub['status'] ?? ''}')),
                        DataCell(Text('${(sub['expiryDate'] as Timestamp?)?.toDate()}')),
                        DataCell(Row(children: [
                          OutlinedButton(onPressed: () => _adjust(context, d.id, 'extend'), child: const Text('Étendre +1m')),
                          const SizedBox(width: 8),
                          OutlinedButton(onPressed: () => _adjust(context, d.id, 'cancel'), child: const Text('Annuler')),
                        ])),
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

  Future<void> _adjust(BuildContext context, String uid, String action) async {
    try {
      await CallableHelper.callFunction('adminAdjustSubscription', {
        'uid': uid,
        'action': action,
        if (action == 'extend') 'months': 1,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action "$action" effectuée')),
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
