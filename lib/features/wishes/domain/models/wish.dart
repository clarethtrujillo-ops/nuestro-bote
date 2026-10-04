enum WishCategory {
  plan,
  experience,
  detail,
}

extension WishCategoryLabel on WishCategory {
  String get label => switch (this) {
        WishCategory.plan => 'Plan',
        WishCategory.experience => 'Experiencia',
        WishCategory.detail => 'Detalle',
      };
}

class Wish {
  const Wish({
    required this.description,
    required this.category,
    required this.dueDate,
    required this.proposedBy,
    required this.createdAt,
    this.id,
    this.note,
    this.proposedByUserId,
    this.readyUserIds = const [],
    this.completedAt,
    this.completedByUserId,
    this.completedByName,
  });

  final String? id;
  final String description;
  final WishCategory category;
  final DateTime dueDate;
  final String proposedBy;
  final DateTime createdAt;
  final String? note;
  final String? proposedByUserId;
  final List<String> readyUserIds;

  final DateTime? completedAt;
  final String? completedByUserId;
  final String? completedByName;

  String get key => id ?? createdAt.microsecondsSinceEpoch.toString();

  bool get isCompleted => completedAt != null;

  String get statusLabel => isCompleted ? 'Cumplido' : 'Pendiente';

  bool get hasNote => note != null && note!.trim().isNotEmpty;

  Wish copyWith({
    String? id,
    String? description,
    WishCategory? category,
    DateTime? dueDate,
    String? proposedBy,
    DateTime? createdAt,
    String? note,
    bool removeNote = false,
    String? proposedByUserId,
    List<String>? readyUserIds,
    DateTime? completedAt,
    String? completedByUserId,
    String? completedByName,
  }) {
    return Wish(
      id: id ?? this.id,
      description: description ?? this.description,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      proposedBy: proposedBy ?? this.proposedBy,
      createdAt: createdAt ?? this.createdAt,
      note: removeNote ? null : (note ?? this.note),
      proposedByUserId: proposedByUserId ?? this.proposedByUserId,
      readyUserIds: readyUserIds == null
          ? this.readyUserIds
          : List<String>.unmodifiable(readyUserIds),
      completedAt: completedAt ?? this.completedAt,
      completedByUserId: completedByUserId ?? this.completedByUserId,
      completedByName: completedByName ?? this.completedByName,
    );
  }
}

class WishDetailResult {
  const WishDetailResult.updated(
    Wish updatedWish, {
    this.openMemories = false,
    this.addMemory = false,
  })  : wish = updatedWish,
        deleted = false;

  const WishDetailResult.deleted()
      : wish = null,
        deleted = true,
        openMemories = false,
        addMemory = false;

  final Wish? wish;
  final bool deleted;

  /// Abre la lista de recuerdos al volver al bote.
  final bool openMemories;

  /// Abre el formulario del deseo que acaba de cumplirse.
  final bool addMemory;
}