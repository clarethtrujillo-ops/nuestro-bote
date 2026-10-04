import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../jar/presentation/widgets/jar_bottom_navigation.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../profile/domain/models/user_profile.dart';
import '../../domain/models/wish.dart';
import '../widgets/wish_form_section.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class CreateWishScreen extends StatefulWidget {
  const CreateWishScreen({
    this.initialWish,
    this.onOpenMemories,
    super.key,
  });

  final Wish? initialWish;
  final VoidCallback? onOpenMemories;

  @override
  State<CreateWishScreen> createState() => _CreateWishScreenState();
}

class _CreateWishScreenState extends State<CreateWishScreen> {
  final _wishController = TextEditingController();
  final _noteController = TextEditingController();
  final _profileRepository = ProfileRepository();

  String _selectedCategory = 'Experiencia';
  DateTime? _selectedDate;

  UserProfile? _currentProfile;
  UserProfile? _authorProfile;

  bool _isLoadingProfile = true;
  bool _openingProfile = false;
  String? _profileError;

  bool get _isEditing => widget.initialWish != null;

  String get _proposerName {
    return _authorProfile?.name.trim() ??
        widget.initialWish?.proposedBy ??
        _currentProfile?.name.trim() ??
        '';
  }

  @override
  void initState() {
    super.initState();

    final wish = widget.initialWish;

    if (wish != null) {
      _wishController.text = wish.description;
      _noteController.text = wish.note ?? '';
      _selectedCategory = wish.category.label;
      _selectedDate = wish.dueDate;
    }

    _loadProfiles();
  }

  @override
  void dispose() {
    _wishController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw StateError('No fue posible identificar al usuario.');
      }

      final currentProfile = await _profileRepository.getProfile(user.uid);

      if (currentProfile == null || currentProfile.name.trim().isEmpty) {
        throw StateError('No encontramos tu perfil completo.');
      }

      final initialWish = widget.initialWish;
      UserProfile? authorProfile;

      if (initialWish == null) {
        authorProfile = currentProfile;
      } else {
        final authorId = initialWish.proposedByUserId;

        if (authorId == user.uid) {
          authorProfile = currentProfile;
        } else if (authorId != null && authorId.isNotEmpty) {
          authorProfile = await _profileRepository.getProfile(authorId);
        } else if (initialWish.proposedBy.trim() ==
            currentProfile.name.trim()) {
          // Compatibilidad con deseos anteriores que no guardaban el UID.
          authorProfile = currentProfile;
        }
      }

      if (!mounted) return;

      setState(() {
        _currentProfile = currentProfile;
        _authorProfile = authorProfile;
        _isLoadingProfile = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
        _profileError = error is StateError
            ? error.message.toString()
            : 'No pudimos cargar los perfiles.';
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
    FocusScope.of(context).unfocus();

    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop<Wish>();
    } else {
      _showMessage('Abre esta pantalla desde tu bote para regresar a él.');
    }
  }

    Future<void> _openProfile() async {
    if (_openingProfile || _isLoadingProfile) return;

    final profile = _currentProfile;
    final user = FirebaseAuth.instance.currentUser;
    final coupleId = profile?.coupleId;

    if (profile == null ||
        user == null ||
        profile.id != user.uid ||
        coupleId == null ||
        coupleId.isEmpty) {
      _showMessage(
        'No encontramos tu perfil vinculado al bote.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    _openingProfile = true;

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(
            coupleId: coupleId,
          ),
        ),
      );

      if (!mounted) return;

      // Actualiza el nombre si fue editado desde Perfil.
      // Los campos del deseo conservan lo que escribiste.
      await _loadProfiles();
    } finally {
      _openingProfile = false;
    }
  }

  void _selectNavigation(int index) {
    if (_openingProfile) return;

    if (index == 0) {
      _goBack();
      return;
    }

    if (index == 1) {
      final openMemories = widget.onOpenMemories;
      final navigator = Navigator.of(context);

      if (openMemories == null || !navigator.canPop()) {
        _showMessage(
          'Vuelve al bote para abrir tus recuerdos.',
        );
        return;
      }

      FocusScope.of(context).unfocus();
      openMemories();
      navigator.pop<Wish>();
      return;
    }

    if (index == 2) {
      _openProfile();
    }
  }

  Future<void> _selectDate() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(now.year + 5, 12, 31);

    final selected = _selectedDate;
    var initialDate = selected == null
        ? today.add(const Duration(days: 1))
        : DateTime(selected.year, selected.month, selected.day);

    if (initialDate.isBefore(today)) initialDate = today;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: lastDate,
      helpText: 'FECHA PARA CUMPLIRLO',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.coral,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted || date == null) return;

    setState(() {
      _selectedDate = date;
    });
  }

  void _saveWish() {
    FocusScope.of(context).unfocus();

    final user = FirebaseAuth.instance.currentUser;

    if (_isLoadingProfile) {
      _showMessage('Espera mientras cargamos tu perfil.');
      return;
    }

    if (user == null ||
        _currentProfile == null ||
        _currentProfile!.id != user.uid ||
        _profileError != null) {
      _showMessage('Carga tu perfil antes de guardar el deseo.');
      return;
    }

    final description = _wishController.text.trim();
    final note = _noteController.text.trim();

    if (description.isEmpty) {
      _showMessage('Escribe el deseo que quieren guardar.');
      return;
    }

    if (_selectedDate == null) {
      _showMessage('Elige una fecha para cumplir el deseo.');
      return;
    }

    if (_proposerName.trim().isEmpty) {
      _showMessage('No pudimos identificar al autor del deseo.');
      return;
    }

    final navigator = Navigator.of(context);

    if (!navigator.canPop()) {
      _showMessage('Abre esta pantalla desde tu bote para guardar el deseo.');
      return;
    }

    final category = switch (_selectedCategory) {
      'Plan' => WishCategory.plan,
      'Detalle' => WishCategory.detail,
      _ => WishCategory.experience,
    };

    final initialWish = widget.initialWish;

    final wish = initialWish != null
        ? initialWish.copyWith(
            description: description,
            category: category,
            dueDate: _selectedDate!,
            note: note.isEmpty ? null : note,
            removeNote: note.isEmpty,
          )
        : Wish(
            description: description,
            category: category,
            dueDate: _selectedDate!,
            proposedBy: _proposerName,
            proposedByUserId: user.uid,
            createdAt: DateTime.now(),
            note: note.isEmpty ? null : note,
          );

    navigator.pop<Wish>(wish);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    final profileReady =
        !_isLoadingProfile && _profileError == null && _currentProfile != null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      bottomNavigationBar: _BottomArea(
        label: _isEditing ? 'Guardar cambios' : 'Guardar en el bote',
        showSave: profileReady,
        showNavigation: !keyboardVisible,
        onSave: _saveWish,
        onDestinationSelected: _selectNavigation,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox.expand(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox(
                width: double.infinity,
                child: _isLoadingProfile
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.coral,
                          strokeWidth: 2.4,
                        ),
                      )
                    : !profileReady
                        ? Center(child: _buildProfileError())
                        : ListView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              18,
                              16,
                              24,
                            ),
                            children: [
                              Text(
                                _isEditing
                                    ? 'Editar deseo'
                                    : 'Guardar un deseo',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 24,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                _isEditing
                                    ? 'Actualiza los detalles que necesiten.'
                                    : 'Algo que quieran vivir, crear o recordar juntos.',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 20),
                              WishFormSection(
                                controller: _wishController,
                                noteController: _noteController,
                                selectedCategory: _selectedCategory,
                                selectedProposer: _proposerName,
                                proposerProfile: _authorProfile,
                                selectedDate: _selectedDate,
                                onCategoryChanged: (category) {
                                  setState(() {
                                    _selectedCategory = category;
                                  });
                                },
                                onSelectDate: _selectDate,
                              ),
                            ],
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_outline_rounded,
            color: AppColors.coral,
            size: 38,
          ),
          const SizedBox(height: 14),
          Text(
            _profileError ?? 'No pudimos cargar tu perfil.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Intentar nuevamente',
            onPressed: _loadProfiles,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 64,
      leading: IconButton(
        onPressed: _goBack,
        tooltip: 'Volver',
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textPrimary,
          size: 20,
        ),
      ),
      title: const Text(
        'nuestro · bote',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.8,
        ),
      ),
      centerTitle: true,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(3),
        child: SizedBox(
          width: 62,
          child: Divider(
            height: 3,
            thickness: 2,
            color: AppColors.coral,
          ),
        ),
      ),
    );
  }
}

class _BottomArea extends StatelessWidget {
  const _BottomArea({
    required this.label,
    required this.showSave,
    required this.showNavigation,
    required this.onSave,
    required this.onDestinationSelected,
  });

  final String label;
  final bool showSave;
  final bool showNavigation;
  final VoidCallback onSave;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      // La navegación ya controla su espacio inferior.
      bottom: !showNavigation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSave)
            Align(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _PrivacyMessage(),
                      const SizedBox(height: 10),
                      PrimaryButton(
                        label: label,
                        onPressed: onSave,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (showNavigation) ...[
            const Divider(height: 1, color: AppColors.border),
            JarBottomNavigation(
              selectedIndex: 0,
              onDestinationSelected: onDestinationSelected,
            ),
          ],
        ],
      ),
    );
  }
}

class _PrivacyMessage extends StatelessWidget {
  const _PrivacyMessage();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 14,
          color: AppColors.textSecondary,
        ),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Solo ustedes podrán ver este deseo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
