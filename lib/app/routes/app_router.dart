import 'package:flutter/material.dart';

import '../../features/connection/presentation/screens/connection_success_screen.dart';
import '../../features/connection/presentation/screens/create_jar_screen.dart';
import '../../features/connection/presentation/screens/join_jar_screen.dart';
import '../../features/jar/presentation/screens/jar_home_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/profile/presentation/screens/profile_setup_screen.dart';
import '../../features/wishes/domain/models/wish.dart';
import '../../features/wishes/presentation/screens/create_wish_screen.dart';
import '../../features/wishes/presentation/screens/wish_detail_screen.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(
    RouteSettings settings,
  ) {
    switch (settings.name) {
      case AppRoutes.welcome:
        return MaterialPageRoute<void>(
          builder: (_) => const WelcomeScreen(),
          settings: settings,
        );

      case AppRoutes.profileSetup:
        final destinationRoute = settings.arguments;

        if (destinationRoute is! String) {
          return _errorRoute(
            settings,
            'No se recibió el destino de la configuración del perfil.',
          );
        }

        final validDestination = destinationRoute == AppRoutes.createJar ||
            destinationRoute == AppRoutes.joinJar;

        if (!validDestination) {
          return _errorRoute(
            settings,
            'El destino del perfil no es válido.',
          );
        }

        return MaterialPageRoute<void>(
          builder: (_) => ProfileSetupScreen(
            destinationRoute: destinationRoute,
          ),
          settings: settings,
        );

      case AppRoutes.createJar:
        return MaterialPageRoute<void>(
          builder: (_) => const CreateJarScreen(),
          settings: settings,
        );

      case AppRoutes.joinJar:
        return MaterialPageRoute<void>(
          builder: (_) => const JoinJarScreen(),
          settings: settings,
        );

      case AppRoutes.connectionSuccess:
        final coupleId = settings.arguments;

        if (coupleId is! String || coupleId.trim().isEmpty) {
          return _errorRoute(
            settings,
            'No se recibió la pareja conectada.',
          );
        }

        return MaterialPageRoute<void>(
          builder: (_) => ConnectionSuccessScreen(
            coupleId: coupleId,
          ),
          settings: settings,
        );

      case AppRoutes.jarHome:
        final coupleId = settings.arguments;

        if (coupleId is! String || coupleId.trim().isEmpty) {
          return _errorRoute(
            settings,
            'No se recibió el identificador del bote.',
          );
        }

        return MaterialPageRoute<void>(
          builder: (_) => JarHomeScreen(
            coupleId: coupleId,
          ),
          settings: settings,
        );

      case AppRoutes.createWish:
        final initialWish = settings.arguments;

        return MaterialPageRoute<Wish>(
          builder: (_) => CreateWishScreen(
            initialWish: initialWish is Wish ? initialWish : null,
          ),
          settings: settings,
        );

     case AppRoutes.wishDetail:
  final wish = settings.arguments;

  if (wish is Wish) {
    return MaterialPageRoute<WishDetailResult>(
      builder: (_) => WishDetailScreen(
        wish: wish,
      ),
      settings: settings,
    );
  }

  return _errorRoute(
    settings,
    'No se recibió el deseo que se quiere mostrar.',
  );

default:
  return _errorRoute(
    settings,
    'La ruta ${settings.name} no existe.',
  );
    }
  }

  static Route<void> _errorRoute(
    RouteSettings settings,
    String message,
  ) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                message,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
