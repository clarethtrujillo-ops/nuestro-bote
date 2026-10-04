import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show PointerDeviceKind;

import '../../../../app/theme/app_theme.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/models/user_profile.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    required this.destinationRoute,
    super.key,
  });

  final String destinationRoute;

  @override
  State<ProfileSetupScreen> createState() {
    return _ProfileSetupScreenState();
  }
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();

  final ProfileRepository _profileRepository = ProfileRepository();

  static const List<String> _avatarSeeds = [
    'classic-coral',
    'alex-lavender',
    'luna-warm',
    'mateo-night',
    'sofia-blush',
    'nico-magic',
    'avatar-coral',
    'avatar-sunglasses',
    'avatar_12',
  ];

  String _selectedAvatarSeed = _avatarSeeds.first;

  UserProfile? _existingProfile;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'No fue posible identificar al usuario.',
      );

      return;
    }

    try {
      final profile = await _profileRepository.getProfile(
        user.uid,
      );

      if (!mounted) return;

      if (profile != null) {
        _existingProfile = profile;
        _nameController.text = profile.name;

        if (_avatarSeeds.contains(profile.avatarSeed)) {
          _selectedAvatarSeed = profile.avatarSeed;
        }
      }
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'No pudimos cargar tu perfil.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (name.length < 2) {
      _showMessage(
        'Escribe un nombre de al menos dos caracteres.',
      );
      return;
    }

    if (user == null) {
      _showMessage(
        'No fue posible identificar al usuario.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final profile = UserProfile(
        id: user.uid,
        name: name,
        avatarSeed: _selectedAvatarSeed,
        coupleId: _existingProfile?.coupleId,
      );

      await _profileRepository.saveProfile(profile);

      if (!mounted) return;

      await Navigator.of(context).pushReplacementNamed(
        widget.destinationRoute,
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'No pudimos guardar tu perfil. Inténtalo nuevamente.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _selectAvatar(String avatarSeed) {
    if (_isSaving) return;

    setState(() {
      _selectedAvatarSeed = avatarSeed;
    });
  }

  void _goBack() {
    if (_isSaving) return;

    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  String _avatarAsset(String avatarSeed) {
    return 'assets/avatars/$avatarSeed.png';
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
    final mediaQuery = MediaQuery.of(context);

    final keyboardVisible = mediaQuery.viewInsets.bottom > 0;

    final compact = mediaQuery.size.height < 760;

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.stylus,
              PointerDeviceKind.trackpad,
            },
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 430,
                ),
                child: _isLoading
                    ? const _LoadingView()
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          keyboardVisible ? 28 : 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ProfileHeader(
                              onBack: _goBack,
                            ),
                            SizedBox(
                              height: keyboardVisible
                                  ? 16
                                  : compact
                                      ? 20
                                      : 28,
                            ),
                            Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(
                                  milliseconds: 220,
                                ),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: _SelectedAvatarPreview(
                                  key: ValueKey(
                                    _selectedAvatarSeed,
                                  ),
                                  avatarAsset: _avatarAsset(
                                    _selectedAvatarSeed,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: keyboardVisible ? 18 : 24,
                            ),
                            const Center(
                              child: Text(
                                'Hazlo tuyo',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 29,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            const Center(
                              child: Text(
                                'Elige cómo aparecerás en tu bote.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                            const Text(
                              '¿Cómo quieres que te llamemos?',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameController,
                              enabled: !_isSaving,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.done,
                              maxLength: 24,
                              onSubmitted: (_) {
                                _saveProfile();
                              },
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Tu nombre',
                                counterText: '',
                                hintStyle: const TextStyle(
                                  color: AppColors.inactive,
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    13,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    13,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    13,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.coral,
                                    width: 1.3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'ELIGE TU AVATAR',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.7,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _AvatarGrid(
                              avatarSeeds: _avatarSeeds,
                              selectedAvatarSeed: _selectedAvatarSeed,
                              avatarAssetBuilder: _avatarAsset,
                              onSelected: _selectAvatar,
                            ),
                            const SizedBox(height: 26),
                            _SaveProfileButton(
                              loading: _isSaving,
                              onPressed: _isSaving ? null : _saveProfile,
                            ),
                            const SizedBox(height: 11),
                            const Center(
                              child: Text(
                                'Podrás cambiarlo más adelante.',
                                style: TextStyle(
                                  color: AppColors.inactive,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 65,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: onBack,
              tooltip: 'Volver',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
          ),
          const Positioned(
            top: 10,
            child: Text(
              'nuestro · bote',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
          ),
          Positioned(
            left: 42,
            right: 0,
            bottom: 5,
            child: Stack(
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: 0.42,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.coral,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedAvatarPreview extends StatelessWidget {
  const _SelectedAvatarPreview({
    required this.avatarAsset,
    super.key,
  });

  final String avatarAsset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 150,
          height: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.coral,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.coral.withValues(
                  alpha: 0.10,
                ),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              avatarAsset,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return const _AvatarError();
              },
            ),
          ),
        ),
        Positioned(
          top: -7,
          right: -7,
          child: Container(
            width: 35,
            height: 35,
            decoration: const BoxDecoration(
              color: AppColors.coral,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.background,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarGrid extends StatelessWidget {
  const _AvatarGrid({
    required this.avatarSeeds,
    required this.selectedAvatarSeed,
    required this.avatarAssetBuilder,
    required this.onSelected,
  });

  final List<String> avatarSeeds;
  final String selectedAvatarSeed;
  final String Function(String seed) avatarAssetBuilder;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      primary: false,
      itemCount: avatarSeeds.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 11,
        crossAxisSpacing: 11,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final seed = avatarSeeds[index];

        final selected = seed == selectedAvatarSeed;

        return _AvatarOption(
          avatarAsset: avatarAssetBuilder(seed),
          selected: selected,
          onPressed: () {
            onSelected(seed);
          },
        );
      },
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.avatarAsset,
    required this.selected,
    required this.onPressed,
  });

  final String avatarAsset;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.coral : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    avatarAsset,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return const _AvatarError(
                        iconSize: 30,
                      );
                    },
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.coral,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.background,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarError extends StatelessWidget {
  const _AvatarError({
    this.iconSize = 42,
  });

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.elevated,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline_rounded,
        color: AppColors.textSecondary,
        size: iconSize,
      ),
    );
  }
}

class _SaveProfileButton extends StatelessWidget {
  const _SaveProfileButton({
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 53,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.coral,
          disabledBackgroundColor: AppColors.coral.withValues(
            alpha: 0.55,
          ),
          foregroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.background,
                  strokeWidth: 2.3,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Guardar y continuar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 9),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                  ),
                ],
              ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.coral,
        strokeWidth: 2.4,
      ),
    );
  }
}
