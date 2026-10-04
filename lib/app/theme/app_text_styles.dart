import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const display = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 28,
    height: 1.08,
    fontWeight: FontWeight.w700,
    letterSpacing: -.6,
  );

  static const body = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
    height: 1.45,
  );
}
