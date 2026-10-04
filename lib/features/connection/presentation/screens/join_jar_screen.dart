import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/connection_repository.dart';
import '../../data/firestore_connection_repository.dart';
class JoinJarScreen extends StatefulWidget {
  const JoinJarScreen({super.key});

  @override
  State<JoinJarScreen> createState() {
    return _JoinJarScreenState();
  }
}

class _JoinJarScreenState
    extends State<JoinJarScreen> {
  static const int _codeLength = 6;

  final TextEditingController _controller =
      TextEditingController();

  final FocusNode _focusNode = FocusNode();

  final FirestoreConnectionRepository
      _connectionRepository =
      FirestoreConnectionRepository();

  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();

    _focusNode.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pasteCode() async {
    if (_isConnecting) return;

    final clipboard = await Clipboard.getData(
      Clipboard.kTextPlain,
    );

    final value = (clipboard?.text ?? '')
        .replaceAll(
          RegExp(r'[^a-zA-Z0-9]'),
          '',
        )
        .toUpperCase();

    if (value.isEmpty) {
      _showMessage(
        'El portapapeles no contiene un código.',
      );
      return;
    }

    final clippedLength =
        value.length > _codeLength
            ? _codeLength
            : value.length;

    _controller.value = TextEditingValue(
      text: value.substring(
        0,
        clippedLength,
      ),
      selection: TextSelection.collapsed(
        offset: clippedLength,
      ),
    );

    _focusNode.requestFocus();
  }

  Future<void> _connect() async {
    if (_isConnecting) return;

    final code = _controller.text
        .trim()
        .toUpperCase();

    if (code.length != _codeLength) {
      _showMessage(
        'Introduce los seis caracteres del código.',
      );

      _focusNode.requestFocus();
      return;
    }

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'No fue posible identificar al usuario.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isConnecting = true;
    });

    try {
      final coupleId =
          await _connectionRepository.joinWithCode(
        code: code,
        joiningUserId: user.uid,
      );

      if (!mounted) return;

      await Navigator.of(context)
          .pushReplacementNamed(
        AppRoutes.connectionSuccess,
        arguments: coupleId,
      );
    } on ConnectionFailure catch (error) {
      if (!mounted) return;

      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'No pudimos completar la conexión. Revisa tu conexión e inténtalo nuevamente.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
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
    final keyboardVisible =
        MediaQuery.viewInsetsOf(context).bottom > 0;

    final codeComplete =
        _controller.text.length == _codeLength;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: !keyboardVisible,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 430,
            ),
            child: LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter:
                              _MagicJarBackground(
                            compact:
                                keyboardVisible,
                          ),
                        ),
                      ),
                    ),
                    AnimatedPadding(
                      duration: const Duration(
                        milliseconds: 220,
                      ),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        keyboardVisible ? 4 : 10,
                        16,
                        keyboardVisible ? 10 : 22,
                      ),
                      child: Column(
                        children: [
                          _Header(
                            onBack: _isConnecting
                                ? () {}
                                : () {
                                    Navigator.of(
                                      context,
                                    ).pop();
                                  },
                          ),
                          SizedBox(
                            height:
                                keyboardVisible
                                    ? 10
                                    : 34,
                          ),
                          const Text(
                            'Introduce el código',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              color: AppColors
                                  .textPrimary,
                              fontSize: 25,
                              height: 1.05,
                              fontWeight:
                                  FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(
                            height:
                                keyboardVisible
                                    ? 5
                                    : 9,
                          ),
                          const Text(
                            'Pídele a tu pareja el código que aparece\n'
                            'en su pantalla.',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              color: AppColors
                                  .textSecondary,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(
                            height:
                                keyboardVisible
                                    ? 14
                                    : 27,
                          ),
                          GestureDetector(
                            onTap: _isConnecting
                                ? null
                                : _focusNode
                                    .requestFocus,
                            behavior:
                                HitTestBehavior
                                    .opaque,
                            child: _CodeBoxes(
                              value:
                                  _controller.text,
                            ),
                          ),
                          SizedBox(
                            height:
                                keyboardVisible
                                    ? 5
                                    : 12,
                          ),
                          TextButton(
                            onPressed:
                                _isConnecting
                                    ? null
                                    : _pasteCode,
                            style:
                                TextButton.styleFrom(
                              foregroundColor:
                                  AppColors.coral,
                              minimumSize:
                                  const Size(
                                100,
                                36,
                              ),
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 8,
                              ),
                              textStyle:
                                  const TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    FontWeight.w500,
                              ),
                            ),
                            child: const Text(
                              'Pegar código',
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment:
                                  Alignment
                                      .bottomCenter,
                              child:
                                  AnimatedOpacity(
                                duration:
                                    const Duration(
                                  milliseconds: 180,
                                ),
                                opacity:
                                    codeComplete
                                        ? 1
                                        : 0.55,
                                child:
                                    AbsorbPointer(
                                  absorbing:
                                      !codeComplete ||
                                      _isConnecting,
                                  child:
                                      PrimaryButton(
                                    label:
                                        _isConnecting
                                            ? 'Conectando…'
                                            : 'Conectar con mi pareja',
                                    onPressed:
                                        _connect,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: SizedBox(
                        width: 1,
                        height: 1,
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            controller:
                                _controller,
                            focusNode: _focusNode,
                            enabled:
                                !_isConnecting,
                            autofocus: false,
                            autocorrect: false,
                            enableSuggestions:
                                false,
                            textCapitalization:
                                TextCapitalization
                                    .characters,
                            keyboardType:
                                TextInputType.text,
                            textInputAction:
                                TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .allow(
                                RegExp(
                                  r'[a-zA-Z0-9]',
                                ),
                              ),
                              LengthLimitingTextInputFormatter(
                                _codeLength,
                              ),
                              _UpperCaseFormatter(),
                            ],
                            onSubmitted: (_) {
                              _connect();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: onBack,
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              color: AppColors.textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
          const Positioned(
            top: 31,
            child: Text(
              'nuestro · bote',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
            ),
          ),
          Positioned(
            top: 22,
            left: 28,
            right: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: const LinearProgressIndicator(
                value: .64,
                minHeight: 4,
                backgroundColor: AppColors.elevated,
                valueColor: AlwaysStoppedAnimation(AppColors.coral),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_JoinJarScreenState._codeLength, (index) {
        final character = index < value.length ? value[index] : '';
        final activeIndex = value.length > 5 ? 5 : value.length;
        final active =
            index == activeIndex || (value.length == 6 && index == 5);

        return Container(
          width: 40,
          height: 46,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x7A29212C),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: active ? AppColors.coral : AppColors.border,
              width: active ? 1.2 : 1,
            ),
          ),
          child: Text(
            character,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _MagicJarBackground extends CustomPainter {
  const _MagicJarBackground({required this.compact});

  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    const pixel = 6.0;
    final dark = Paint()
      ..color = const Color(0xFF312936)
      ..isAntiAlias = false;
    final darker = Paint()
      ..color = const Color(0xFF28212C)
      ..isAntiAlias = false;
    final accent = Paint()
      ..color = const Color(0xFF4A3040)
      ..isAntiAlias = false;

    void block(double x, double y, Paint paint, [double scale = 1]) {
      canvas.drawRect(
        Rect.fromLTWH(x, y, pixel * scale, pixel * scale),
        paint,
      );
    }

    // Partículas separadas de la composición principal.
    final particles = <Offset>[
      Offset(size.width * .60, 16),
      Offset(size.width * .08, 82),
      Offset(size.width * .93, 64),
      Offset(size.width * .05, 154),
      Offset(size.width * .91, 252),
      Offset(size.width * .08, size.height * .66),
      Offset(size.width * .38, size.height * .86),
    ];
    for (var i = 0; i < particles.length; i++) {
      block(particles[i].dx, particles[i].dy, i.isEven ? dark : accent);
    }

    // Humo mágico: una cinta pixelada ancha que baja por el lateral derecho.
    final smoke = <Offset>[
      const Offset(.83, -.04),
      const Offset(.75, .03),
      const Offset(.72, .09),
      const Offset(.78, .15),
      const Offset(.85, .21),
      const Offset(.91, .27),
      const Offset(.88, .34),
      const Offset(.81, .40),
      const Offset(.75, .46),
      const Offset(.70, .52),
      const Offset(.74, .58),
      const Offset(.82, .64),
      const Offset(.88, .70),
      const Offset(.84, .76),
      const Offset(.78, .81),
    ];

    for (var segment = 0; segment < smoke.length - 1; segment++) {
      final a = smoke[segment];
      final b = smoke[segment + 1];
      for (var t = 0.0; t <= 1; t += .12) {
        final x = (a.dx + (b.dx - a.dx) * t) * size.width;
        final y = (a.dy + (b.dy - a.dy) * t) * size.height;
        block(x, y, segment.isEven ? darker : dark, 2.2);
        block(x + 12, y + 5, darker, 1.7);
      }
    }

    // Bote lateral inferior derecho.
    final centerX = size.width * .79;
    final baseY = size.height - (compact ? 2 : 24);
    final jarScale = compact ? .72 : 1.0;
    for (var i = -5; i <= 5; i++) {
      block(centerX + i * pixel * jarScale, baseY - 94 * jarScale, dark,
          jarScale);
      block(centerX + i * pixel * jarScale, baseY - 86 * jarScale, dark,
          jarScale);
    }
    for (var i = 0; i < 7; i++) {
      block(centerX - (42 + i * 4) * jarScale, baseY - (77 - i * 7) * jarScale,
          dark, 1.5 * jarScale);
      block(centerX + (36 + i * 4) * jarScale, baseY - (77 - i * 7) * jarScale,
          dark, 1.5 * jarScale);
    }
    for (double offset = 42; offset >= 5; offset -= 8) {
      block(centerX - 66 * jarScale, baseY - offset * jarScale, dark,
          1.5 * jarScale);
      block(centerX + 60 * jarScale, baseY - offset * jarScale, dark,
          1.5 * jarScale);
    }
  }

  @override
  bool shouldRepaint(covariant _MagicJarBackground oldDelegate) {
    return oldDelegate.compact != compact;
  }
}
