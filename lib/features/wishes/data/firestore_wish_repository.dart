import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/models/wish.dart';

class FirestoreWishRepository {
  FirestoreWishRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _collection(String coupleId) {
    if (coupleId.trim().isEmpty) {
      throw StateError('No encontramos el identificador del bote.');
    }

    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('wishes');
  }

  String _currentUserId() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Tu sesión terminó. Vuelve a entrar.');
    }

    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _reference(
    String coupleId,
    Wish wish,
  ) {
    final id = wish.id;

    if (id == null || id.isEmpty) {
      throw StateError('Este deseo todavía no está guardado.');
    }

    return _collection(coupleId).doc(id);
  }

  Stream<List<Wish>> watchWishes(String coupleId) {
    return _collection(coupleId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => _fromDocument(document))
              .toList(growable: false),
        );
  }

  Stream<Wish?> watchWish(String coupleId, String wishId) {
    return _collection(coupleId).doc(wishId).snapshots().map(
          (document) =>
              document.exists ? _fromDocument(document) : null,
        );
  }

    Future<void> createWish({
    required String coupleId,
    required Wish wish,
    required String authorName,
  }) async {
    final userId = _currentUserId();
    _validateContent(wish);

    final profileSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .get(const GetOptions(source: Source.server));

    final profileData = profileSnapshot.data();
    final storedName = profileData?['name'];

    if (!profileSnapshot.exists ||
        storedName is! String ||
        storedName.trim().isEmpty) {
      throw StateError(
        'No encontramos tu nombre. Revisa tu perfil antes de guardar.',
      );
    }

    // Usa el nombre actual de Firestore, como exigen las reglas.
    final reference = _collection(coupleId).doc();

    await reference.set({
      'description': wish.description.trim(),
      'category': wish.category.name,
      'dueDate': Timestamp.fromDate(wish.dueDate),
      'note': _normalizeNote(wish.note),
      'proposedBy': storedName,
      'proposedByUserId': userId,
      'readyUserIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'completedAt': null,
      'completedByUserId': null,
      'completedByName': null,
    });
  }

  Future<void> updateWish({
    required String coupleId,
    required Wish original,
    required Wish edited,
  }) async {
    _currentUserId();
    _validateContent(edited);

    final reference = _reference(coupleId, original);

    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      final current = _existingWish(snapshot);

      if (current.isCompleted) {
        throw StateError('Este deseo ya fue cumplido y no se puede editar.');
      }

      // Evita reemplazar una edición que la pareja hizo
      // mientras este formulario estaba abierto.
      if (!_sameContent(current, original)) {
        throw StateError(
          'Tu pareja modificó este deseo. '
          'Vuelve a abrir la edición para usar los datos actualizados.',
        );
      }

      if (_sameContent(current, edited)) return;

      transaction.update(reference, {
        'description': edited.description.trim(),
        'category': edited.category.name,
        'dueDate': Timestamp.fromDate(edited.dueDate),
        'note': _normalizeNote(edited.note),
        'readyUserIds': <String>[],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> toggleReady({
    required String coupleId,
    required Wish wish,
  }) async {
    final userId = _currentUserId();
    final reference = _reference(coupleId, wish);

    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      final current = _existingWish(snapshot);

      if (current.isCompleted) {
        throw StateError('Este deseo ya fue cumplido.');
      }

      final readyIds = current.readyUserIds.toSet();

      if (!readyIds.add(userId)) {
        readyIds.remove(userId);
      }

      transaction.update(reference, {
        'readyUserIds': readyIds.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<Wish> completeWish({
    required String coupleId,
    required Wish wish,
    required String completedByName,
  }) async {
    final userId = _currentUserId();
    final reference = _reference(coupleId, wish);
    final name = completedByName.trim();

    if (name.isEmpty) {
      throw StateError('No encontramos tu nombre.');
    }

    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      final current = _existingWish(snapshot);

      // Si ambos pulsan el botón, conserva el primer registro.
      if (current.isCompleted) return;

      transaction.update(reference, {
        'completedAt': FieldValue.serverTimestamp(),
        'completedByUserId': userId,
        'completedByName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );

    return _existingWish(snapshot);
  }

  Future<void> deleteWish({
    required String coupleId,
    required Wish wish,
  }) async {
    _currentUserId();
    final reference = _reference(coupleId, wish);

    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);

      // Si la pareja ya lo eliminó, la acción está resuelta.
      if (!snapshot.exists) return;

      final current = _fromDocument(snapshot);

      if (current.isCompleted) {
        throw StateError(
          'Los deseos cumplidos se conservan en el historial.',
        );
      }

      transaction.delete(reference);
    });
  }

  Wish _existingWish(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) {
      throw StateError('Este deseo ya no existe.');
    }

    return _fromDocument(snapshot);
  }

  Wish _fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('No pudimos leer el deseo.');
    }

    final categoryName = data['category'];

    final category = switch (categoryName) {
      'plan' => WishCategory.plan,
      'experience' => WishCategory.experience,
      'detail' => WishCategory.detail,
      _ => throw StateError('El deseo tiene una categoría inválida.'),
    };

    final dueDate = data['dueDate'];
    final completedAt = data['completedAt'];
    final createdAt = data['createdAt'];

    if (dueDate is! Timestamp) {
      throw StateError('El deseo no tiene una fecha válida.');
    }

    // Un timestamp de servidor puede ser nulo durante
    // una escritura local que todavía no se ha confirmado.
    final creationDate = createdAt is Timestamp
        ? createdAt.toDate()
        : DateTime.now();

    final rawReadyIds = data['readyUserIds'];

    return Wish(
      id: document.id,
      description: data['description'] as String,
      category: category,
      dueDate: dueDate.toDate(),
      proposedBy: data['proposedBy'] as String,
      proposedByUserId: data['proposedByUserId'] as String,
      createdAt: creationDate,
      note: data['note'] as String?,
      readyUserIds: List<String>.unmodifiable(
        rawReadyIds is List
            ? rawReadyIds.cast<String>()
            : const <String>[],
      ),
      completedAt: completedAt is Timestamp
          ? completedAt.toDate()
          : null,
      completedByUserId: data['completedByUserId'] as String?,
      completedByName: data['completedByName'] as String?,
    );
  }

  void _validateContent(Wish wish) {
    final description = wish.description.trim();
    final note = _normalizeNote(wish.note);

    if (description.isEmpty || description.length > 80) {
      throw StateError('El deseo debe tener entre 1 y 80 caracteres.');
    }

    if (note != null && note.length > 140) {
      throw StateError('La nota puede tener hasta 140 caracteres.');
    }
  }

  String? _normalizeNote(String? value) {
    final note = value?.trim();

    return note == null || note.isEmpty ? null : note;
  }

  bool _sameContent(Wish first, Wish second) {
    return first.description.trim() == second.description.trim() &&
        first.category == second.category &&
        first.dueDate.isAtSameMomentAs(second.dueDate) &&
        _normalizeNote(first.note) == _normalizeNote(second.note);
  }
}

String wishErrorMessage(Object error) {
  if (error is StateError) {
    return error.message.toString();
  }

  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'No tienes permiso para esta operación. '
            'Comprueba las reglas de Firestore y tu conexión al bote.',
      'unavailable' =>
        'No pudimos conectar con Firebase. Comprueba tu conexión.',
      'unauthenticated' => 'Tu sesión terminó. Vuelve a entrar.',
      'aborted' =>
        'Hubo un cambio simultáneo. Intenta nuevamente.',
      _ => 'No pudimos completar la operación. Intenta nuevamente.',
    };
  }

  return 'No pudimos completar la operación. Intenta nuevamente.';
}