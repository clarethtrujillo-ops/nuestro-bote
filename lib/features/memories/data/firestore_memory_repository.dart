import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../wishes/data/firestore_wish_repository.dart';
import '../domain/models/memory_record.dart';
import '../../locations/domain/models/memory_location.dart';

class FirestoreMemoryRepository {
  FirestoreMemoryRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const maxPhotoBytes = 100 * 1024;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _couple(String coupleId) {
    if (coupleId.isEmpty) {
      throw StateError('No encontramos el identificador del bote.');
    }

    return _firestore.collection('couples').doc(coupleId);
  }

  Stream<List<MemoryRecord>> watchMemories(String coupleId) {
    return _couple(coupleId)
        .collection('memories')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(MemoryRecord.fromDocument)
              .toList(growable: false),
        );
  }

  Future<Uint8List> loadPhoto({
    required String coupleId,
    required String wishId,
    required int photoVersion,
  }) async {
    final document = await _couple(coupleId)
        .collection('memoryPhotos')
        .doc(wishId)
        .get()
        .timeout(const Duration(seconds: 20));

    final data = document.data();

    if (data == null) {
      throw StateError('No encontramos la foto del recuerdo.');
    }

    if (data['version'] != photoVersion) {
      throw StateError('La foto cambió. Intenta cargarla nuevamente.');
    }

    final bytes = data['bytes'];

    if (bytes is! Blob) {
      throw StateError('La foto guardada no tiene un formato válido.');
    }

    return bytes.bytes;
  }

  Future<Uint8List> compressPhoto(Uint8List bytes) {
    return compute(compressMemoryPhoto, bytes);
  }

   Future<void> saveMemory({
    required String coupleId,
    required String wishId,
    required DateTime date,
    required String description,
    required int expectedVersion,
    MemoryLocation? location,
    Uint8List? newPhoto,
    bool removePhoto = false,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Tu sesión terminó. Vuelve a entrar.');
    }
    location?.validate();
    final text = description.trim();

    if (text.length > 200) {
      throw StateError('El texto puede tener hasta 200 caracteres.');
    }

    if (newPhoto != null &&
        (newPhoto.isEmpty || newPhoto.lengthInBytes > maxPhotoBytes)) {
      throw StateError('La foto debe pesar como máximo 100 KB.');
    }

    final day = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (day.isAfter(today) || day.isBefore(DateTime(1900))) {
      throw StateError('Elige una fecha válida para el recuerdo.');
    }

    final couple = _couple(coupleId);
    final wishReference = couple.collection('wishes').doc(wishId);
    final memoryReference = couple.collection('memories').doc(wishId);
    final photoReference = couple.collection('memoryPhotos').doc(wishId);

    await _firestore.runTransaction<void>((transaction) async {
      // Todas las lecturas ocurren antes de las escrituras.
      final wishSnapshot = await transaction.get(wishReference);
      final memorySnapshot = await transaction.get(memoryReference);

      if (!wishSnapshot.exists ||
          wishSnapshot.data()?['completedAt'] is! Timestamp) {
        throw StateError(
          'Solo puedes guardar recuerdos de deseos cumplidos.',
        );
      }

      final previous = memorySnapshot.exists
          ? MemoryRecord.fromDocument(memorySnapshot)
          : null;

      final currentVersion = previous?.version ?? 0;

      if (currentVersion != expectedVersion) {
        throw StateError(
          'Tu pareja modificó este recuerdo. '
          'Vuelve a la lista y abre la edición nuevamente.',
        );
      }

      final nextVersion = currentVersion + 1;

      final hasPhoto =
          newPhoto != null || (!removePhoto && previous?.hasPhoto == true);

      final int? photoVersion = newPhoto != null
          ? nextVersion
          : hasPhoto
              ? previous?.photoVersion
              : null;

      if (text.isEmpty && !hasPhoto) {
        throw StateError(
          'Añade una foto o escribe algo que quieran recordar.',
        );
      }

      if (newPhoto != null) {
        transaction.set(photoReference, {
          'bytes': Blob(newPhoto),
          'contentType': 'image/jpeg',
          'version': nextVersion,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (removePhoto && previous?.hasPhoto == true) {
        transaction.delete(photoReference);
      }

           final values = <String, dynamic>{
        'date': Timestamp.fromDate(day),
        'description': text,
        'location': location?.toMap(),
        'hasPhoto': hasPhoto,
        'photoVersion': photoVersion,
        'version': nextVersion,
        'updatedByUserId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (previous == null) {
        transaction.set(memoryReference, {
          ...values,
          'createdByUserId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(memoryReference, values);
      }
    });
  }
}

// Función independiente para ejecutar la compresión con compute.
Uint8List compressMemoryPhoto(Uint8List bytes) {
  if (bytes.lengthInBytes > 15 * 1024 * 1024) {
    throw StateError('Selecciona una foto de menos de 15 MB.');
  }

  final decoded = img.decodeImage(bytes);

  if (decoded == null) {
    throw StateError(
      'No pudimos leer esa imagen. Prueba con una foto JPG o PNG.',
    );
  }

  final oriented = img.bakeOrientation(decoded);
  final longestSide =
      oriented.width > oriented.height ? oriented.width : oriented.height;

  var targetSize = longestSide > 900 ? 900 : longestSide;

  while (targetSize >= 160) {
    final resized = oriented.width >= oriented.height
        ? img.copyResize(oriented, width: targetSize)
        : img.copyResize(oriented, height: targetSize);

    for (final quality in [85, 70, 55, 40]) {
      final encoded = img.encodeJpg(resized, quality: quality);

      if (encoded.lengthInBytes <= FirestoreMemoryRepository.maxPhotoBytes) {
        return Uint8List.fromList(encoded);
      }
    }

    targetSize = (targetSize * 0.75).floor();
  }

  // También cubre imágenes que ya tenían dimensiones pequeñas.
  final small = oriented.width >= oriented.height
      ? img.copyResize(
          oriented,
          width: longestSide < 160 ? longestSide : 160,
        )
      : img.copyResize(
          oriented,
          height: longestSide < 160 ? longestSide : 160,
        );

  final encoded = img.encodeJpg(small, quality: 35);

  if (encoded.lengthInBytes > FirestoreMemoryRepository.maxPhotoBytes) {
    throw StateError('No pudimos reducir esta foto a 100 KB.');
  }

  return Uint8List.fromList(encoded);
}

String memoryErrorMessage(Object error) {
  if (error is FirebaseException && error.code == 'resource-exhausted') {
    return 'Se alcanzó una cuota gratuita de Firebase. '
        'Revisa la sección Uso de Firestore.';
  }

  return wishErrorMessage(error);
}
