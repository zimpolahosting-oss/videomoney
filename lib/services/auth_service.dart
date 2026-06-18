import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_service.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    FirestoreService? firestoreService,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestoreService = firestoreService ?? FirestoreService();

  final FirebaseAuth _firebaseAuth;
  final FirestoreService _firestoreService;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    if (credential.user != null) {
      await _firestoreService.createUserProfile(credential.user!);
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'Enter your email address first.',
      );
    }

    await _firebaseAuth.sendPasswordResetEmail(email: normalizedEmail);
  }
}
