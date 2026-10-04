import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/couple.dart';
import '../domain/models/invitation_code.dart';
import 'connection_repository.dart';

class FirestoreConnectionRepository
    implements ConnectionRepository {
  FirestoreConnectionRepository({
    FirebaseFirestore? firestore,
    Random? random,
  })  : _firestore =
            firestore ?? FirebaseFirestore.instance,
        _random = random ?? Random.secure();

  final FirebaseFirestore _firestore;
  final Random _random;

  static const String _allowedCharacters =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  CollectionReference<Map<String, dynamic>>
      get _invitations {
    return _firestore.collection('invitations');
  }

  CollectionReference<Map<String, dynamic>>
      get _couples {
    return _firestore.collection('couples');
  }

  CollectionReference<Map<String, dynamic>>
      get _users {
    return _firestore.collection('users');
  }

  @override
  Future<InvitationCode> createInvitation({
    required String ownerUserId,
  }) async {
    final cleanOwnerId = ownerUserId.trim();

    if (cleanOwnerId.isEmpty) {
      throw const ConnectionFailure(
        code: 'invalid-user',
        message:
            'No fue posible identificar al usuario.',
      );
    }

    final ownerSnapshot =
        await _users.doc(cleanOwnerId).get();

    final ownerData = ownerSnapshot.data();

    if (!ownerSnapshot.exists || ownerData == null) {
      throw const ConnectionFailure(
        code: 'profile-not-found',
        message:
            'Primero debes configurar tu perfil.',
      );
    }

    final existingCoupleId =
        ownerData['coupleId'] as String?;

    if (existingCoupleId != null &&
        existingCoupleId.trim().isNotEmpty) {
      throw const ConnectionFailure(
        code: 'already-connected',
        message:
            'Ya perteneces a un bote compartido.',
      );
    }

    for (var attempt = 0; attempt < 12; attempt++) {
      final code = _generateCode();

      final invitationReference =
          _invitations.doc(code);

      final expiresAt = DateTime.now()
          .toUtc()
          .add(
            const Duration(hours: 24),
          );

      final created =
          await _firestore.runTransaction<bool>(
        (transaction) async {
          final existingSnapshot =
              await transaction.get(
            invitationReference,
          );

          if (existingSnapshot.exists) {
            return false;
          }

          transaction.set(
            invitationReference,
            {
              'code': code,
              'ownerId': cleanOwnerId,
              'joinerId': null,
              'coupleId': null,
              'status':
                  InvitationStatus.waiting.value,
              'createdAt':
                  FieldValue.serverTimestamp(),
              'updatedAt':
                  FieldValue.serverTimestamp(),
              'expiresAt':
                  Timestamp.fromDate(expiresAt),
            },
          );

          return true;
        },
      );

      if (created) {
        return InvitationCode(
          value: code,
          ownerId: cleanOwnerId,
          expiresAt: expiresAt,
          status: InvitationStatus.waiting,
        );
      }
    }

    throw const ConnectionFailure(
      code: 'code-generation-failed',
      message:
          'No pudimos generar un código. Inténtalo nuevamente.',
    );
  }

  @override
  Stream<InvitationCode?> watchInvitation(
    String code,
  ) {
    final normalizedCode = _normalizeCode(code);

    if (normalizedCode.isEmpty) {
      return Stream.value(null);
    }

    return _invitations
        .doc(normalizedCode)
        .snapshots()
        .map(_invitationFromSnapshot);
  }

  @override
  Future<String> joinWithCode({
    required String code,
    required String joiningUserId,
  }) async {
    final normalizedCode = _normalizeCode(code);
    final cleanJoiningUserId =
        joiningUserId.trim();

    if (normalizedCode.length != 6) {
      throw const ConnectionFailure(
        code: 'invalid-code',
        message:
            'El código debe tener seis caracteres.',
      );
    }

    if (cleanJoiningUserId.isEmpty) {
      throw const ConnectionFailure(
        code: 'invalid-user',
        message:
            'No fue posible identificar al usuario.',
      );
    }

    final joiningProfile =
        await _users.doc(cleanJoiningUserId).get();

    final joiningData = joiningProfile.data();

    if (!joiningProfile.exists ||
        joiningData == null) {
      throw const ConnectionFailure(
        code: 'profile-not-found',
        message:
            'Primero debes configurar tu perfil.',
      );
    }

    final existingCoupleId =
        joiningData['coupleId'] as String?;

    if (existingCoupleId != null &&
        existingCoupleId.trim().isNotEmpty) {
      throw const ConnectionFailure(
        code: 'already-connected',
        message:
            'Ya perteneces a un bote compartido.',
      );
    }

    final invitationReference =
        _invitations.doc(normalizedCode);

    final coupleReference =
        _couples.doc();

    await _firestore.runTransaction<void>(
      (transaction) async {
        final invitationSnapshot =
            await transaction.get(
          invitationReference,
        );

        final invitationData =
            invitationSnapshot.data();

        if (!invitationSnapshot.exists ||
            invitationData == null) {
          throw const ConnectionFailure(
            code: 'code-not-found',
            message:
                'No encontramos esa invitación.',
          );
        }

        final ownerId =
            invitationData['ownerId'] as String?;

        final status =
            invitationData['status'] as String?;

        final currentJoinerId =
            invitationData['joinerId'] as String?;

        final expiresTimestamp =
            invitationData['expiresAt'];

        if (ownerId == null ||
            ownerId.trim().isEmpty) {
          throw const ConnectionFailure(
            code: 'invalid-invitation',
            message:
                'La invitación no es válida.',
          );
        }

        if (ownerId == cleanJoiningUserId) {
          throw const ConnectionFailure(
            code: 'same-user',
            message:
                'No puedes usar tu propio código.',
          );
        }

        if (status !=
                InvitationStatus.waiting.value ||
            currentJoinerId != null) {
          throw const ConnectionFailure(
            code: 'code-used',
            message:
                'Esta invitación ya fue utilizada.',
          );
        }

        if (expiresTimestamp is! Timestamp) {
          throw const ConnectionFailure(
            code: 'invalid-expiration',
            message:
                'La invitación no tiene una vigencia válida.',
          );
        }

        final expiresAt =
            expiresTimestamp.toDate();

        if (DateTime.now().isAfter(expiresAt)) {
          throw const ConnectionFailure(
            code: 'code-expired',
            message:
                'Esta invitación ya venció.',
          );
        }

        transaction.set(
          coupleReference,
          {
            'memberIds': [
              ownerId,
              cleanJoiningUserId,
            ],
            'invitationCode':
                normalizedCode,
            'status': 'active',
            'createdAt':
                FieldValue.serverTimestamp(),
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );

        transaction.update(
          invitationReference,
          {
            'joinerId':
                cleanJoiningUserId,
            'coupleId':
                coupleReference.id,
            'status':
                InvitationStatus.connected.value,
            'joinedAt':
                FieldValue.serverTimestamp(),
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );
      },
    );

    await _users
        .doc(cleanJoiningUserId)
        .update({
      'coupleId': coupleReference.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return coupleReference.id;
  }

  @override
  Future<Couple?> getCouple(
    String coupleId,
  ) async {
    final cleanCoupleId = coupleId.trim();

    if (cleanCoupleId.isEmpty) {
      return null;
    }

    final snapshot =
        await _couples.doc(cleanCoupleId).get();

    return _coupleFromSnapshot(snapshot);
  }

  @override
  Stream<Couple?> watchCouple(
    String coupleId,
  ) {
    final cleanCoupleId = coupleId.trim();

    if (cleanCoupleId.isEmpty) {
      return Stream.value(null);
    }

    return _couples
        .doc(cleanCoupleId)
        .snapshots()
        .map(_coupleFromSnapshot);
  }

  @override
  Future<void> cancelInvitation({
    required String code,
    required String ownerUserId,
  }) async {
    final normalizedCode = _normalizeCode(code);

    if (normalizedCode.isEmpty) {
      return;
    }

    final reference =
        _invitations.doc(normalizedCode);

    final snapshot = await reference.get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return;
    }

    if (data['ownerId'] != ownerUserId) {
      throw const ConnectionFailure(
        code: 'not-owner',
        message:
            'No puedes cancelar esta invitación.',
      );
    }

    if (data['status'] !=
        InvitationStatus.waiting.value) {
      return;
    }

    await reference.update({
      'status':
          InvitationStatus.cancelled.value,
      'updatedAt':
          FieldValue.serverTimestamp(),
    });
  }

  InvitationCode? _invitationFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>>
        snapshot,
  ) {
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    final expiresTimestamp =
        data['expiresAt'];

    if (expiresTimestamp is! Timestamp) {
      return null;
    }

    return InvitationCode(
      value:
          data['code'] as String? ??
              snapshot.id,
      ownerId:
          data['ownerId'] as String? ?? '',
      joinerId:
          data['joinerId'] as String?,
      coupleId:
          data['coupleId'] as String?,
      expiresAt:
          expiresTimestamp.toDate(),
      status:
          InvitationStatusValue.fromValue(
        data['status'] as String?,
      ),
    );
  }

    Couple? _coupleFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    final rawMemberIds = data['memberIds'];
    final createdTimestamp = data['createdAt'];

    if (rawMemberIds is! List ||
        createdTimestamp is! Timestamp) {
      return null;
    }

    final memberIds = rawMemberIds
        .whereType<String>()
        .toList(growable: false);

    if (memberIds.length != 2 ||
        memberIds[0] == memberIds[1]) {
      return null;
    }

    final requestedAt = data['disconnectRequestedAt'];
    final disconnectedAt = data['disconnectedAt'];

    return Couple(
      id: snapshot.id,
      memberIds: memberIds,
      invitationCode:
          data['invitationCode'] as String? ?? '',
      createdAt: createdTimestamp.toDate(),
      status: data['status'] as String? ?? 'active',
      disconnectRequestedBy:
          data['disconnectRequestedBy'] as String?,
      disconnectRequestId:
          data['disconnectRequestId'] as String?,
      disconnectRequestedAt:
          requestedAt is Timestamp
              ? requestedAt.toDate()
              : null,
      disconnectedAt:
          disconnectedAt is Timestamp
              ? disconnectedAt.toDate()
              : null,
    );
  }
  
  String _generateCode() {
    return List.generate(
      6,
      (_) {
        final index = _random.nextInt(
          _allowedCharacters.length,
        );

        return _allowedCharacters[index];
      },
    ).join();
  }

  String _normalizeCode(String value) {
    return value
        .replaceAll(
          RegExp(r'[^a-zA-Z0-9]'),
          '',
        )
        .toUpperCase();
  }
}