import 'package:flutter/material.dart';

import 'routes/app_router.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class NuestroBoteApp extends StatelessWidget {
  const NuestroBoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nuestro·bote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: AppRoutes.welcome,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
