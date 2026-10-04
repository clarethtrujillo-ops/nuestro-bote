class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.avatarSeed,
    this.coupleId,
  });

  final String id;
  final String name;
  final String avatarSeed;
  final String? coupleId;

  String get avatarUrl {
    final encodedSeed = Uri.encodeComponent(avatarSeed);

    return 'https://api.dicebear.com/10.x/pixel-art/svg'
        '?seed=$encodedSeed'
        '&backgroundColor=transparent';
  }

  String get initial {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      return '?';
    }

    return cleanName.substring(0, 1).toUpperCase();
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'avatarSeed': avatarSeed,
      'coupleId': coupleId,
    };
  }

  factory UserProfile.fromMap({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return UserProfile(
      id: id,
      name: map['name'] as String? ?? '',
      avatarSeed: map['avatarSeed'] as String? ?? 'magic-jar',
      coupleId: map['coupleId'] as String?,
    );
  }

  UserProfile copyWith({
    String? name,
    String? avatarSeed,
    String? coupleId,
    bool removeCoupleId = false,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      coupleId: removeCoupleId ? null : coupleId ?? this.coupleId,
    );
  }
}