import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../data/firestore_connection_repository.dart';
import '../../domain/models/invitation_code.dart';

class CreateJarScreen extends StatefulWidget {
  const CreateJarScreen({super.key});

  @override
  State<CreateJarScreen> createState() => _CreateJarScreenState();
}

class _CreateJarScreenState extends State<CreateJarScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreConnectionRepository _connectionRepository =
      FirestoreConnectionRepository();

  final ProfileRepository _profileRepository = ProfileRepository();

  late final AnimationController _pulseController;

  StreamSubscription<InvitationCode?>? _invitationSubscription;

  InvitationCode? _invitation;

  bool _isCreatingInvitation = true;
  bool _connectionHandled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
      lowerBound: 0.45,
      upperBound: 1,
    )..repeat(reverse: true);

    _createInvitation();
  }

  Future<void> _createInvitation() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isCreatingInvitation = false;
        _errorMessage =
            'No encontramos un usuario autenticado. Reinicia la aplicación.';
      });

      return;
    }

    try {
      final profile = await _profileRepository.getProfile(user.uid);

      if (!mounted) return;

      final hasCompleteProfile = profile != null &&
          profile.name.trim().length >= 2 &&
          profile.avatarSeed.trim().isNotEmpty;

      if (!hasCompleteProfile) {
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.profileSetup,
          arguments: AppRoutes.createJar,
        );
        return;
      }

      final invitation = await _connectionRepository.createInvitation(
        ownerUserId: user.uid,
      );
      if (!mounted) return;

      setState(() {
        _invitation = invitation;
        _isCreatingInvitation = false;
        _errorMessage = null;
      });

      _listenToInvitation(invitation.value);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isCreatingInvitation = false;
        _errorMessage = _readableError(error);
      });
    }
  }

  void _listenToInvitation(String code) {
    _invitationSubscription?.cancel();

    _invitationSubscription =
        _connectionRepository.watchInvitation(code).listen(
      (invitation) {
        if (!mounted || invitation == null) {
          return;
        }

        setState(() {
          _invitation = invitation;
        });

        _handleInvitationUpdate(invitation);
      },
      onError: (Object error) {
        if (!mounted) return;

        setState(() {
          _errorMessage = _readableError(error);
        });
      },
    );
  }

  Future<void> _handleInvitationUpdate(
    InvitationCode invitation,
  ) async {
    if (!invitation.isConnected ||
        invitation.coupleId == null ||
        invitation.coupleId!.isEmpty ||
        _connectionHandled) {
      return;
    }

    _connectionHandled = true;

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          'No encontramos el usuario que creó la invitación.',
        );
      }

      final coupleId = invitation.coupleId!;

      // Este paso faltaba para el dispositivo que genera el código.
      await _profileRepository.updateCoupleId(
        userId: user.uid,
        coupleId: coupleId,
      );

      // Confirmamos que el dato ya quedó disponible antes de navegar.
      final updatedProfile = await _profileRepository.getProfile(
        user.uid,
      );

      if (updatedProfile == null || updatedProfile.coupleId != coupleId) {
        throw Exception(
          'No fue posible guardar la conexión en el perfil.',
        );
      }

      if (!mounted) return;

      await _invitationSubscription?.cancel();
      _invitationSubscription = null;

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(
        AppRoutes.connectionSuccess,
        arguments: coupleId,
      );
    } catch (error) {
      _connectionHandled = false;

      if (!mounted) return;

      setState(() {
        _errorMessage = _readableError(error);
      });

      _showMessage(
        'No fue posible completar la conexión. Inténtalo nuevamente.',
      );
    }
  }

  Future<void> _copyCode({
    bool invitation = false,
  }) async {
    final code = _invitation?.value;

    if (code == null || code.isEmpty) {
      _showMessage(
        'Espera un momento mientras generamos el código.',
      );
      return;
    }

    final value =
        invitation ? 'Únete a nuestro bote con el código $code' : code;

    await Clipboard.setData(
      ClipboardData(text: value),
    );

    if (!mounted) return;

    _showMessage(
      invitation
          ? 'Invitación copiada. Ya puedes compartirla.'
          : 'Código copiado.',
    );
  }

  Future<void> _retryInvitation() async {
    await _invitationSubscription?.cancel();
    _invitationSubscription = null;

    setState(() {
      _invitation = null;
      _errorMessage = null;
      _isCreatingInvitation = true;
      _connectionHandled = false;
    });

    await _createInvitation();
  }

  Future<void> _goBack() async {
    await _cancelPendingInvitation();

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  Future<void> _openJoinScreen() async {
    await _cancelPendingInvitation();

    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(
      AppRoutes.joinJar,
    );
  }

  Future<void> _cancelPendingInvitation() async {
    final invitation = _invitation;
    final user = FirebaseAuth.instance.currentUser;

    await _invitationSubscription?.cancel();
    _invitationSubscription = null;

    if (invitation == null ||
        invitation.isConnected ||
        invitation.value.isEmpty ||
        user == null) {
      return;
    }

    try {
      await _connectionRepository.cancelInvitation(
        code: invitation.value,
        ownerUserId: user.uid,
      );
    } catch (_) {
      // Si la invitación ya fue usada o eliminada,
      // permitimos salir sin bloquear la navegación.
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.elevated,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');

    if (message.trim().isEmpty) {
      return 'Ocurrió un error inesperado.';
    }

    return message;
  }

  @override
  void dispose() {
    _invitationSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compact = media.size.height < 740;
    final reduceMotion = media.disableAnimations;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goBack();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  compact ? 14 : 22,
                  24,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      onBack: _goBack,
                    ),
                    SizedBox(
                      height: compact ? 34 : 48,
                    ),
                    const Text(
                      'CONECTA CON TU PAREJA',
                      style: TextStyle(
                        color: AppColors.inactive,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'El bote empieza\ncon los dos',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 30,
                        height: 1.02,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Comparte este código con tu pareja para crear\n'
                      'un espacio privado entre ustedes.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(
                      height: compact ? 12 : 18,
                    ),
                    const SizedBox(
                      width: double.infinity,
                      height: 82,
                      child: CustomPaint(
                        painter: _PixelConnectionPainter(),
                      ),
                    ),
                    _CodeCard(
                      invitation: _invitation,
                      isLoading: _isCreatingInvitation,
                      errorMessage: _errorMessage,
                      onCopy: () => _copyCode(),
                      onRetry: _retryInvitation,
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Compartir invitación',
                      onPressed: () {
                        if (_isCreatingInvitation || _invitation == null) {
                          _showMessage(
                            'Espera mientras generamos el código.',
                          );
                          return;
                        }

                        _copyCode(
                          invitation: true,
                        );
                      },
                    ),
                    const SizedBox(height: 17),
                    Center(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: reduceMotion ? 1 : _pulseController.value,
                            child: child,
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.coral,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox(
                                width: 8,
                                height: 8,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isCreatingInvitation
                                  ? 'Creando un código privado…'
                                  : 'Esperando a que tu pareja se una…',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _openJoinScreen,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.pink,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: const Text(
                          'Introducir otro código',
                        ),
                      ),
                    ),
                    SizedBox(
                      height: compact ? 12 : 22,
                    ),
                    const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.inactive,
                            size: 15,
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Tu código es privado y solo puede '
                              'usarse una vez.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.inactive,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              tooltip: 'Volver',
              icon: const Icon(
                Icons.chevron_left_rounded,
                size: 30,
              ),
              color: AppColors.textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            ),
          ),
          const Text(
            'nuestro · bote',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          Positioned(
            left: 30,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: const LinearProgressIndicator(
                value: 0.32,
                minHeight: 4,
                backgroundColor: AppColors.elevated,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.coral,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.invitation,
    required this.isLoading,
    required this.errorMessage,
    required this.onCopy,
    required this.onRetry,
  });

  final InvitationCode? invitation;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onCopy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null;
    final code = invitation?.value ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        22,
        24,
        22,
        22,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasError ? AppColors.coral : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'CÓDIGO DE VINCULACIÓN',
            style: TextStyle(
              color: AppColors.inactive,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const SizedBox(
              height: 38,
              width: 38,
              child: CircularProgressIndicator(
                color: AppColors.coral,
                strokeWidth: 2.5,
              ),
            )
          else if (hasError)
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.coral,
                fontSize: 12,
                height: 1.35,
              ),
            )
          else
            SelectableText(
              code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 35,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            hasError
                ? 'No pudimos generar el código.'
                : 'Válido durante 24 horas',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 17),
          if (hasError)
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 17,
              ),
              label: const Text('Intentar nuevamente'),
              style: _buttonStyle(),
            )
          else
            OutlinedButton.icon(
              onPressed: isLoading ? null : onCopy,
              icon: const Icon(
                Icons.copy_rounded,
                size: 16,
              ),
              label: const Text('Copiar código'),
              style: _buttonStyle(),
            ),
        ],
      ),
    );
  }

  ButtonStyle _buttonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      backgroundColor: AppColors.elevated,
      disabledForegroundColor: AppColors.inactive,
      side: const BorderSide(
        color: AppColors.border,
      ),
      minimumSize: const Size(
        168,
        43,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      textStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _PixelConnectionPainter extends CustomPainter {
  const _PixelConnectionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const pixel = 4.0;
    const step = 8.0;

    final muted = Paint()
      ..color = AppColors.border
      ..isAntiAlias = false;

    final accent = Paint()
      ..color = const Color(0xFF713A4D)
      ..isAntiAlias = false;

    final heartPaint = Paint()
      ..color = const Color(0xFF5F3448)
      ..isAntiAlias = false;

    final centerX = size.width / 2;

    void block(
      double x,
      double y,
      Paint paint,
    ) {
      canvas.drawRect(
        Rect.fromLTWH(
          x,
          y,
          pixel,
          pixel,
        ),
        paint,
      );
    }

    const leftLead = <Offset>[
      Offset(0, 6),
      Offset(8, 14),
      Offset(16, 22),
    ];

    for (final point in leftLead) {
      block(
        point.dx,
        point.dy,
        muted,
      );
    }

    for (double x = 24; x <= size.width * 0.27; x += step) {
      block(
        x,
        22,
        muted,
      );
    }

    for (var index = 0; index < 8; index++) {
      final paint = index >= 5 ? accent : muted;

      block(
        size.width * 0.29 + index * step,
        22 + index * 3.1,
        paint,
      );
    }

    const rightLeadY = <double>[
      6,
      14,
      22,
    ];

    for (var index = 0; index < rightLeadY.length; index++) {
      block(
        size.width - pixel - index * step,
        rightLeadY[index],
        accent,
      );
    }

    for (double x = size.width - 24; x >= size.width * 0.69; x -= step) {
      block(
        x,
        22,
        accent,
      );
    }

    for (var index = 0; index < 8; index++) {
      block(
        size.width * 0.68 - index * step,
        22 + index * 3.1,
        accent,
      );
    }

    for (double x = centerX - 12; x <= centerX + 12; x += pixel) {
      block(
        x,
        45,
        accent,
      );
    }

    block(
      centerX - 16,
      49,
      muted,
    );

    block(
      centerX + 12,
      49,
      muted,
    );

    final jarPixels = <Offset>[
      const Offset(-16, 53),
      const Offset(12, 53),
      const Offset(-20, 57),
      const Offset(16, 57),
      const Offset(-20, 61),
      const Offset(16, 61),
      const Offset(-20, 65),
      const Offset(16, 65),
      const Offset(-20, 69),
      const Offset(16, 69),
      const Offset(-16, 73),
      const Offset(12, 73),
      const Offset(-12, 77),
      const Offset(-8, 77),
      const Offset(-4, 77),
      const Offset(0, 77),
      const Offset(4, 77),
      const Offset(8, 77),
    ];

    for (final point in jarPixels) {
      block(
        centerX + point.dx,
        point.dy,
        muted,
      );
    }

    block(
      centerX - 8,
      61,
      heartPaint,
    );

    block(
      centerX,
      61,
      heartPaint,
    );

    block(
      centerX - 8,
      65,
      heartPaint,
    );

    block(
      centerX - 4,
      65,
      heartPaint,
    );

    block(
      centerX,
      65,
      heartPaint,
    );

    block(
      centerX - 4,
      69,
      heartPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}
