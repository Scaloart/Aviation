import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> getUser(String uid) {
    return _db.collection('users').doc(uid);
  }

  Future<void> deleteUser(String uid) {
    return _db.collection('users').doc(uid).delete();
  }

  Future<void> setUserData(String uid, Map<String, dynamic> data) {
    return _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }
}
