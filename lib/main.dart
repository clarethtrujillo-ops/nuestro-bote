import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/routes/app_router.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/app_theme.dart';
import 'firebase_options.dart';
import 'features/onboarding/presentation/screens/welcome_screen.dart';
import 'features/notifications/presentation/widgets/in_app_notifications.dart';

final _notificationMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const NuestroBoteApp());
}

class NuestroBoteApp extends StatelessWidget {
  const NuestroBoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nuestro Bote',
            debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _notificationMessengerKey,
      builder: (context, child) {
        return InAppNotifications(
          messengerKey: _notificationMessengerKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _StartupScreen(),
      onGenerateRoute: AppRouter.onGenerateRoute,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.coral,
          secondary: AppColors.pink,
          surface: AppColors.surface,
          onPrimary: AppColors.textPrimary,
          onSecondary: AppColors.textPrimary,
          onSurface: AppColors.textPrimary,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.elevated,
          contentTextStyle: TextStyle(
            color: AppColors.textPrimary,
          ),
          behavior: SnackBarBehavior.floating,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppColors.coral,
          selectionColor: AppColors.border,
          selectionHandleColor: AppColors.coral,
        ),
      ),
    );
  }
}

class _StartupScreen extends StatefulWidget {
  const _StartupScreen();

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  static const _stepTimeout = Duration(seconds: 20);

  bool _isLoading = true;
  bool _isRestoring = false;

  String _loadingMessage = 'Recuperando tu espacio…';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restoreAccess();
    });
  }

  Future<T> _runStep<T>(
    String message,
    Future<T> Function() operation,
  ) async {
    if (!mounted) {
      throw StateError('La pantalla de inicio fue cerrada.');
    }

    setState(() {
      _loadingMessage = message;
    });

    debugPrint('[INICIO] $message');

    try {
      final result = await operation().timeout(
        _stepTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Firebase no respondió a tiempo durante: $message',
          );
        },
      );

      debugPrint('[INICIO] Completado: $message');
      return result;
    } catch (error) {
      debugPrint('[INICIO] Falló: $message');
      rethrow;
    }
  }

  Future<void> _restoreAccess() async {
    if (!mounted || _isRestoring) return;

    _isRestoring = true;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadingMessage = 'Recuperando tu sesión…';
    });

    try {
      final auth = FirebaseAuth.instance;

      if (kIsWeb) {
        await _runStep<void>(
          'Preparando tu sesión…',
          () => auth.setPersistence(Persistence.LOCAL),
        );
      }

      // Espera la restauración antes de crear una sesión nueva.
      User? user = await _runStep<User?>(
        'Recuperando tu sesión…',
        () => auth.authStateChanges().first,
      );

      if (user == null) {
        final credential = await _runStep<UserCredential>(
          'Iniciando tu sesión…',
          () => auth.signInAnonymously(),
        );

        user = credential.user;
      }

      if (user == null) {
        throw StateError('No pudimos iniciar tu sesión.');
      }

      final platformName =
          kIsWeb ? 'WEB' : defaultTargetPlatform.name.toUpperCase();

      debugPrint('PLATAFORMA: $platformName');
      debugPrint('USUARIO ACTUAL UID: ${user.uid}');

      final coupleId = await _findExistingCouple(user.uid);

      if (!mounted) return;

      if (auth.currentUser?.uid != user.uid) {
        throw StateError(
          'La sesión cambió. Intenta entrar nuevamente.',
        );
      }

      if (coupleId != null) {
        debugPrint('[INICIO] Abriendo el bote existente.');

        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.jarHome,
          (route) => false,
          arguments: coupleId,
        );
      } else {
        debugPrint('[INICIO] Usuario sin bote vinculado.');

        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(
            builder: (_) => const WelcomeScreen(),
          ),
          (route) => false,
        );
      }
    } on TimeoutException catch (error) {
      debugPrint('[INICIO] Tiempo de espera agotado: $error');

      _showError(
        '${error.message ?? 'Firebase no respondió a tiempo.'}\n\n'
        'Comprueba que el emulador tenga acceso a Internet '
        'y pulsa Intentar nuevamente.',
      );
    } on FirebaseAuthException catch (error) {
      debugPrint(
        '[INICIO] Autenticación: '
        '${error.code} - ${error.message}',
      );

      _showError(
        'No pudimos recuperar tu sesión (${error.code}). '
        'Inténtalo nuevamente.',
      );
    } on FirebaseException catch (error) {
      debugPrint(
        '[INICIO] Firebase: ${error.code} - ${error.message}',
      );

      final message = switch (error.code) {
        'permission-denied' =>
          'Firebase rechazó la consulta. Comprueba que las reglas '
              'estén publicadas en el proyecto utilizado por esta app.',
        'unavailable' => 'No pudimos conectar con Firebase. '
            'Comprueba la conexión a Internet del emulador.',
        'unauthenticated' =>
          'No pudimos validar tu sesión. Intenta nuevamente.',
        'failed-precondition' => 'Firebase no pudo ejecutar la consulta. '
            'Revisa el mensaje de la terminal para conocer el motivo.',
        _ => 'No pudimos recuperar tu bote (${error.code}). '
            'Inténtalo nuevamente.',
      };

      _showError(message);
    } catch (error, stackTrace) {
      debugPrint('[INICIO] Error: $error');
      debugPrintStack(stackTrace: stackTrace);

      _showError(
        error is StateError
            ? error.message.toString()
            : 'No pudimos recuperar tu acceso. '
                'Inténtalo nuevamente.',
      );
    } finally {
      _isRestoring = false;
    }
  }

  Future<String?> _findExistingCouple(String userId) async {
    final firestore = FirebaseFirestore.instance;

    const serverOptions = GetOptions(source: Source.server);

    final userReference = firestore.collection('users').doc(userId);

    final userSnapshot = await _runStep<DocumentSnapshot<Map<String, dynamic>>>(
      'Consultando tu perfil…',
      () => userReference.get(serverOptions),
    );

    final userData = userSnapshot.data();
    final rawCoupleId = userData?['coupleId'];

    if (rawCoupleId != null && rawCoupleId is! String) {
      throw StateError(
        'La conexión guardada en tu perfil no es válida.',
      );
    }

    final savedCoupleId = rawCoupleId is String ? rawCoupleId.trim() : '';

    if (savedCoupleId.isNotEmpty) {
      final coupleSnapshot =
          await _runStep<DocumentSnapshot<Map<String, dynamic>>>(
        'Validando tu bote…',
        () => firestore
            .collection('couples')
            .doc(savedCoupleId)
            .get(serverOptions),
      );

      final coupleData = coupleSnapshot.data();

      if (!coupleSnapshot.exists || coupleData == null) {
        throw StateError(
          'Tu perfil tiene un bote vinculado, '
          'pero no encontramos ese bote.',
        );
      }

      _validateCouple(
        data: coupleData,
        userId: userId,
      );

      return coupleSnapshot.id;
    }

    // Recupera la conexión si el bote existe pero el perfil
    // todavía no tiene guardado su identificador.
    final matchingCouples = await _runStep<QuerySnapshot<Map<String, dynamic>>>(
      'Buscando tu conexión…',
      () => firestore
          .collection('couples')
          .where('memberIds', arrayContains: userId)
          .get(serverOptions),
    );

    final activeCouples = matchingCouples.docs
        .where(
          (document) => document.data()['status'] == 'active',
        )
        .toList(growable: false);

    if (activeCouples.isEmpty) return null;

    if (activeCouples.length > 1) {
      throw StateError(
        'Encontramos más de un bote activo para tu usuario. '
        'Debemos revisar esas conexiones antes de continuar.',
      );
    }

    final coupleSnapshot = activeCouples.single;

    _validateCouple(
      data: coupleSnapshot.data(),
      userId: userId,
    );

    if (!userSnapshot.exists) {
      throw StateError(
        'Encontramos tu bote, pero falta tu perfil.',
      );
    }

    if (FirebaseAuth.instance.currentUser?.uid != userId) {
      throw StateError(
        'La sesión cambió. Intenta entrar nuevamente.',
      );
    }

    await _runStep<void>(
      'Recuperando el vínculo de tu perfil…',
      () => userReference.update({
        'coupleId': coupleSnapshot.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );

    return coupleSnapshot.id;
  }

  void _validateCouple({
    required Map<String, dynamic> data,
    required String userId,
  }) {
    if (data['status'] != 'active') {
      throw StateError('Tu bote vinculado no está activo.');
    }

    final rawMembers = data['memberIds'];

    if (rawMembers is! List ||
        rawMembers.length != 2 ||
        rawMembers.any((member) => member is! String)) {
      throw StateError(
        'Los miembros de tu bote no están configurados correctamente.',
      );
    }

    final members = rawMembers.cast<String>();

    if (members.toSet().length != 2 || !members.contains(userId)) {
      throw StateError(
        'No pudimos verificar tu pertenencia a este bote.',
      );
    }

    if (data['createdAt'] is! Timestamp) {
      throw StateError('Los datos de tu bote están incompletos.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _isLoading ? _buildLoading() : _buildError(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'nuestro · bote',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(
          color: AppColors.coral,
          strokeWidth: 2.4,
        ),
        const SizedBox(height: 18),
        Text(
          _loadingMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.link_off_rounded,
          color: AppColors.coral,
          size: 38,
        ),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? 'No pudimos recuperar tu acceso.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _restoreAccess,
          child: const Text('Intentar nuevamente'),
        ),
      ],
    );
  }
}
