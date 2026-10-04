class Couple {
  const Couple({
    required this.id,
    required this.memberIds,
    required this.invitationCode,
    required this.createdAt,
    this.status = 'active',
    this.disconnectRequestedBy,
    this.disconnectRequestId,
    this.disconnectRequestedAt,
    this.disconnectedAt,
  });

  final String id;
  final List<String> memberIds;
  final String invitationCode;
  final DateTime createdAt;

  final String status;
  final String? disconnectRequestedBy;
  final String? disconnectRequestId;
  final DateTime? disconnectRequestedAt;
  final DateTime? disconnectedAt;

  bool get isActive => status == 'active';

  bool get hasDisconnectRequest =>
      isActive &&
      disconnectRequestedBy != null &&
      disconnectRequestId != null;

  bool containsUser(String userId) {
    return memberIds.contains(userId);
  }

  String? partnerIdFor(String currentUserId) {
    if (!containsUser(currentUserId)) return null;

    for (final memberId in memberIds) {
      if (memberId != currentUserId) {
        return memberId;
      }
    }

    return null;
  }
}