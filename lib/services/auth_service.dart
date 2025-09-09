import 'package:firebase_auth/firebase_auth.dart';
// Using FirebaseAuth's signInWithProvider for Google/Facebook across all platforms.
import 'package:brie_fly/models/user_model.dart';
import 'package:brie_fly/services/firestore_service.dart';
import 'package:brie_fly/services/purchase_service.dart';
import 'package:brie_fly/services/theme_service.dart'; // Import ThemeService
import 'package:rxdart/rxdart.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:brie_fly/services/bookmarks_service.dart';
import 'package:brie_fly/services/exam_storage_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final PurchaseService _purchaseService = PurchaseService();
  final ThemeService _themeService; // Add ThemeService instance
  final Function() onAuthChanged;
  StreamSubscription? _customerInfoSubscription;

  AuthService({
    required this.onAuthChanged,
    required ThemeService themeService,
  }) : _themeService = themeService;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestoreService.setUserData(
        userCredential.user!.uid,
        {
          'name': name,
          'email': email,
          'subscription': {'type': 'free', 'expiryDate': null}
        },
      );
      // ignore: avoid_print
      print('[deleteAccount] Calling onAuthChanged…');
      onAuthChanged();
      // ignore: avoid_print
      print('[deleteAccount] onAuthChanged done.');
      // Cross-device sync: pull then push
      try {
        await BookmarksService().syncFromCloud();
        await ExamStorageService().syncFromCloud();
        await BookmarksService().pushAllToCloud();
        await ExamStorageService().pushAllToCloud();
      } catch (_) {}
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print(e.message);
      return null;
    }
  }

  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      onAuthChanged();
      // Cross-device sync: pull then push
      try {
        await BookmarksService().syncFromCloud();
        await ExamStorageService().syncFromCloud();
        await BookmarksService().pushAllToCloud();
        await ExamStorageService().pushAllToCloud();
      } catch (_) {}
      return credential;
    } on FirebaseAuthException catch (e) {
      print(e.message);
      return null;
    }
  }

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    final UserCredential cred = await _auth.signInWithProvider(provider);
    final user = cred.user;
    if (user != null) {
      // If first login, create a basic user profile in Firestore
      if (cred.additionalUserInfo?.isNewUser == true) {
        await _firestoreService.setUserData(user.uid, {
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'photoURL': user.photoURL,
          'subscription': {'type': 'free', 'expiryDate': null}
        });
      }
      // Start listening for RevenueCat customer info to keep subscription in sync
      _setupPurchaseListener(user.uid);
    }
    onAuthChanged();
    // Cross-device sync: pull then push
    try {
      await BookmarksService().syncFromCloud();
      await ExamStorageService().syncFromCloud();
      await BookmarksService().pushAllToCloud();
      await ExamStorageService().pushAllToCloud();
    } catch (_) {}
  }


  Future<void> signOut() async {
    await _themeService.clearBackground(); // Clear the background on sign out
    await _purchaseService.logout();
    await _auth.signOut();
    onAuthChanged();
  }

  Future<void> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Aucun utilisateur connecté.');
      }
      // ignore: avoid_print
      print('[deleteAccount] Current user uid=${user.uid}, email=${user.email}');

      // Reauthenticate depending on linked providers
      final providers = user.providerData.map((p) => p.providerId).toList();
      // Debug
      // ignore: avoid_print
      print('[deleteAccount] Providers: $providers');
      final hasPassword = providers.contains('password');
      final hasGoogle = providers.contains('google.com');

      if (hasPassword) {
        if (password.isEmpty) {
          throw Exception('Veuillez saisir votre mot de passe.');
        }
        try {
          final cred = EmailAuthProvider.credential(email: user.email!, password: password);
          // ignore: avoid_print
          print('[deleteAccount] Reauth with password…');
          await user.reauthenticateWithCredential(cred).timeout(const Duration(seconds: 8));
          // ignore: avoid_print
          print('[deleteAccount] Reauth OK');
        } on FirebaseAuthException catch (e) {
          switch (e.code) {
            case 'wrong-password':
              throw Exception('Mot de passe incorrect.');
            case 'requires-recent-login':
              throw Exception('Veuillez vous reconnecter et réessayer.');
            case 'user-mismatch':
            case 'user-not-found':
              throw Exception("Utilisateur introuvable.");
            case 'invalid-credential':
              throw Exception('Identifiants invalides.');
            default:
              throw Exception('Erreur d’authentification: ${e.code}');
          }
        } on TimeoutException {
          // Fallback: try signIn to refresh credentials
          // ignore: avoid_print
          print('[deleteAccount] Reauth timeout. Fallback to signIn…');
          try {
            await _auth.signInWithEmailAndPassword(email: user.email!, password: password).timeout(const Duration(seconds: 8));
            // ignore: avoid_print
            print('[deleteAccount] Fallback signIn OK');
          } on FirebaseAuthException catch (e) {
            throw Exception('Échec de la réauthentification (timeout): ${e.code}');
          } on TimeoutException {
            throw Exception('Connexion lente: impossible de réauthentifier (timeout).');
          }
        }
      } else if (hasGoogle) {
        // For Google-only accounts, prompt Google reauth
        try {
          final provider = GoogleAuthProvider();
          // ignore: avoid_print
          print('[deleteAccount] Reauth with Google…');
          await user.reauthenticateWithProvider(provider).timeout(const Duration(seconds: 20));
          // ignore: avoid_print
          print('[deleteAccount] Google reauth OK');
        } on FirebaseAuthException catch (e) {
          throw Exception('Échec de la réauthentification Google: ${e.code}');
        } on TimeoutException {
          throw Exception('Réauthentification Google trop longue.');
        }
      } else {
        // Fallback when provider unknown
        throw Exception('Méthode de connexion non prise en charge pour la suppression.');
      }

      // Delete Firestore profile first (ignore errors so account deletion can proceed)
      try {
        // ignore: avoid_print
        print('[deleteAccount] Deleting Firestore user doc…');
        await _firestoreService.deleteUser(user.uid).timeout(const Duration(seconds: 15));
        // ignore: avoid_print
        print('[deleteAccount] Firestore user doc deleted');
      } catch (e) {
        // ignore: avoid_print
        print('[deleteAccount] Firestore delete error: $e');
      }

      // Delete Firebase user
      // ignore: avoid_print
      print('[deleteAccount] Deleting Firebase user…');
      try {
        await user.delete().timeout(const Duration(seconds: 20));
      } on FirebaseAuthException catch (e) {
        // ignore: avoid_print
        print('[deleteAccount] user.delete FirebaseAuthException code=${e.code}, message=${e.message}');
        rethrow;
      }
      // ignore: avoid_print
      print('[deleteAccount] Firebase user deleted');

      // Local cleanup after deletion
      try { await _themeService.clearBackground(); } catch (_) {}
      try { await _purchaseService.logout(); } catch (_) {}

      onAuthChanged();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user is currently signed in.');
      final cred = EmailAuthProvider.credential(email: user.email!, password: oldPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } catch (e) {
      rethrow;
    }
  }

  void _setupPurchaseListener(String userId) {
    _customerInfoSubscription?.cancel();
    _customerInfoSubscription = _purchaseService.customerInfoStream.listen((CustomerInfo customerInfo) {
      final aLaCarteEntitlement = customerInfo.entitlements.all['a_la_carte'];
      String subscriptionType = 'free';
      DateTime? expiryDate;

      if (aLaCarteEntitlement != null && aLaCarteEntitlement.isActive) {
        customerInfo.entitlements.all.forEach((key, value) {
          if (value.isActive && (expiryDate == null || DateTime.parse(value.expirationDate!).isAfter(expiryDate!))) {
            expiryDate = DateTime.parse(value.expirationDate!);
            subscriptionType = value.productIdentifier;
          }
        });
      }

      _firestoreService.setUserData(userId, {
        'subscription': {
          'type': subscriptionType,
          'expiryDate': expiryDate,
        }
      });
    });
  }
}

