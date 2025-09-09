import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? avatarUrl;
  final Map<String, dynamic> subscription;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.subscription,
  });

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppUser(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      avatarUrl: data['avatarUrl'],
      // Ensure subscription is never null and defaults to 'free'
      subscription: (data['subscription'] as Map<String, dynamic>?) ?? {'type': 'free'},
    );
  }

  bool get isSubscribed => subscription['type'] != 'free';
}
