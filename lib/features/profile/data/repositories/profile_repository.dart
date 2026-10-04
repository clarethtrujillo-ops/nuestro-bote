import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/user_profile.dart';

class ProfileRepository {
  ProfileRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users {
    return _firestore.collection('users');
  }

  Future<UserProfile?> getProfile(String userId) async {
    final snapshot = await _users.doc(userId).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return UserProfile.fromMap(
      id: snapshot.id,
      map: data,
    );
  }

  Stream<UserProfile?> watchProfile(String userId) {
    return _users.doc(userId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return UserProfile.fromMap(
        id: snapshot.id,
        map: data,
      );
    });
  }

  void _validateDetails(String name, String avatarSeed) {
    final cleanName = name.trim();

    if (cleanName.length < 2 ||
        cleanName.length > 24 ||
        avatarSeed.isEmpty ||
        avatarSeed.length > 100) {
      throw StateError(
        'Escribe un nombre de 2 a 24 caracteres '
        'y selecciona un avatar válido.',
      );
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    _validateDetails(profile.name, profile.avatarSeed);

    final reference = _users.doc(profile.id);

    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(reference);

      final values = <String, dynamic>{
        'name': profile.name.trim(),
        'avatarSeed': profile.avatarSeed,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existing.exists) {
        // Actualiza los datos visibles sin cambiar el bote.
        transaction.update(reference, values);
      } else {
        transaction.set(reference, {
          ...values,
          'coupleId': profile.coupleId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> updateDetails({
    required String userId,
    required String name,
    required String avatarSeed,
  }) async {
    _validateDetails(name, avatarSeed);

    await _users.doc(userId).update({
      'name': name.trim(),
      'avatarSeed': avatarSeed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCoupleId({
    required String userId,
    required String? coupleId,
  }) async {
    await _users.doc(userId).update({
      'coupleId': coupleId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}