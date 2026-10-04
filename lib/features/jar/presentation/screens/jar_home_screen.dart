import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../connection/data/firestore_connection_repository.dart';
import '../../../memories/presentation/screens/memories_screen.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../profile/domain/models/user_profile.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../wishes/data/firestore_wish_repository.dart';
import '../../../wishes/domain/models/wish.dart';
import '../../../wishes/presentation/screens/create_wish_screen.dart';
import '../../../wishes/presentation/screens/wish_detail_screen.dart';
import '../widgets/jar_bottom_navigation.dart';
import '../widgets/wish_jar_empty_illustration.dart';

class JarHomeScreen extends StatefulWidget {
  const JarHomeScreen({
    required this.coupleId,
    super.key,
  });

  final String coupleId;

  @override
  State<JarHomeScreen> createState() => _JarHomeScreenState();
}

class _JarHomeScreenState extends State<JarHomeScreen> {
  final _connections = FirestoreConnectionRepository();
  final _profiles = ProfileRepository();
  final _wishRepository = FirestoreWishRepository();

  StreamSubscription<List<Wish>>? _wishSubscription;
  StreamSubscription<UserProfile?>? _currentProfileSubscription;
  StreamSubscription<UserProfile?>? _partnerProfileSubscription;

  List<Wish> _wishes = [];

  UserProfile? _currentProfile;
  UserProfile? _partnerProfile;
  WishCategory? _selectedCategory;

  bool _isLoading = true;
  bool _isOpeningScreen = false;
  bool _isSaving = false;
  String? _error;

  List<Wish> get _pendingWishes =>
      _wishes.where((wish) => !wish.isCompleted).toList();

  List<Wish> get _completedWishes =>
      _wishes.where((wish) => wish.isCompleted).toList();

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _wishSubscription?.cancel();
    _currentProfileSubscription?.cancel();
    _partnerProfileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _wishSubscription?.cancel();
    await _currentProfileSubscription?.cancel();
    await _partnerProfileSubscription?.cancel();

    _wishSubscription = null;
    _currentProfileSubscription = null;
    _partnerProfileSubscription = null;

    if (!mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw StateError('No encontramos tu sesión.');
      }

      final couple = await _connections.getCouple(widget.coupleId);

      if (couple == null || !couple.containsUser(user.uid)) {
        throw StateError('No pudimos validar tu conexión.');
      }

      final partnerId = couple.partnerIdFor(user.uid);

      if (partnerId == null) {
        throw StateError('No encontramos a tu pareja.');
      }

      final profiles = await Future.wait<UserProfile?>([
        _profiles.getProfile(user.uid),
        _profiles.getProfile(partnerId),
      ]);

      if (profiles[0] == null || profiles[1] == null) {
        throw StateError('No pudimos cargar ambos perfiles.');
      }

      if (!mounted) return;

      _currentProfile = profiles[0];
      _partnerProfile = profiles[1];

      void handleProfileError(Object error) {
        if (!mounted) return;

        _showMessage(
          'No pudimos actualizar los perfiles. '
          '${wishErrorMessage(error)}',
        );
      }

      _currentProfileSubscription = _profiles.watchProfile(user.uid).listen(
        (profile) {
          if (!mounted) return;

          setState(() {
            _currentProfile = profile;
          });
        },
        onError: handleProfileError,
      );

      _partnerProfileSubscription = _profiles.watchProfile(partnerId).listen(
        (profile) {
          if (!mounted) return;

          setState(() {
            _partnerProfile = profile;
          });
        },
        onError: handleProfileError,
      );

      _currentProfileSubscription = _profiles.watchProfile(user.uid).listen(
        (profile) {
          if (!mounted) return;

          setState(() {
            _currentProfile = profile;
          });
        },
        onError: handleProfileError,
      );

      _partnerProfileSubscription = _profiles.watchProfile(partnerId).listen(
        (profile) {
          if (!mounted) return;

          setState(() {
            _partnerProfile = profile;
          });
        },
        onError: handleProfileError,
      );

      _wishSubscription = _wishRepository.watchWishes(widget.coupleId).listen(
        (wishes) {
          if (!mounted) return;

          setState(() {
            _wishes = wishes;
            _isLoading = false;
            _error = null;
          });
        },
        onError: (Object error) {
          if (!mounted) return;

          setState(() {
            _isLoading = false;
            _error = wishErrorMessage(error);
          });
        },
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = wishErrorMessage(error);
      });
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

  void _goBack() {
    if (_isOpeningScreen || _isSaving) return;

    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(
        AppRoutes.connectionSuccess,
        arguments: widget.coupleId,
      );
    }
  }

  void _selectDestination(int index) {
    if (_isOpeningScreen || _isSaving) return;

    if (index == 1) {
      _openMemories();
    } else if (index == 2) {
      _openProfile();
    }
  }

  Future<void> _openProfile() async {
    if (_isOpeningScreen || _isSaving) return;

    _isOpeningScreen = true;

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(
            coupleId: widget.coupleId,
          ),
        ),
      );
    } finally {
      _isOpeningScreen = false;
    }
  }

  Future<void> _openMemories({Wish? wish}) async {
    if (_isOpeningScreen || _isSaving) return;

    _isOpeningScreen = true;

    try {
      await Navigator.of(context).push<MemoriesResult>(
        MaterialPageRoute<MemoriesResult>(
          builder: (_) => MemoriesScreen(
            coupleId: widget.coupleId,
            wish: wish?.isCompleted == true ? wish : null,
          ),
        ),
      );
    } finally {
      _isOpeningScreen = false;
    }
  }

  Future<void> _openNewWish() async {
    if (_isOpeningScreen || _isSaving) return;

    final author = _currentProfile;

    if (author == null || FirebaseAuth.instance.currentUser?.uid != author.id) {
      _showMessage('No pudimos validar tu sesión.');
      return;
    }

    var openMemories = false;
    _isOpeningScreen = true;

    try {
      final draft = await Navigator.of(context).push<Wish>(
        MaterialPageRoute<Wish>(
          builder: (_) => CreateWishScreen(
            onOpenMemories: () {
              openMemories = true;
            },
          ),
        ),
      );

      if (!mounted) return;

      if (draft != null) {
        await _saveNewWish(draft, author.name);
      }
    } finally {
      _isOpeningScreen = false;
    }

    if (mounted && openMemories) {
      await _openMemories();
    }
  }

  Future<void> _saveNewWish(Wish draft, String authorName) async {
    // Mantiene el borrador mientras el usuario reintenta.
    var retry = true;

    while (mounted && retry) {
      setState(() {
        _isSaving = true;
      });

      try {
        await _wishRepository.createWish(
          coupleId: widget.coupleId,
          wish: draft,
          authorName: authorName,
        );

        if (!mounted) return;

        setState(() {
          _isSaving = false;
          _selectedCategory = null;
        });

        _showMessage('El deseo fue guardado en su bote.');
        return;
      } catch (error) {
        if (!mounted) return;

        setState(() {
          _isSaving = false;
        });

        retry = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: const Text(
                  'No pudimos guardar el deseo',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                content: Text(
                  wishErrorMessage(error),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Descartar borrador'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Intentar nuevamente'),
                  ),
                ],
              ),
            ) ??
            false;
      }
    }
  }

  Future<void> _openWishDetails(Wish wish) async {
    if (_isOpeningScreen || _isSaving) return;

    _isOpeningScreen = true;
    WishDetailResult? result;

    try {
      result = await Navigator.of(context).push<WishDetailResult>(
        MaterialPageRoute<WishDetailResult>(
          builder: (_) => WishDetailScreen(
            wish: wish,
            coupleId: widget.coupleId,
          ),
        ),
      );
    } finally {
      _isOpeningScreen = false;
    }

    if (!mounted || result == null) return;

    // La lista se actualiza mediante la escucha de Firestore.
    // El resultado solo controla la navegación a Recuerdos.
    if (result.addMemory && result.wish?.isCompleted == true) {
      await _openMemories(wish: result.wish);
    } else if (result.openMemories) {
      await _openMemories();
    }
  }

  UserProfile? _authorFor(Wish wish) {
    final profiles = <UserProfile>[
      if (_currentProfile != null) _currentProfile!,
      if (_partnerProfile != null) _partnerProfile!,
    ];

    for (final profile in profiles) {
      if (profile.id == wish.proposedByUserId) return profile;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.coral),
        ),
      );
    }

    final current = _currentProfile;
    final partner = _partnerProfile;

    if (_error != null || current == null || partner == null) {
      return _buildError();
    }

    final pending = _pendingWishes;
    final filtered = pending
        .where(
          (wish) =>
              _selectedCategory == null || wish.category == _selectedCategory,
        )
        .toList();

    final completedCount = _completedWishes.length;

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: JarBottomNavigation(
          selectedIndex: 0,
          onDestinationSelected: _selectDestination,
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox(
                width: double.infinity,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: [
                    _buildHeader(current, partner),
                    if (_isSaving) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(
                        color: AppColors.coral,
                        backgroundColor: AppColors.surface,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Guardando el deseo…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (pending.isEmpty)
                      ..._buildEmpty(current, partner)
                    else ...[
                      const Text(
                        'Nuestro bote',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 31,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Un lugar para todo lo que quieren vivir juntos.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(
                        height: 145,
                        child: CustomPaint(
                          painter: _PixelHeartPainter(),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${pending.length} '
                              '${pending.length == 1 ? 'deseo pendiente' : 'deseos pendientes'}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _openNewWish,
                            icon: const Icon(
                              Icons.add_rounded,
                              size: 18,
                            ),
                            label: const Text('Añadir deseo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.coral,
                              side: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildCategoryFilters(pending),
                      const SizedBox(height: 18),
                      if (filtered.isEmpty)
                        _buildEmptyCategory()
                      else
                        for (final wish in filtered) ...[
                          _WishCard(
                            wish: wish,
                            author: _authorFor(wish),
                            onTap: () => _openWishDetails(wish),
                          ),
                          const SizedBox(height: 14),
                        ],
                    ],
                    if (completedCount > 0) ...[
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: _openMemories,
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 19,
                        ),
                        label: Text(
                          'Ver $completedCount '
                          '${completedCount == 1 ? 'deseo cumplido' : 'deseos cumplidos'}',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.lavender,
                          side: const BorderSide(
                            color: AppColors.border,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters(List<Wish> pending) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _categoryChip('Todos (${pending.length})', null),
        for (final category in WishCategory.values)
          _categoryChip(
            '${category.label} '
            '(${pending.where((wish) => wish.category == category).length})',
            category,
          ),
      ],
    );
  }

  Widget _categoryChip(String label, WishCategory? category) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedCategory == category,
      onSelected: (_) {
        setState(() {
          _selectedCategory = category;
        });
      },
      selectedColor: AppColors.coral.withValues(alpha: 0.18),
      backgroundColor: AppColors.surface,
      checkmarkColor: AppColors.coral,
      side: BorderSide(
        color:
            _selectedCategory == category ? AppColors.coral : AppColors.border,
      ),
      labelStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 11,
      ),
    );
  }

  Widget _buildEmptyCategory() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Todavía no tienen deseos de '
        '${_selectedCategory?.label.toLowerCase() ?? 'esta categoría'}.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error ?? 'No pudimos cargar el bote.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Intentar nuevamente',
                  onPressed: _loadProfiles,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserProfile current, UserProfile partner) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            tooltip: 'Volver',
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
          const Expanded(
            child: Text(
              'nuestro · bote',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
              ),
            ),
          ),
          Tooltip(
            message: current.name,
            child: ProfileAvatar(
              profile: current,
              size: 32,
              borderColor: AppColors.pink,
            ),
          ),
          const SizedBox(width: 7),
          Tooltip(
            message: partner.name,
            child: ProfileAvatar(
              profile: partner,
              size: 32,
              borderColor: AppColors.lavender,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEmpty(UserProfile current, UserProfile partner) {
    final hasCompleted = _completedWishes.isNotEmpty;

    return [
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ProfileAvatar(
            profile: current,
            size: 44,
            borderColor: AppColors.pink,
          ),
          const SizedBox(width: 16),
          const Icon(
            Icons.link_rounded,
            color: AppColors.coral,
            size: 25,
          ),
          const SizedBox(width: 16),
          ProfileAvatar(
            profile: partner,
            size: 44,
            borderColor: AppColors.lavender,
          ),
        ],
      ),
      const SizedBox(height: 24),
      Text(
        hasCompleted
            ? 'Un nuevo deseo\nlos espera'
            : 'Este bote ya es\nde los dos',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 28,
          height: 1.05,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        hasCompleted
            ? 'Sus deseos cumplidos están en Recuerdos.'
            : 'Empiecen guardando algo que quieran vivir juntos.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 18),
      const Center(
        child: WishJarEmptyIllustration(size: 185),
      ),
      const SizedBox(height: 20),
      PrimaryButton(
        label: hasCompleted ? 'Guardar otro deseo' : 'Guardar primer deseo',
        onPressed: _openNewWish,
      ),
    ];
  }
}

class _WishCard extends StatelessWidget {
  const _WishCard({
    required this.wish,
    required this.author,
    required this.onTap,
  });

  final Wish wish;
  final UserProfile? author;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = author;

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.coral, width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wish.category.label.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.coral,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                wish.description,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.textSecondary,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Antes del ${_formatDate(wish.dueDate)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  if (profile != null)
                    ProfileAvatar(
                      profile: profile,
                      size: 32,
                      borderColor: AppColors.coral,
                    )
                  else
                    const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textSecondary,
                      size: 32,
                    ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      profile?.name ?? wish.proposedBy,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Text(
                    wish.statusLabel,
                    style: const TextStyle(
                      color: AppColors.lavender,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$day/$month/${date.year}';
}

class _PixelHeartPainter extends CustomPainter {
  const _PixelHeartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 45;

    final soft = Paint()..color = AppColors.lavender.withValues(alpha: 0.20);

    final coral = Paint()..color = AppColors.coral.withValues(alpha: 0.80);

    final lavender = Paint()
      ..color = AppColors.lavender.withValues(alpha: 0.75);

    void pixel(double x, double y, Paint paint) {
      canvas.drawRect(
        Rect.fromLTWH(x, y, unit * 0.84, unit * 0.84),
        paint,
      );
    }

    const trail = [
      Offset(0.2, 6.7),
      Offset(3, 8.4),
      Offset(6.2, 10.3),
      Offset(9.4, 9.2),
      Offset(12.6, 11.9),
      Offset(16.2, 10.7),
      Offset(19.7, 13.1),
      Offset(23, 11.4),
      Offset(26, 13.7),
    ];

    for (var index = 0; index < trail.length; index++) {
      final point = trail[index];

      pixel(
        point.dx * unit,
        point.dy * unit,
        index.isEven ? coral : soft,
      );
    }

    const heart = [
      Offset(4, 1),
      Offset(5, 1),
      Offset(6, 1),
      Offset(10, 1),
      Offset(11, 1),
      Offset(12, 1),
      Offset(3, 2),
      Offset(7, 2),
      Offset(9, 2),
      Offset(13, 2),
      Offset(2, 3),
      Offset(8, 3),
      Offset(14, 3),
      Offset(2, 4),
      Offset(14, 4),
      Offset(2, 5),
      Offset(14, 5),
      Offset(2, 6),
      Offset(14, 6),
      Offset(3, 7),
      Offset(13, 7),
      Offset(4, 8),
      Offset(12, 8),
      Offset(5, 9),
      Offset(11, 9),
      Offset(6, 10),
      Offset(10, 10),
      Offset(7, 11),
      Offset(9, 11),
      Offset(8, 12),
    ];

    final originX = size.width - 18 * unit;

    for (var index = 0; index < heart.length; index++) {
      final point = heart[index];

      pixel(
        originX + point.dx * unit,
        unit * 0.4 + point.dy * unit,
        index == 17 ? coral : (index == 22 ? lavender : soft),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PixelHeartPainter oldDelegate) => false;
}
