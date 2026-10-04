import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/models/user_profile.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.profile,
    this.size = 48,
    this.borderColor = AppColors.border,
    this.borderWidth = 1,
    super.key,
  });

  final UserProfile profile;
  final double size;
  final Color borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(
        size * 0.045,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          size * 0.25,
        ),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          size * 0.19,
        ),
        child: Image.asset(
          'assets/avatars/${profile.avatarSeed == 'danna-coral' ? 'classic-coral' : profile.avatarSeed}.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return Container(
              color: AppColors.elevated,
              alignment: Alignment.center,
              child: Text(
                profile.initial,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}