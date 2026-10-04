import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../profile/domain/models/user_profile.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../data/firestore_connection_repository.dart';
import '../../domain/models/couple.dart';

class ConnectionSuccessScreen
    extends StatefulWidget {
  const ConnectionSuccessScreen({
    required this.coupleId,
    super.key,
  });

  final String coupleId;

  @override
  State<ConnectionSuccessScreen> createState() {
    return _ConnectionSuccessScreenState();
  }
}

class _ConnectionSuccessScreenState
    extends State<ConnectionSuccessScreen> {
  final FirestoreConnectionRepository
      _connectionRepository =
      FirestoreConnectionRepository();

  final ProfileRepository _profileRepository =
      ProfileRepository();

  UserProfile? _currentProfile;
  UserProfile? _partnerProfile;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConnection();
  }

  Future<void> _loadConnection() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw StateError(
          'No fue posible identificar al usuario.',
        );
      }

      final Couple? couple =
          await _connectionRepository.getCouple(
        widget.coupleId,
      );

      if (couple == null) {
        throw StateError(
          'No encontramos la conexión.',
        );
      }

      if (!couple.containsUser(user.uid)) {
        throw StateError(
          'No perteneces a esta conexión.',
        );
      }

      final partnerId =
          couple.partnerIdFor(user.uid);

      if (partnerId == null) {
        throw StateError(
          'No encontramos el perfil de tu pareja.',
        );
      }

      final profiles =
          await Future.wait<UserProfile?>([
        _profileRepository.getProfile(
          user.uid,
        ),
        _profileRepository.getProfile(
          partnerId,
        ),
      ]);

      final currentProfile = profiles[0];
      final partnerProfile = profiles[1];

      if (currentProfile == null ||
          partnerProfile == null) {
        throw StateError(
          'No pudimos cargar ambos perfiles.',
        );
      }

      if (!mounted) return;

      setState(() {
        _currentProfile = currentProfile;
        _partnerProfile = partnerProfile;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is StateError
            ? error.message.toString()
            : 'No pudimos cargar la conexión.';
      });
    }
  }

  void _enterJar() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.jarHome,
      (route) => false,
      arguments: widget.coupleId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 430,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                14,
              ),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.coral,
          strokeWidth: 2.4,
        ),
      );
    }

    if (_errorMessage != null ||
        _currentProfile == null ||
        _partnerProfile == null) {
      return _ConnectionError(
        message: _errorMessage ??
            'No pudimos cargar la conexión.',
        onRetry: _loadConnection,
        onBack: () {
          Navigator.of(context).pop();
        },
      );
    }

    return Column(
      children: [
        _Header(
          onBack: () {
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 16),
        _ConnectionGraphic(
          currentProfile: _currentProfile!,
          partnerProfile: _partnerProfile!,
        ),
        const SizedBox(height: 18),
        const Text(
          'CONEXIÓN COMPLETADA',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.inactive,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ya están\nconectados',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            height: 0.93,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${_currentProfile!.name} y '
          '${_partnerProfile!.name} ya tienen un espacio\n'
          'privado para guardar sus deseos.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 17),
        const _BenefitsCard(),
        const Spacer(),
        PrimaryButton(
          label: 'Entrar a nuestro bote',
          onPressed: _enterJar,
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 11,
              color: AppColors.inactive,
            ),
            SizedBox(width: 5),
            Text(
              'Conexión privada y segura',
              style: TextStyle(
                color: AppColors.inactive,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ],
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
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: onBack,
              tooltip: 'Volver',
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 18,
              ),
              color: AppColors.textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
            ),
          ),
          const Positioned(
            top: 9,
            child: Text(
              'nuestro · bote',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.8,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 1,
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(3),
              child:
                  const LinearProgressIndicator(
                value: 1,
                minHeight: 4,
                backgroundColor:
                    AppColors.elevated,
                valueColor:
                    AlwaysStoppedAnimation(
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

class _ConnectionGraphic extends StatelessWidget {
  const _ConnectionGraphic({
    required this.currentProfile,
    required this.partnerProfile,
  });

  final UserProfile currentProfile;
  final UserProfile partnerProfile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: _CircuitPainter(),
            ),
          ),
          Positioned(
            top: 29,
            left: 34,
            right: 34,
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                _ConnectedProfile(
                  profile: currentProfile,
                  borderColor: AppColors.pink,
                ),
                _ConnectedProfile(
                  profile: partnerProfile,
                  borderColor:
                      AppColors.lavender,
                ),
              ],
            ),
          ),
          const Positioned(
            top: 45,
            child: Icon(
              Icons.link_rounded,
              color: AppColors.coral,
              size: 35,
            ),
          ),
          Positioned(
            top: 78,
            child: Container(
              width: 17,
              height: 17,
              decoration: const BoxDecoration(
                color: Color(0xFF83C8A5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.background,
                size: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedProfile extends StatelessWidget {
  const _ConnectedProfile({
    required this.profile,
    required this.borderColor,
  });

  final UserProfile profile;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: Column(
        children: [
          ProfileAvatar(
            profile: profile,
            size: 53,
            borderColor: borderColor,
            borderWidth: 1.5,
          ),
          const SizedBox(height: 6),
          Text(
            profile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        9,
        16,
        8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: const Column(
        children: [
          _BenefitRow(
            title:
                'Un espacio privado para los dos',
            description:
                'Solo ustedes podrán ver lo que guarden.',
          ),
          Divider(
            height: 16,
            color: AppColors.border,
          ),
          _BenefitRow(
            title: 'Deseos compartidos',
            description:
                'Ambos pueden agregar y elegir el siguiente.',
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: AppColors.coral,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 13,
            color: AppColors.background,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color:
                      AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color:
                      AppColors.textSecondary,
                  fontSize: 9,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectionError extends StatelessWidget {
  const _ConnectionError({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.link_off_rounded,
              color: AppColors.coral,
              size: 38,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:
                    AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Intentar nuevamente',
              onPressed: onRetry,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onBack,
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircuitPainter extends CustomPainter {
  const _CircuitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF2D2631)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;

    final nodePaint = Paint()
      ..color = const Color(0xFF4A3F4D)
      ..isAntiAlias = false;

    final centerX = size.width / 2;

    final path = Path()
      ..moveTo(0, 2)
      ..lineTo(18, 2)
      ..quadraticBezierTo(
        30,
        2,
        30,
        15,
      )
      ..lineTo(30, 42)
      ..quadraticBezierTo(
        30,
        55,
        43,
        55,
      )
      ..lineTo(64, 55)
      ..moveTo(size.width, 2)
      ..lineTo(size.width - 18, 2)
      ..quadraticBezierTo(
        size.width - 30,
        2,
        size.width - 30,
        15,
      )
      ..lineTo(size.width - 30, 42)
      ..quadraticBezierTo(
        size.width - 30,
        55,
        size.width - 43,
        55,
      )
      ..lineTo(size.width - 64, 55)
      ..moveTo(87, 82)
      ..lineTo(87, 97)
      ..quadraticBezierTo(
        87,
        105,
        97,
        105,
      )
      ..lineTo(centerX, 105)
      ..lineTo(centerX, 148)
      ..moveTo(size.width - 87, 82)
      ..lineTo(size.width - 87, 97)
      ..quadraticBezierTo(
        size.width - 87,
        105,
        size.width - 97,
        105,
      )
      ..lineTo(centerX, 105);

    canvas.drawPath(path, linePaint);

    void pixel(double x, double y) {
      canvas.drawRect(
        Rect.fromLTWH(
          x - 4,
          y - 4,
          8,
          8,
        ),
        nodePaint,
      );
    }

    pixel(30, 25);
    pixel(50, 55);
    pixel(size.width - 30, 25);
    pixel(size.width - 50, 55);
    pixel(87, 95);
    pixel(size.width - 87, 95);
    pixel(centerX, 105);
  }

  @override
  bool shouldRepaint(
    covariant _CircuitPainter oldDelegate,
  ) {
    return false;
  }
}