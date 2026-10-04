import '../domain/models/couple.dart';
import '../domain/models/invitation_code.dart';

abstract interface class ConnectionRepository {
  Future<InvitationCode> createInvitation({
    required String ownerUserId,
  });

  Stream<InvitationCode?> watchInvitation(
    String code,
  );

  Future<String> joinWithCode({
    required String code,
    required String joiningUserId,
  });

  Future<Couple?> getCouple(
    String coupleId,
  );

  Stream<Couple?> watchCouple(
    String coupleId,
  );

  Future<void> cancelInvitation({
    required String code,
    required String ownerUserId,
  });
}

class ConnectionFailure implements Exception {
  const ConnectionFailure({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() {
    return message;
  }
}