import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalReminderService {
  LocalReminderService._();

  static final instance = LocalReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _preferences = SharedPreferencesAsync();

  Future<void>? _initialization;
  Future<void> _queue = Future<void>.value();

  String? _userId;
  List<Map<String, dynamic>> _wishes = [];

  int _revision = 0;

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _initialize() {
    return _initialization ??= _initializePlugin();
  }

  Future<void> _initializePlugin() async {
    try {
    
         tz_data.initializeTimeZones();

      final zone = await FlutterTimezone.getLocalTimezone();
      final identifier = zone.identifier.trim();

      if (identifier == 'GMT' ||
          identifier == 'Etc/GMT' ||
          identifier == 'UTC' ||
          identifier == 'Etc/UTC') {
        tz.setLocalLocation(tz.UTC);
      } else {
        tz.setLocalLocation(tz.getLocation(identifier));
      }

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
      );
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> scheduleTest() async {
    if (!supported) {
      throw StateError(
        'La prueba de recordatorios está disponible en Android.',
      );
    }

    await _enqueue(() async {
      await _initialize();

      await _plugin.zonedSchedule(
        id: 999,
        title: 'Nuestro Bote',
        body: 'Tu recordatorio de prueba está funcionando.',
        scheduledDate: tz.TZDateTime.now(tz.local).add(
          const Duration(minutes: 1),
        ),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'wish_dates',
            'Fechas de los deseos',
            channelDescription:
                'Recordatorios de los deseos pendientes del bote.',
            icon: 'ic_notification',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    });
  }

  Future<bool> requestPermission() async {
    if (!supported) return false;

    await _initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return false;

    final granted = await android.requestNotificationsPermission();

    return granted ?? await android.areNotificationsEnabled() ?? false;
  }

  Future<void> synchronize({
    required String userId,
    required QuerySnapshot<Map<String, dynamic>> snapshot,
  }) {
    if (!supported) return Future<void>.value();

    _userId = userId;
    _wishes = [
      for (final document in snapshot.docs)
        Map<String, dynamic>.from(document.data()),
    ];

    return refresh();
  }

  Future<void> refresh() {
    if (!supported) return Future<void>.value();

    final revision = ++_revision;
    final userId = _userId;
    final wishes = List<Map<String, dynamic>>.from(_wishes);

    return _enqueue(
      () => _apply(revision, userId, wishes),
    );
  }

  Future<void> clear() {
    if (!supported) return Future<void>.value();

    _userId = null;
    _wishes = [];

    return refresh();
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _queue.then((_) => operation());

    // Una operación fallida no bloquea los siguientes cambios.
    _queue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[RECORDATORIOS] $error');
      },
    );

    return result;
  }

  Future<void> _apply(
    int revision,
    String? userId,
    List<Map<String, dynamic>> wishes,
  ) async {
    if (revision != _revision) return;

    await _initialize();

    if (revision != _revision) return;

    // Este servicio administra todas las notificaciones locales
    // del sistema creadas hasta ahora por Nuestro Bote.
    await _plugin.cancelAll();

    if (revision != _revision ||
        userId == null ||
        FirebaseAuth.instance.currentUser?.uid != userId) {
      return;
    }

    final enabled = await _preferences.getBool(
          'notifications.$userId.upcomingDates',
        ) ??
        false;

    if (!enabled || revision != _revision) return;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (await android?.areNotificationsEnabled() != true) return;

    final now = tz.TZDateTime.now(tz.local);

    final plans = <({
      tz.TZDateTime date,
      String body,
    })>[];

    for (final wish in wishes) {
      if (wish['completedAt'] != null) continue;

      final rawDate = wish['dueDate'];
      final description = wish['description'];

      if (rawDate is! Timestamp || description is! String) continue;

      final dueDate = rawDate.toDate();

      final todayReminder = tz.TZDateTime(
        tz.local,
        dueDate.year,
        dueDate.month,
        dueDate.day,
        9,
      );

      final previousDayReminder = tz.TZDateTime(
        tz.local,
        dueDate.year,
        dueDate.month,
        dueDate.day - 1,
        9,
      );

      if (previousDayReminder.isAfter(now)) {
        plans.add((
          date: previousDayReminder,
          body: 'Mañana tienen este deseo: $description',
        ));
      }

      if (todayReminder.isAfter(now)) {
        plans.add((
          date: todayReminder,
          body: 'Hoy es la fecha de este deseo: $description',
        ));
      }
    }

    plans.sort((first, second) => first.date.compareTo(second.date));

    // Programa los 60 avisos más próximos.
    // Al sincronizar nuevamente se actualiza esta selección.
    final selected = plans.take(60).toList();

    for (var index = 0; index < selected.length; index++) {
      if (revision != _revision ||
          FirebaseAuth.instance.currentUser?.uid != userId) {
        return;
      }

      final plan = selected[index];

      await _plugin.zonedSchedule(
        id: 1000 + index,
        title: 'Nuestro Bote',
        body: plan.body,
        scheduledDate: plan.date,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'wish_dates',
            'Fechas de los deseos',
            channelDescription:
                'Recordatorios de los deseos pendientes del bote.',
            icon: 'ic_notification',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
