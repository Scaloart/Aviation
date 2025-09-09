import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brie_fly/models/app_user.dart';
import 'package:brie_fly/screens/home_screen.dart';
import 'package:brie_fly/screens/account_screen.dart';
import 'package:brie_fly/services/firestore_service.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const AccountScreen();
        }

        // Block navigation for unverified accounts
        if (!user.emailVerified) {
          return const AccountScreen();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: firestoreService.getUser(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Scaffold(
                body: Center(child: Text('Error loading user data or user does not exist.')),
              );
            }

            final appUser = AppUser.fromFirestore(userSnapshot.data!);
            return HomeScreen(user: appUser);
          },
        );
      },
    );
  }
}

