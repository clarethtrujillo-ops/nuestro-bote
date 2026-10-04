import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../locations/domain/models/memory_location.dart';

class MemoryRecord {
  const MemoryRecord({
    required this.wishId,
    required this.date,
    required this.description,
    required this.hasPhoto,
    required this.version,
    required this.createdByUserId,
    required this.updatedByUserId,
    this.location,
    this.photoVersion,
    this.savedAt,
    this.updatedAt,
  });

  final String wishId;
  final DateTime date;
  final String description;

  final MemoryLocation? location;

  final bool hasPhoto;
  final int? photoVersion;
  final int version;

  final String createdByUserId;
  final String updatedByUserId;

  final DateTime? savedAt;
  final DateTime? updatedAt;

  bool get hasMemory =>
      hasPhoto || description.trim().isNotEmpty;

  factory MemoryRecord.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('No pudimos leer el recuerdo.');
    }

    final date = data['date'];

    if (date is! Timestamp) {
      throw StateError('El recuerdo tiene una fecha inválida.');
    }

    final savedAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    final locationData = data['location'];

    return MemoryRecord(
      wishId: document.id,
      date: date.toDate(),
      description: data['description'] as String,
      hasPhoto: data['hasPhoto'] as bool,
      photoVersion: data['photoVersion'] as int?,
      version: data['version'] as int,
      createdByUserId: data['createdByUserId'] as String,
      updatedByUserId: data['updatedByUserId'] as String,
      location: locationData == null
          ? null
          : MemoryLocation.fromMap(
              Map<String, dynamic>.from(locationData as Map),
            ),
      savedAt: savedAt is Timestamp ? savedAt.toDate() : null,
      updatedAt:
          updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }
}

class MemoriesResult {
  const MemoriesResult({required this.records});

  final List<MemoryRecord> records;
}