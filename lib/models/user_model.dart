import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final Timestamp createdAt;
  final Map<String, dynamic> subscription;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.createdAt,
    required this.subscription,
  });

  // Factory constructor to create a UserModel from a Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      subscription: data['subscription'] as Map<String, dynamic>? ?? {'type': 'none', 'expiryDate': null},
    );
  }

  // Method to convert UserModel to a map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'createdAt': createdAt,
      'subscription': subscription,
    };
  }
}
