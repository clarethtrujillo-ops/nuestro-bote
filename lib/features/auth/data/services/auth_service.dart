import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  User? get currentUser => _firebaseAuth.currentUser;

  String? get currentUserId => currentUser?.uid;

  Stream<User?> get authStateChanges {
    return _firebaseAuth.authStateChanges();
  }

  Future<User> ensureAuthenticated() async {
    final existingUser = _firebaseAuth.currentUser;

    if (existingUser != null) {
      return existingUser;
    }

    final credential = await _firebaseAuth.signInAnonymously();
    final user = credential.user;

    if (user == null) {
      throw StateError(
        'Firebase no pudo crear el usuario anónimo.',
      );
    }

    return user;
  }
}