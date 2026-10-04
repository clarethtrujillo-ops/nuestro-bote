import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              letterSpacing: 5.5,
            ),
            children: [
              TextSpan(text: 'nuestro'),
              TextSpan(
                text: '·',
                style: TextStyle(color: AppColors.coral),
              ),
              TextSpan(text: 'bote'),
            ],
          ),
        ),
        SizedBox(height: 7),
        Text(
          'DESEOS PARA COMPARTIR',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 7,
            fontWeight: FontWeight.w500,
            letterSpacing: 3.1,
          ),
        ),
      ],
    );
  }
}
