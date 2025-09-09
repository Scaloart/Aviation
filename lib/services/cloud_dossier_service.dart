import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:brie_fly/models/dossier_info.dart';
import 'package:brie_fly/services/dossier_service.dart';

class CloudDossierService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final DossierService _local = DossierService();

  CollectionReference<Map<String, dynamic>> _userDossiersCol(String uid) =>
      _firestore.collection('users').doc(uid).collection('dossiers');

  Future<void> uploadDossier({
    required String uid,
    required File file,
    required DossierInfo info,
  }) async {
    final storagePath = 'users/$uid/dossiers/${info.id}.pdf';
    final ref = _storage.ref(storagePath);

    // Upload file
    final Uint8List bytes = await file.readAsBytes();
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/pdf'),
    );

    // Save metadata in Firestore
    await _userDossiersCol(uid).doc(info.id).set({
      'id': info.id,
      'name': info.name,
      'category': info.category,
      'productionDate': info.productionDate.toIso8601String(),
      'storagePath': storagePath,
      'size': bytes.length,
      'departAirportCodes': info.departAirportCodes,
      'arriveeAirportCodes': info.arriveeAirportCodes,
      'enRouteAirportCodes': info.enRouteAirportCodes,
      'selectedOptions': info.selectedOptions,
      'fileName': p.basename(file.path),
      'uploadedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> syncFromCloud({required String uid, bool prune = false}) async {
    // Fetch cloud metadata
    final snap = await _userDossiersCol(uid)
        .orderBy('productionDate', descending: true)
        .get();

    final localList = await _local.listDossiers();
    final localById = {for (final d in localList) d.id: d};

    // Build set of cloud IDs for reconciliation
    final Set<String> cloudIds = {};

    for (final doc in snap.docs) {
      final data = doc.data();
      final id = data['id'] as String? ?? doc.id;
      cloudIds.add(id);
      if (localById.containsKey(id)) continue; // already have locally

      final storagePath = data['storagePath'] as String?;
      if (storagePath == null) continue;

      try {
        final ref = _storage.ref(storagePath);
        final bytes = await ref.getData();
        if (bytes == null) continue;

        final directory = await getApplicationDocumentsDirectory();
        final dossierDir = Directory('${directory.path}/dossiers');
        if (!await dossierDir.exists()) {
          await dossierDir.create(recursive: true);
        }
        final fileName = data['fileName'] as String? ?? '${id}.pdf';
        final file = File(p.join(dossierDir.path, fileName));
        await file.writeAsBytes(bytes, flush: true);

        final info = DossierInfo(
          id: id,
          productionDate: DateTime.tryParse(data['productionDate'] as String? ?? '') ?? DateTime.now(),
          name: (data['name'] as String?) ?? 'Dossier',
          category: (data['category'] as String?) ?? '',
          filePath: file.path,
          departAirportCodes: List<String>.from(data['departAirportCodes'] ?? const []),
          arriveeAirportCodes: List<String>.from(data['arriveeAirportCodes'] ?? const []),
          enRouteAirportCodes: List<String>.from(data['enRouteAirportCodes'] ?? const []),
          selectedOptions: List<String>.from(data['selectedOptions'] ?? const []),
        );
        await _local.saveDossierInfo(info);
      } catch (_) {
        // Ignore one-off failures; continue with others
      }
    }

    // Reconcile (optional): prune local dossiers that are no longer in cloud
    if (prune) {
      try {
        for (final local in localList) {
          if (!cloudIds.contains(local.id)) {
            try {
              await _local.deleteDossier(local);
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
  }

  Future<void> deleteFromCloud({required String uid, required String id}) async {
    final docRef = _userDossiersCol(uid).doc(id);
    final doc = await docRef.get();
    if (doc.exists) {
      final data = doc.data()!;
      final storagePath = data['storagePath'] as String?;
      if (storagePath != null) {
        try {
          await _storage.ref(storagePath).delete();
        } catch (_) {}
      }
      await docRef.delete();
    }
  }
}

