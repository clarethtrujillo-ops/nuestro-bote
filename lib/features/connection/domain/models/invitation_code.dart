enum InvitationStatus {
  waiting,
  connected,
  cancelled,
}

extension InvitationStatusValue on InvitationStatus {
  String get value {
    return switch (this) {
      InvitationStatus.waiting => 'waiting',
      InvitationStatus.connected => 'connected',
      InvitationStatus.cancelled => 'cancelled',
    };
  }

  static InvitationStatus fromValue(String? value) {
    return switch (value) {
      'connected' => InvitationStatus.connected,
      'cancelled' => InvitationStatus.cancelled,
      _ => InvitationStatus.waiting,
    };
  }
}

class InvitationCode {
  const InvitationCode({
    required this.value,
    required this.ownerId,
    required this.expiresAt,
    required this.status,
    this.joinerId,
    this.coupleId,
  });

  final String value;
  final String ownerId;
  final String? joinerId;
  final String? coupleId;
  final DateTime expiresAt;
  final InvitationStatus status;

  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  bool get isWaiting {
    return status == InvitationStatus.waiting &&
        !isExpired;
  }

  bool get isConnected {
    return status == InvitationStatus.connected &&
        coupleId != null &&
        joinerId != null;
  }

  InvitationCode copyWith({
    String? value,
    String? ownerId,
    String? joinerId,
    String? coupleId,
    DateTime? expiresAt,
    InvitationStatus? status,
  }) {
    return InvitationCode(
      value: value ?? this.value,
      ownerId: ownerId ?? this.ownerId,
      joinerId: joinerId ?? this.joinerId,
      coupleId: coupleId ?? this.coupleId,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
    );
  }
}