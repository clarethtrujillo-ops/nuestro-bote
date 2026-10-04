import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../widgets/brand_wordmark.dart';
import '../widgets/wish_jar_illustration.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final ProfileRepository _profileRepository = ProfileRepository();

  bool _isNavigating = false;

  Future<void> _continueTo(String destinationRoute) async {
    if (_isNavigating) {
      return;
    }

    setState(() {
      _isNavigating = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showMessage(
          'No fue posible identificar al usuario.',
        );
        return;
      }

      final profile = await _profileRepository.getProfile(
        user.uid,
      );

      if (!mounted) {
        return;
      }

      final hasCompleteProfile =
          profile != null &&
          profile.name.trim().length >= 2 &&
          profile.avatarSeed.trim().isNotEmpty;

      if (hasCompleteProfile) {
        await Navigator.of(context).pushNamed(
          destinationRoute,
        );
      } else {
        await Navigator.of(context).pushNamed(
          AppRoutes.profileSetup,
          arguments: destinationRoute,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'No pudimos comprobar tu perfil. Revisa tu conexión.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
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
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.elevated,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compact = media.size.height < 720;

    return Scaffold(
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
                compact ? 20 : 34,
                24,
                22,
              ),
              child: Column(
                children: [
                  const BrandWordmark(),
                  SizedBox(
                    height: compact ? 20 : 28,
                  ),
                  Semantics(
                    label: 'Bote con deseos compartidos',
                    image: true,
                    child: Transform.scale(
                      scale: compact ? 0.78 : 0.9,
                      child: WishJarIllustration(
                        reduceMotion: media.disableAnimations,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: compact ? 0 : 4,
                  ),
                  const Text(
                    'Todo lo que sueñan,\nen un solo lugar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      height: 1.12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Guarden sus deseos y conviértanlos\n'
                    'en planes compartidos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(
                    height: compact ? 24 : 30,
                  ),
                  AnimatedOpacity(
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    opacity: _isNavigating ? 0.65 : 1,
                    child: AbsorbPointer(
                      absorbing: _isNavigating,
                      child: PrimaryButton(
                        label: _isNavigating
                            ? 'Comprobando perfil...'
                            : 'Crear nuestro bote',
                        onPressed: () {
                          _continueTo(
                            AppRoutes.createJar,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: 'Ya tengo una invitación',
                    child: TextButton(
                      onPressed: _isNavigating
                          ? null
                          : () {
                              _continueTo(
                                AppRoutes.joinJar,
                              );
                            },
                      style: TextButton.styleFrom(
                        foregroundColor:
                            AppColors.textPrimary,
                        disabledForegroundColor:
                            AppColors.inactive,
                        minimumSize: const Size(
                          double.infinity,
                          48,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text(
                        'Tengo una invitación',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Un espacio privado solo para ustedes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.inactive,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}