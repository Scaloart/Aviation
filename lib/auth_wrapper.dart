import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brie_fly/models/app_user.dart';
import 'package:brie_fly/screens/home_screen.dart';
import 'package:brie_fly/screens/account_screen.dart';
import 'package:brie_fly/services/firestore_service.dart';
import 'package:brie_fly/services/bookmarks_service.dart';
import 'package:brie_fly/services/exam_storage_service.dart';
import 'package:provider/provider.dart';
import 'package:brie_fly/services/device_registry_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;
          if (user == null) {
            return const AccountScreen();
          }

          // If the user has not verified their email yet, keep them on AccountScreen
          if (!user.emailVerified) {
            return const AccountScreen();
          }

          // Debug
          // ignore: avoid_print
          print('[AuthWrapper] authState: user=${user.uid} email=${user.email}');

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: firestoreService.getUser(user.uid).snapshots(),
            builder: (context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(child: CircularProgressIndicator(color: Color(0xFFFF1744))),
                );
              }
              if (userSnapshot.hasError) {
                // ignore: avoid_print
                print('[AuthWrapper] Firestore user error: ${userSnapshot.error}');
                return const AccountScreen();
              }
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                // ignore: avoid_print
                print('[AuthWrapper] Firestore user doc missing; routing to AccountScreen');
                return const AccountScreen();
              }

              final appUser = AppUser.fromFirestore(userSnapshot.data!);
              // Enforce 2-device limit before entering the app
              return FutureBuilder<void>(
                future: DeviceRegistryService.ensureRegistered(),
                builder: (context, regSnap) {
                  if (regSnap.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      backgroundColor: Colors.black,
                      body: Center(child: CircularProgressIndicator(color: Color(0xFFFF1744))),
                    );
                  }
                  if (regSnap.hasError) {
                    final err = regSnap.error.toString();
                    return Scaffold(
                      backgroundColor: Colors.black,
                      body: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock, color: Colors.white70, size: 48),
                              const SizedBox(height: 16),
                              const Text('Device not authorized', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              const Text(
                                'Your account is limited to two devices. Please remove an old device and try again.\n\nDetails: ',
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(err, style: const TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () async {
                                  await FirebaseAuth.instance.signOut();
                                },
                                child: const Text('Back to sign in'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return HomeScreen(user: appUser);
                },
              );
            },
          );
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

