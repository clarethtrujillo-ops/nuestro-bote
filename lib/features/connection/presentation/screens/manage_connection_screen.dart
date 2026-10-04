import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../jar/presentation/widgets/jar_bottom_navigation.dart';
import '../../../onboarding/presentation/screens/welcome_screen.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../profile/domain/models/user_profile.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../data/connection_management_repository.dart';
import '../../data/firestore_connection_repository.dart';
import '../../domain/models/couple.dart';

class ManageConnectionScreen extends StatefulWidget {
  const ManageConnectionScreen({
    required this.coupleId,
    super.key,
  });

  final String coupleId;

  @override
  State<ManageConnectionScreen> createState() => _ManageConnectionScreenState();
}

class _ManageConnectionScreenState extends State<ManageConnectionScreen> {
  final _connections = FirestoreConnectionRepository();
  final _management = ConnectionManagementRepository();
  final _profiles = ProfileRepository();

  StreamSubscription<Couple?>? _coupleSubscription;
  StreamSubscription<UserProfile?>? _currentSubscription;
  StreamSubscription<UserProfile?>? _partnerSubscription;

  Couple? _couple;
  UserProfile? _currentProfile;
  UserProfile? _partnerProfile;

  String? _userId;
  String? _error;

  bool _loading = true;
  bool _busy = false;
  bool _leaving = false;
  bool _profilesStarted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _coupleSubscription?.cancel();
    _currentSubscription?.cancel();
    _partnerSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    await _coupleSubscription?.cancel();
    await _currentSubscription?.cancel();
    await _partnerSubscription?.cancel();

    if (!mounted) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;

    setState(() {
      _userId = userId;
      _loading = true;
      _error = null;
      _profilesStarted = false;
      _currentProfile = null;
      _partnerProfile = null;
    });

    if (userId == null) {
      _handleError(
        StateError('Tu sesión terminó. Vuelve a entrar.'),
      );
      return;
    }

    _coupleSubscription = _connections.watchCouple(widget.coupleId).listen(
      (couple) {
        if (!mounted || _leaving) return;

        if (couple == null || !couple.containsUser(userId)) {
          _handleError(
            StateError('No encontramos su conexión.'),
          );
          return;
        }

        if (!couple.isActive) {
          _returnToWelcome();
          return;
        }

        setState(() {
          _couple = couple;
        });

        if (!_profilesStarted) {
          final partnerId = couple.partnerIdFor(userId);

          if (partnerId == null) {
            _handleError(
              StateError('No encontramos a tu pareja.'),
            );
            return;
          }

          _profilesStarted = true;

          _currentSubscription = _profiles.watchProfile(userId).listen(
            (profile) {
              if (!mounted || _leaving) return;

              setState(() {
                _currentProfile = profile;
                _updateLoading();
              });
            },
            onError: _handleError,
          );

          _partnerSubscription = _profiles.watchProfile(partnerId).listen(
            (profile) {
              if (!mounted || _leaving) return;

              setState(() {
                _partnerProfile = profile;
                _updateLoading();
              });
            },
            onError: _handleError,
          );
        }
      },
      onError: _handleError,
    );
  }

  void _updateLoading() {
    if (_currentProfile != null && _partnerProfile != null) {
      _loading = false;
      _error = null;
    }
  }

  void _handleError(Object error) {
    if (!mounted || _leaving) return;

    setState(() {
      _loading = false;
      _error = error is StateError
          ? error.message.toString()
          : 'No pudimos consultar la conexión. '
              'Revisa internet y los permisos de Firebase.';
    });
  }

  void _returnToWelcome() {
    if (_leaving) return;

    _leaving = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => const WelcomeScreen(),
        ),
        (_) => false,
      );
    });
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.elevated,
        ),
      );
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String button,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
              ),
            ),
            content: Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Volver'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: Text(
                  button,
                  style: const TextStyle(
                    color: AppColors.coral,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _requestDisconnect() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    try {
      final accepted = await _confirmDialog(
        title: 'Solicitar desconexión',
        message: 'Tu pareja deberá confirmar. '
            'Mientras la solicitud esté pendiente, '
            'su bote seguirá conectado.',
        button: 'Enviar solicitud',
      );

      if (!mounted || !accepted) return;

      await _management.requestDisconnect(widget.coupleId);

      if (mounted) {
        _showMessage('Solicitud enviada a tu pareja.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is StateError
              ? error.message.toString()
              : 'No pudimos enviar la solicitud.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _dismissDisconnect() async {
    final requestId = _couple?.disconnectRequestId;

    if (_busy || requestId == null) return;

    setState(() {
      _busy = true;
    });

    try {
      await _management.dismissDisconnect(
        coupleId: widget.coupleId,
        expectedRequestId: requestId,
      );

      if (mounted) {
        _showMessage('La conexión continúa activa.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is StateError
              ? error.message.toString()
              : 'No pudimos actualizar la solicitud.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _confirmDisconnect() async {
    final requestId = _couple?.disconnectRequestId;

    if (_busy || requestId == null) return;

    setState(() {
      _busy = true;
    });

    try {
      final accepted = await _confirmDialog(
        title: 'Confirmar desconexión',
        message: 'Ambos perfiles dejarán de estar vinculados. '
            'Los deseos y recuerdos se conservarán '
            'en el bote archivado.',
        button: 'Confirmar desconexión',
      );

      if (!mounted || !accepted) return;

      await _management.confirmDisconnect(
        coupleId: widget.coupleId,
        expectedRequestId: requestId,
      );

      if (mounted) {
        _returnToWelcome();
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is StateError
              ? error.message.toString()
              : 'No pudimos confirmar la desconexión.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _selectDestination(int index) {
    if (_busy || _leaving) return;

    // Perfil recibirá el destino elegido.
    Navigator.of(context).pop<int>(index);
  }

  String _formatDate(DateTime date) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    final local = date.toLocal();

    return '${local.day} de '
        '${months[local.month - 1]} de ${local.year}';
  }

  Widget _panel({
    required Widget child,
    bool danger = false,
    double minHeight = 0,
  }) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: minHeight,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.elevated,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: danger ? AppColors.coral : AppColors.border,
        ),
      ),
      child: child,
    );
  }

  Widget _member(UserProfile profile, String subtitle) {
    return Row(
      children: [
        ProfileAvatar(
          profile: profile,
          size: 38,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _riskPanel(Couple couple) {
    final pending = couple.hasDisconnectRequest;
    final requestedByMe = couple.disconnectRequestedBy == _userId;

    return _panel(
      danger: true,
      minHeight: 190,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zona de riesgo',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.link_off_rounded,
                color: AppColors.coral,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pending ? 'Solicitud de desconexión' : 'Desconectar pareja',
                  style: const TextStyle(
                    color: AppColors.coral,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            !pending
                ? 'Esta acción requiere confirmación de ambos.'
                : requestedByMe
                    ? 'Esperando la confirmación de '
                        '${_partnerProfile!.name}.'
                    : '${_partnerProfile!.name} solicitó '
                        'desconectar sus perfiles.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          if (!pending)
            TextButton(
              onPressed: _busy ? null : _requestDisconnect,
              child: const Text(
                'Solicitar desconexión',
                style: TextStyle(color: AppColors.coral),
              ),
            )
          else if (requestedByMe)
            TextButton(
              onPressed: _busy ? null : _dismissDisconnect,
              child: const Text('Cancelar solicitud'),
            )
          else
            Wrap(
              spacing: 10,
              children: [
                TextButton(
                  onPressed: _busy ? null : _dismissDisconnect,
                  child: const Text('Mantener conexión'),
                ),
                TextButton(
                  onPressed: _busy ? null : _confirmDisconnect,
                  child: const Text(
                    'Confirmar desconexión',
                    style: TextStyle(color: AppColors.coral),
                  ),
                ),
              ],
            ),
          if (_busy)
            const LinearProgressIndicator(
              color: AppColors.coral,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final couple = _couple;
    final current = _currentProfile;
    final partner = _partnerProfile;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: JarBottomNavigation(
          selectedIndex: 2,
          onDestinationSelected: _selectDestination,
        ),
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  120,
                ),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed:
                            _busy ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
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
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Gestionar conexión',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Controlen el vínculo de su bote compartido.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                    TextButton(
                      onPressed: _load,
                      child: const Text('Intentar nuevamente'),
                    ),
                  ] else if (couple != null &&
                      current != null &&
                      partner != null) ...[
                    _panel(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ProfileAvatar(
                                profile: current,
                                size: 46,
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Icon(
                                  Icons.link_rounded,
                                  color: AppColors.coral,
                                  size: 34,
                                ),
                              ),
                              ProfileAvatar(
                                profile: partner,
                                size: 46,
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: couple.hasDisconnectRequest
                                      ? AppColors.coral
                                      : const Color(0xFF9BD6BB),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                couple.hasDisconnectRequest
                                    ? 'Solicitud pendiente'
                                    : 'Conexión activa',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Conectados desde el '
                            '${_formatDate(couple.createdAt)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Integrantes',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _panel(
                      child: Column(
                        children: [
                          _member(current, 'Tú'),
                          const SizedBox(height: 16),
                          _member(partner, 'Tu pareja'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _panel(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.lavender,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Privacidad compartida',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Solo ${current.name} y '
                                  '${partner.name} pueden acceder '
                                  'al bote.\n'
                                  'Sus deseos y recuerdos son privados.\n'
                                  'El contenido se conserva si '
                                  'desconectan sus perfiles.',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _riskPanel(couple),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
