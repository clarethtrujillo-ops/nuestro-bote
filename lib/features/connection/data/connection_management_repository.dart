import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConnectionManagementRepository {
  ConnectionManagementRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _userId {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Tu sesión terminó. Vuelve a entrar.');
    }

    return user.uid;
  }

  Map<String, dynamic> _validateCouple(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String userId,
  ) {
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw StateError('No encontramos su conexión.');
    }

    final members = data['memberIds'];

    if (members is! List ||
        members.length != 2 ||
        !members.contains(userId)) {
      throw StateError('No perteneces a esta conexión.');
    }

    if (data['status'] != 'active') {
      throw StateError('Esta conexión ya fue cerrada.');
    }

    return data;
  }

  Future<void> requestDisconnect(String coupleId) async {
    final userId = _userId;
    final reference = _firestore.collection('couples').doc(coupleId);

    // Genera un identificador sin crear otro documento.
    final requestId =
        _firestore.collection('couples').doc().id;

    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = _validateCouple(snapshot, userId);

      if (data['disconnectRequestedBy'] != null ||
          data['disconnectRequestId'] != null) {
        throw StateError(
          'Ya hay una solicitud pendiente. '
          'Vuelve a revisar la pantalla.',
        );
      }

      transaction.update(reference, {
        'disconnectRequestedBy': userId,
        'disconnectRequestId': requestId,
        'disconnectRequestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> dismissDisconnect({
    required String coupleId,
    required String expectedRequestId,
  }) async {
    final userId = _userId;
    final reference = _firestore.collection('couples').doc(coupleId);

    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = _validateCouple(snapshot, userId);

      if (data['disconnectRequestId'] != expectedRequestId ||
          data['disconnectRequestedBy'] == null) {
        throw StateError(
          'La solicitud cambió. Revisa su estado nuevamente.',
        );
      }

      // El solicitante puede cancelar.
      // La otra persona puede rechazar.
      transaction.update(reference, {
        'disconnectRequestedBy': null,
        'disconnectRequestId': null,
        'disconnectRequestedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> confirmDisconnect({
    required String coupleId,
    required String expectedRequestId,
  }) async {
    final userId = _userId;
    final reference = _firestore.collection('couples').doc(coupleId);

    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = _validateCouple(snapshot, userId);

      final requestedBy = data['disconnectRequestedBy'];

      if (data['disconnectRequestId'] != expectedRequestId ||
          requestedBy is! String) {
        throw StateError(
          'La solicitud cambió. Revisa su estado nuevamente.',
        );
      }

      if (requestedBy == userId) {
        throw StateError(
          'Tu pareja debe confirmar la solicitud.',
        );
      }

      final members =
          List<String>.from(data['memberIds'] as List);

      if (!members.contains(requestedBy)) {
        throw StateError('La solicitud no es válida.');
      }

      final firstUser =
          _firestore.collection('users').doc(members[0]);

      final secondUser =
          _firestore.collection('users').doc(members[1]);

      // Todas las lecturas se realizan antes de escribir.
      final firstSnapshot = await transaction.get(firstUser);
      final secondSnapshot = await transaction.get(secondUser);

      if (firstSnapshot.data()?['coupleId'] != coupleId ||
          secondSnapshot.data()?['coupleId'] != coupleId) {
        throw StateError(
          'Los perfiles cambiaron. '
          'Vuelve a abrir Gestionar conexión.',
        );
      }

      transaction.update(reference, {
        'status': 'disconnected',
        'disconnectedBy': userId,
        'disconnectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(firstUser, {
        'coupleId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(secondUser, {
        'coupleId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}