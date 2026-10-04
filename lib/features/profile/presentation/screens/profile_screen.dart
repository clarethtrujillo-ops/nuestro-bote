import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/profile_avatar.dart';
import '../../../connection/presentation/screens/manage_connection_screen.dart';
import '../../../memories/presentation/screens/memories_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.coupleId,
    super.key,
  });

  final String coupleId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repository = ProfileRepository();

  late final Stream<UserProfile?>? _profileStream;

  bool _openingEditor = false;

  @override
  void initState() {
    super.initState();

    final userId = FirebaseAuth.instance.currentUser?.uid;

    _profileStream = userId == null ? null : _repository.watchProfile(userId);
  }

  Future<void> _editProfile(UserProfile profile) async {
    if (_openingEditor) return;

    _openingEditor = true;

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _EditProfileScreen(
            profile: profile,
            repository: _repository,
          ),
        ),
      );
    } finally {
      _openingEditor = false;
    }
  }

  Future<void> _manageConnection() async {
    if (_openingEditor) return;

    _openingEditor = true;
    int? destination;

    try {
      destination = await Navigator.of(context).push<int>(
        MaterialPageRoute<int>(
          builder: (_) => ManageConnectionScreen(
            coupleId: widget.coupleId,
          ),
        ),
      );
    } finally {
      _openingEditor = false;
    }

    if (!mounted) return;

    if (destination == 0) {
      Navigator.of(context).pop();
    } else if (destination == 1) {
      await Navigator.of(context).push<MemoriesResult>(
        MaterialPageRoute<MemoriesResult>(
          builder: (_) => MemoriesScreen(
            coupleId: widget.coupleId,
          ),
        ),
      );
    }
  }

  Future<void> _openNotifications() async {
    if (_openingEditor) return;

    _openingEditor = true;

    try {
      final destination = await Navigator.of(context).push<int>(
        MaterialPageRoute<int>(
          builder: (_) => const NotificationsScreen(),
        ),
      );

      if (!mounted) return;

      if (destination == 0) {
        Navigator.of(context).pop();
      } else if (destination == 1) {
        await Navigator.of(context).push<MemoriesResult>(
          MaterialPageRoute<MemoriesResult>(
            builder: (_) => MemoriesScreen(
              coupleId: widget.coupleId,
            ),
          ),
        );
      }
    } finally {
      _openingEditor = false;
    }
  }

  Widget _message(String text) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tu perfil'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: StreamBuilder<UserProfile?>(
              stream: _profileStream,
              builder: (context, snapshot) {
                if (_profileStream == null) {
                  return _message(
                    'Tu sesión terminó. Vuelve a entrar.',
                  );
                }

                if (snapshot.hasError) {
                  return _message(
                    'No pudimos cargar tu perfil. '
                    'Vuelve a abrir esta pantalla.',
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.coral,
                    ),
                  );
                }

                final profile = snapshot.data;

                if (profile == null || profile.coupleId != widget.coupleId) {
                  return _message(
                    'No encontramos tu perfil vinculado al bote.',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 28),
                    Center(
                      child: ProfileAvatar(
                        profile: profile,
                        size: 110,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      profile.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Así apareces en tu bote.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 30),
                    FilledButton.icon(
                      onPressed: () => _editProfile(profile),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text(
                        'Editar nombre y avatar',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _openNotifications,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(
                          color: AppColors.border,
                        ),
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: const Icon(
                        Icons.notifications_outlined,
                      ),
                      label: const Text('Notificaciones'),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _manageConnection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(
                          color: AppColors.border,
                        ),
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: const Icon(
                        Icons.link_rounded,
                        color: AppColors.lavender,
                      ),
                      label: const Text('Gestionar conexión'),
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

class _EditProfileScreen extends StatefulWidget {
  const _EditProfileScreen({
    required this.profile,
    required this.repository,
  });

  final UserProfile profile;
  final ProfileRepository repository;

  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  static const _avatarSeeds = [
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

  late final TextEditingController _nameController;
  late String _selectedAvatarSeed;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.profile.name,
    );

    _selectedAvatarSeed =
    widget.profile.avatarSeed == 'danna-coral'
        ? 'classic-coral'
        : widget.profile.avatarSeed;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  Future<void> _save() async {
    if (_saving) return;

    final user = FirebaseAuth.instance.currentUser;
    final name = _nameController.text.trim();

    if (user == null || user.uid != widget.profile.id) {
      _showMessage(
        'Tu sesión cambió. Vuelve a abrir el perfil.',
      );
      return;
    }

    if (name.length < 2 || name.length > 24) {
      _showMessage(
        'Escribe un nombre de 2 a 24 caracteres.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
    });

    try {
      await widget.repository.updateDetails(
        userId: user.uid,
        name: name,
        avatarSeed: _selectedAvatarSeed,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error is StateError
            ? error.message.toString()
            : 'No pudimos guardar los cambios. '
                'Revisa la conexión y los permisos de Firebase.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.profile.copyWith(
      avatarSeed: _selectedAvatarSeed,
    );

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Editar perfil'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          automaticallyImplyLeading: !_saving,
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: ListView(
                padding: const EdgeInsets.all(24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Center(
                    child: ProfileAvatar(
                      profile: preview,
                      size: 100,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Tu nombre',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    enabled: !_saving,
                    maxLength: 24,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'ELIGE TU AVATAR',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _avatarSeeds.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final seed = _avatarSeeds[index];
                      final selected = seed == _selectedAvatarSeed;

                      return Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _saving
                              ? null
                              : () {
                                  setState(() {
                                    _selectedAvatarSeed = seed;
                                  });
                                },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? AppColors.coral
                                    : AppColors.border,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/avatars/$seed.png',
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.none,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person_outline_rounded,
                                  color: AppColors.textSecondary,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Text(
                      _saving ? 'Guardando…' : 'Guardar cambios',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
