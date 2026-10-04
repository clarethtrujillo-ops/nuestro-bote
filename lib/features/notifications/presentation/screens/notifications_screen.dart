import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../jar/presentation/widgets/jar_bottom_navigation.dart';
import '../../data/local_reminder_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _preferences = SharedPreferencesAsync();

  static const _options = [
    (
      key: 'newWishes',
      title: 'Nuevos deseos',
      subtitle: 'Cuando tu pareja guarda un deseo.',
      icon: Icons.favorite_border_rounded,
    ),
    (
      key: 'upcomingDates',
      title: 'Fechas próximas',
      subtitle: 'Recordatorios antes de que venza un deseo.',
      icon: Icons.calendar_today_outlined,
    ),
    (
      key: 'partnerActivity',
      title: 'Actividad de la pareja',
      subtitle: 'Confirmaciones y deseos cumplidos.',
      icon: Icons.link_rounded,
    ),
    (
      key: 'newMemories',
      title: 'Nuevos recuerdos',
      subtitle: 'Cuando se agrega un recuerdo compartido.',
      icon: Icons.photo_outlined,
    ),
  ];

  final Map<String, bool> _values = {};

  String? _userId;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _storageKey(String userId, String option) {
    return 'notifications.$userId.$option';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      setState(() {
        _loading = false;
        _error = 'Tu sesión terminó. Vuelve a entrar.';
      });
      return;
    }

    try {
      final values = <String, bool>{};

      for (final option in _options) {
        values[option.key] = await _preferences.getBool(
              _storageKey(userId, option.key),
            ) ??
            false;
      }

      if (!mounted) return;

      if (FirebaseAuth.instance.currentUser?.uid != userId) {
        throw StateError(
          'La sesión cambió. Abre esta vista nuevamente.',
        );
      }

      setState(() {
        _userId = userId;
        _values
          ..clear()
          ..addAll(values);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error is StateError
            ? error.message.toString()
            : 'No pudimos cargar tus preferencias.';
      });
    }
  }

  Future<void> _change(String option, bool value) async {
    if (_loading || _saving) return;

    final userId = _userId;

    if (userId == null || FirebaseAuth.instance.currentUser?.uid != userId) {
      _showMessage('Tu sesión cambió. Abre esta vista nuevamente.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      if (option == 'upcomingDates' && value) {
        final reminders = LocalReminderService.instance;

        if (!reminders.supported) {
          _showMessage(
            'Los recordatorios con la app cerrada están disponibles '
            'en Android.',
          );
          return;
        }

        final granted = await reminders.requestPermission();

        if (!mounted) return;

        if (!granted) {
          _showMessage(
            'Permite las notificaciones de Nuestro Bote '
            'en los ajustes de Android.',
          );
          return;
        }
      }

      if (!mounted) return;

      if (FirebaseAuth.instance.currentUser?.uid != userId) {
        _showMessage('Tu sesión cambió. Abre esta vista nuevamente.');
        return;
      }

      await _preferences.setBool(
        _storageKey(userId, option),
        value,
      );

      if (!mounted) return;

      setState(() {
        _values[option] = value;
      });

      if (option == 'upcomingDates') {
        try {
          await LocalReminderService.instance.refresh();

          if (!mounted) return;

          _showMessage(
            value
                ? 'Recordatorios activados. Se programan al '
                    'sincronizar los deseos del bote.'
                : 'Recordatorios desactivados.',
          );
        } catch (error) {
          debugPrint('[RECORDATORIOS] $error');

          if (mounted) {
            _showMessage(
              'La preferencia se guardó, pero no pudimos actualizar '
              'los recordatorios. Vuelve a abrir la aplicación.',
            );
          }
        }
      }
    } catch (error) {
      debugPrint('[PREFERENCIAS] $error');

      if (mounted) {
        _showMessage(
          'No pudimos guardar el cambio. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _testReminder() async {
    if (_loading || _saving) return;

    final reminders = LocalReminderService.instance;

    if (!reminders.supported) {
      _showMessage('Esta prueba está disponible en Android.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final granted = await reminders.requestPermission();

      if (!mounted) return;

      if (!granted) {
        _showMessage(
          'Permite las notificaciones de Nuestro Bote '
          'en los ajustes de Android.',
        );
        return;
      }

      await reminders.scheduleTest();

      if (!mounted) return;

      _showMessage(
        'Prueba programada para dentro de un minuto. '
        'Android puede retrasar la entrega.',
      );
    } catch (error) {
      debugPrint('[PRUEBA RECORDATORIO] $error');

      if (mounted) {
        _showMessage(
          'No pudimos programar la prueba. Revisa la terminal.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.elevated,
        ),
      );
  }

  void _selectDestination(int index) {
    if (_saving) return;

    Navigator.of(context).pop<int>(index);
  }

  Widget _panel(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.elevated,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _option(int index) {
    final option = _options[index];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (index > 0)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: AppColors.border),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              Icon(
                option.icon,
                color: AppColors.lavender,
                size: 25,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _values[option.key] ?? false,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.coral,
                inactiveThumbColor: AppColors.lavender,
                inactiveTrackColor: AppColors.elevated,
                onChanged:
                    _saving ? null : (value) => _change(option.key, value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Volver',
          onPressed: _saving ? null : () => Navigator.of(context).pop<int>(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
        ),
        const Expanded(
          child: Text(
            'nuestro · bote',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  List<Widget> _buildPreferences() {
    return [
      const Text(
        'Preferencias',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      _panel([
        for (var i = 0; i < _options.length; i++) _option(i),
      ]),
      if (LocalReminderService.instance.supported) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _saving ? null : _testReminder,
          icon: const Icon(
            Icons.notifications_active_outlined,
          ),
          label: const Text('Probar recordatorio'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.all(14),
          ),
        ),
      ],
      if (_saving) ...[
        const SizedBox(height: 8),
        const LinearProgressIndicator(
          color: AppColors.coral,
        ),
      ],
      const SizedBox(height: 24),
      const Text(
        'Conexión',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      _panel([
        const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: AppColors.lavender,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solicitudes de conexión',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Avisos de desconexión siempre habilitados '
                      'mientras la app está abierta.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ]),
      const SizedBox(height: 20),
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Los avisos de tu pareja aparecen con la app abierta. '
              'En Android, Fechas próximas programa recordatorios '
              'que pueden aparecer con la app cerrada. '
              'Los cambios se actualizan al sincronizar.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<int>(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: JarBottomNavigation(
          selectedIndex: 2,
          onDestinationSelected: _selectDestination,
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox(
                width: double.infinity,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    const Text(
                      'Notificaciones',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Elijan qué momentos quieren recibir.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 26),
                    if (_loading)
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.coral,
                        ),
                      )
                    else if (_error != null) ...[
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Intentar nuevamente'),
                      ),
                    ] else
                      ..._buildPreferences(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
