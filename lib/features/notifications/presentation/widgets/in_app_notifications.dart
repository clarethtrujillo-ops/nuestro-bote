import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/local_reminder_service.dart';

class InAppNotifications extends StatefulWidget {
  const InAppNotifications({
    required this.messengerKey,
    required this.child,
    super.key,
  });

  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Widget child;

  @override
  State<InAppNotifications> createState() =>
      _InAppNotificationsState();
}

class _InAppNotificationsState extends State<InAppNotifications>
    with WidgetsBindingObserver {
  final _preferences = SharedPreferencesAsync();
  final _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _profileSubscription;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _coupleSubscription;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _wishesSubscription;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _memoriesSubscription;

  final Map<String, Map<String, dynamic>> _wishes = {};
  final Set<String> _memoryIds = {};

  String? _userId;
  String? _coupleId;

  String? _requestId;
  String? _requestedBy;

  bool _wishesReady = false;
  bool _memoriesReady = false;
  bool _foreground = true;

  int _generation = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed;

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(_watchUser);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  void _watchUser(User? user) {
    _generation++;

    _profileSubscription?.cancel();
    _profileSubscription = null;

    _stopCouple();
    _clearReminders();

    _userId = user?.uid;

    if (user == null) return;

    final userId = user.uid;

    _profileSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) {
        if (!mounted ||
            _userId != userId ||
            FirebaseAuth.instance.currentUser?.uid != userId) {
          return;
        }

        if (snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          return;
        }

        final rawId = snapshot.data()?['coupleId'];
        final coupleId =
            rawId is String && rawId.isNotEmpty ? rawId : null;

        if (coupleId == _coupleId) return;

        final previousCoupleId = _coupleId;

        _generation++;
        _stopCouple();
        _clearReminders();
        _coupleId = coupleId;

        if (previousCoupleId != null && coupleId == null) {
          _connectionMessage(
            'Tu perfil ya no está vinculado al bote anterior.',
            userId,
          );
        }

        if (coupleId != null) {
          _watchCouple(userId, coupleId);
        }
      },
      onError: _logError,
    );
  }

  void _stopCouple() {
    _coupleSubscription?.cancel();
    _wishesSubscription?.cancel();
    _memoriesSubscription?.cancel();

    _coupleSubscription = null;
    _wishesSubscription = null;
    _memoriesSubscription = null;

    _coupleId = null;
    _requestId = null;
    _requestedBy = null;

    _wishesReady = false;
    _memoriesReady = false;

    _wishes.clear();
    _memoryIds.clear();
  }

  void _watchCouple(String userId, String coupleId) {
    final generation = _generation;
    final couple = _firestore.collection('couples').doc(coupleId);

    _coupleSubscription =
        couple.snapshots(includeMetadataChanges: true).listen(
      (snapshot) {
        if (!_isCurrent(userId, coupleId, generation)) return;

        if (snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          return;
        }

        final data = snapshot.data();
        if (data == null) return;

        final members = data['memberIds'];

        if (members is! List || !members.contains(userId)) return;

        if (data['status'] != 'active') {
          _clearReminders();
          return;
        }

        final rawRequestId = data['disconnectRequestId'];
        final rawRequestedBy = data['disconnectRequestedBy'];

        final requestId =
            rawRequestId is String && rawRequestId.isNotEmpty
                ? rawRequestId
                : null;

        final requestedBy =
            rawRequestedBy is String && rawRequestedBy.isNotEmpty
                ? rawRequestedBy
                : null;

        final previousRequestId = _requestId;
        final previousRequestedBy = _requestedBy;

        _requestId = requestId;
        _requestedBy = requestedBy;

        if (requestId != null &&
            requestId != previousRequestId &&
            requestedBy != null &&
            requestedBy != userId &&
            members.contains(requestedBy)) {
          _connectionMessage(
            'Tu pareja solicitó desconectar el bote. '
            'Revisa Perfil → Gestionar conexión.',
            userId,
          );
        } else if (previousRequestId != null &&
            requestId == null) {
          _connectionMessage(
            previousRequestedBy == userId
                ? 'La solicitud de desconexión ya no está pendiente. '
                    'El bote sigue conectado.'
                : 'La solicitud de desconexión fue retirada. '
                    'El bote sigue conectado.',
            userId,
          );
        }
      },
      onError: _logError,
    );

    _wishesSubscription = couple
        .collection('wishes')
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) {
        if (!_isCurrent(userId, coupleId, generation)) return;

        if (snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          return;
        }

        unawaited(
          LocalReminderService.instance
              .synchronize(
                userId: userId,
                snapshot: snapshot,
              )
              .catchError((Object error) {
            _logError(error);
          }),
        );

        final currentIds = <String>{};

        for (final document in snapshot.docs) {
          final id = document.id;
          final data = document.data();
          final previous = _wishes[id];

          currentIds.add(id);
          _wishes[id] = Map<String, dynamic>.from(data);

          if (!_wishesReady) continue;

          if (previous == null) {
            final author = data['proposedByUserId'];

            if (author is String && author != userId) {
              final description = data['description'];

              unawaited(
                _notify(
                  'newWishes',
                  description is String
                      ? 'Tu pareja añadió un deseo: $description'
                      : 'Tu pareja añadió un nuevo deseo.',
                  userId,
                  coupleId,
                  generation,
                ),
              );
            }

            continue;
          }

          final wasCompleted = previous['completedAt'] != null;
          final isCompleted = data['completedAt'] != null;
          final completedBy = data['completedByUserId'];

          if (!wasCompleted &&
              isCompleted &&
              completedBy is String &&
              completedBy != userId) {
            unawaited(
              _notify(
                'partnerActivity',
                'Tu pareja marcó un deseo como cumplido.',
                userId,
                coupleId,
                generation,
              ),
            );

            continue;
          }

          final previousReady = _readyIds(previous);
          final currentReady = _readyIds(data);

          final partnerConfirmed = currentReady.any(
            (id) => id != userId && !previousReady.contains(id),
          );

          if (partnerConfirmed) {
            unawaited(
              _notify(
                'partnerActivity',
                'Tu pareja confirmó que está lista para un deseo.',
                userId,
                coupleId,
                generation,
              ),
            );
          }
        }

        _wishes.removeWhere((id, _) => !currentIds.contains(id));
        _wishesReady = true;
      },
      onError: _logError,
    );

    _memoriesSubscription = couple
        .collection('memories')
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) {
        if (!_isCurrent(userId, coupleId, generation)) return;

        if (snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          return;
        }

        final currentIds = <String>{};

        for (final document in snapshot.docs) {
          final id = document.id;
          final data = document.data();
          final author = data['createdByUserId'];

          currentIds.add(id);

          if (_memoriesReady &&
              !_memoryIds.contains(id) &&
              author is String &&
              author != userId) {
            unawaited(
              _notify(
                'newMemories',
                'Tu pareja guardó un nuevo recuerdo en su bote.',
                userId,
                coupleId,
                generation,
              ),
            );
          }
        }

        _memoryIds
          ..clear()
          ..addAll(currentIds);

        _memoriesReady = true;
      },
      onError: _logError,
    );
  }

  Set<String> _readyIds(Map<String, dynamic> data) {
    final value = data['readyUserIds'];

    return value is List ? value.whereType<String>().toSet() : {};
  }

  bool _isCurrent(
    String userId,
    String coupleId,
    int generation,
  ) {
    return mounted &&
        _userId == userId &&
        _coupleId == coupleId &&
        _generation == generation &&
        FirebaseAuth.instance.currentUser?.uid == userId;
  }

  void _connectionMessage(String message, String userId) {
    if (!mounted ||
        !_foreground ||
        _userId != userId ||
        FirebaseAuth.instance.currentUser?.uid != userId) {
      return;
    }

    widget.messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.elevated,
        duration: const Duration(seconds: 7),
      ),
    );
  }

  Future<void> _notify(
    String option,
    String message,
    String userId,
    String coupleId,
    int generation,
  ) async {
    if (!_foreground ||
        !_isCurrent(userId, coupleId, generation)) {
      return;
    }

    try {
      final enabled = await _preferences.getBool(
            'notifications.$userId.$option',
          ) ??
          false;

      if (!enabled ||
          !_foreground ||
          !_isCurrent(userId, coupleId, generation)) {
        return;
      }

      widget.messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.elevated,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      _logError(error);
    }
  }

  void _clearReminders() {
    unawaited(
      LocalReminderService.instance.clear().catchError((Object error) {
        _logError(error);
      }),
    );
  }

  void _logError(Object error) {
    debugPrint('[AVISOS] $error');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _generation++;
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _stopCouple();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}