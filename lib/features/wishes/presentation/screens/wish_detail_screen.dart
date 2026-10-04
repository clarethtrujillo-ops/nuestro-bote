import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../connection/data/firestore_connection_repository.dart';
import '../../../jar/presentation/widgets/jar_bottom_navigation.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../../profile/domain/models/user_profile.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../data/firestore_wish_repository.dart';
import '../../domain/models/wish.dart';
import 'create_wish_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class WishDetailScreen extends StatefulWidget {
  const WishDetailScreen({
    required this.wish,
    this.coupleId,
    super.key,
  });

  final Wish wish;
  final String? coupleId;

  @override
  State<WishDetailScreen> createState() => _WishDetailScreenState();
}

class _WishDetailScreenState extends State<WishDetailScreen> {
  final _profiles = ProfileRepository();
  final _connections = FirestoreConnectionRepository();
  final _repository = FirestoreWishRepository();

  StreamSubscription<Wish?>? _subscription;

  late Wish _wish;
  String? _coupleId;

  UserProfile? _currentProfile;
  UserProfile? _partnerProfile;

  bool _isLoading = true;
  bool _busy = false;
  bool _openingProfile = false;
  bool _dialogOpen = false;
  bool _missing = false;
  bool _deleting = false;

  String? _error;

  bool get _currentUserIsReady =>
      _currentProfile != null &&
      _wish.readyUserIds.contains(_currentProfile!.id);

  UserProfile? get _author {
    for (final profile in [
      _currentProfile,
      _partnerProfile,
    ]) {
      if (profile != null && profile.id == _wish.proposedByUserId) {
        return profile;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _wish = widget.wish;
    _loadProfiles();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _missing = false;
    });

    await _subscription?.cancel();
    _subscription = null;

    if (!mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw StateError('No encontramos tu sesión.');
      }

      var coupleId = widget.coupleId;

      if (coupleId == null || coupleId.isEmpty) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final value = snapshot.data()?['coupleId'];
        if (value is String) coupleId = value;
      }

      if (coupleId == null || coupleId.isEmpty) {
        throw StateError('Tu perfil no tiene un bote vinculado.');
      }

      final couple = await _connections.getCouple(coupleId);

      if (couple == null || !couple.containsUser(user.uid)) {
        throw StateError('No pudimos validar la conexión.');
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

      final wishId = _wish.id;

      if (wishId == null || wishId.isEmpty) {
        throw StateError('Este deseo todavía no está guardado.');
      }

      if (!mounted) return;

      _coupleId = coupleId;
      _currentProfile = profiles[0];
      _partnerProfile = profiles[1];

      _subscription = _repository.watchWish(coupleId, wishId).listen(
        (wish) {
          if (!mounted) return;
          if (wish == null && _deleting) return;

          setState(() {
            _isLoading = false;
            _error = null;
            _missing = wish == null;

            if (wish != null) _wish = wish;
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

  void _return({
    bool openMemories = false,
    bool addMemory = false,
  }) {
    if (_busy || _dialogOpen) return;

    Navigator.of(context).pop<WishDetailResult>(
      _missing
          ? const WishDetailResult.deleted()
          : WishDetailResult.updated(
              _wish,
              openMemories: openMemories,
              addMemory: addMemory,
            ),
    );
  }

  bool _canChangeWish() {
    if (_busy || _dialogOpen || _isLoading || _error != null) {
      return false;
    }

    if (_missing) {
      _showMessage('Este deseo ya no existe.');
      return false;
    }

    if (_wish.isCompleted) {
      _showMessage('Este deseo ya fue cumplido.');
      return false;
    }

    final profile = _currentProfile;

    if (_coupleId == null ||
        profile == null ||
        FirebaseAuth.instance.currentUser?.uid != profile.id) {
      _showMessage('No pudimos validar tu sesión.');
      return false;
    }

    return true;
  }

  Future<void> _toggleReady() async {
    if (!_canChangeWish()) return;

    setState(() {
      _busy = true;
    });

    try {
      await _repository.toggleReady(
        coupleId: _coupleId!,
        wish: _wish,
      );
    } catch (error) {
      if (mounted) _showMessage(wishErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _editWish() async {
    if (!_canChangeWish()) return;

    final original = _wish;
    var openMemories = false;

    // Bloquea acciones en el detalle mientras está abierto el formulario.
    setState(() {
      _busy = true;
    });

    try {
      final edited = await Navigator.of(context).push<Wish>(
        MaterialPageRoute<Wish>(
          builder: (_) => CreateWishScreen(
            initialWish: original,
            onOpenMemories: () {
              openMemories = true;
            },
          ),
        ),
      );

      if (!mounted) return;

      if (edited != null) {
        await _repository.updateWish(
          coupleId: _coupleId!,
          original: original,
          edited: edited,
        );

        if (mounted) {
          _showMessage('Los cambios fueron guardados.');
        }
      }
    } catch (error) {
      if (mounted) _showMessage(wishErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }

    if (mounted && openMemories) {
      _return(openMemories: true);
    }
  }

  Future<void> _completeWish() async {
    if (!_canChangeWish()) return;

    _dialogOpen = true;

    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          '¿Ya cumplieron este deseo?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Se guardará la fecha de cumplimiento. '
          'Pueden añadir un recuerdo ahora o hacerlo después.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('complete'),
            child: const Text('Solo marcar cumplido'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('memory'),
            child: const Text(
              'Cumplir y añadir recuerdo',
              style: TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );

    _dialogOpen = false;

    if (!mounted || choice == null) return;
    if (!_canChangeWish()) return;

    setState(() {
      _busy = true;
    });

    var saved = false;

    try {
      final completed = await _repository.completeWish(
        coupleId: _coupleId!,
        wish: _wish,
        completedByName: _currentProfile!.name,
      );

      if (!mounted) return;

      _wish = completed;
      saved = true;
    } catch (error) {
      if (mounted) _showMessage(wishErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }

    if (mounted && saved) {
      _return(addMemory: choice == 'memory');
    }
  }

  Future<void> _deleteWish() async {
    if (!_canChangeWish()) return;

    _dialogOpen = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          '¿Eliminar este deseo?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Se eliminará del bote de ambos. '
          'Esta acción no se puede deshacer.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );

    _dialogOpen = false;

    if (!mounted || confirmed != true) return;
    if (!_canChangeWish()) return;

    setState(() {
      _busy = true;
      _deleting = true;
    });

    var deleted = false;

    try {
      await _repository.deleteWish(
        coupleId: _coupleId!,
        wish: _wish,
      );

      deleted = true;
    } catch (error) {
      if (mounted) _showMessage(wishErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _deleting = false;
        });
      }
    }

    if (mounted && deleted) {
      Navigator.of(context).pop<WishDetailResult>(
        const WishDetailResult.deleted(),
      );
    }
  }

  Future<void> _openProfile() async {
    if (_busy || _dialogOpen || _openingProfile || _isLoading) {
      return;
    }

    final coupleId = _coupleId;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null ||
        _currentProfile?.id != user.uid ||
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

      // Recarga perfiles y el estado actual del deseo.
      await _loadProfiles();
    } finally {
      _openingProfile = false;
    }
  }

  void _selectNavigation(int index) {
    if (_busy || _dialogOpen || _openingProfile) return;

    if (index == 0) {
      _return();
    } else if (index == 1) {
      _return(openMemories: true);
    } else if (index == 2) {
      _openProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canShowActions = !_isLoading && _error == null && !_missing;

    return PopScope<WishDetailResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _return();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canShowActions && !_wish.isCompleted)
              Align(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      12,
                      18,
                      10,
                    ),
                    child: PrimaryButton(
                      label: _busy ? 'Guardando…' : 'Marcar como cumplido',
                      onPressed: _completeWish,
                    ),
                  ),
                ),
              ),
            JarBottomNavigation(
              selectedIndex: 0,
              onDestinationSelected: _selectNavigation,
            ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox(
                width: double.infinity,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    32,
                  ),
                  children: [
                    _buildHeader(),
                    if (_busy) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(
                        color: AppColors.coral,
                        backgroundColor: AppColors.surface,
                      ),
                    ],
                    const SizedBox(height: 22),
                    Text(
                      _wish.category.label.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.coral,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _wish.description,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 27,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (_wish.isCompleted
                                  ? AppColors.coral
                                  : AppColors.lavender)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _wish.statusLabel,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.coral,
                        ),
                      )
                    else if (_missing) ...[
                      const Text(
                        'Este deseo fue eliminado del bote.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Volver al bote',
                        onPressed: _return,
                      ),
                    ] else if (_error != null) ...[
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Intentar nuevamente',
                        onPressed: _loadProfiles,
                      ),
                    ] else ...[
                      _buildInformation(),
                      const SizedBox(height: 24),
                      if (_wish.isCompleted)
                        _buildCompleted()
                      else
                        ..._buildPendingActions(),
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

  Widget _buildHeader() {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            onPressed: _return,
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
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          ),
          if (!_wish.isCompleted &&
              !_missing &&
              !_busy &&
              !_isLoading &&
              _error == null)
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              color: AppColors.surface,
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: AppColors.textPrimary,
              ),
              onSelected: (_) => _deleteWish(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Eliminar deseo',
                    style: TextStyle(color: AppColors.coral),
                  ),
                ),
              ],
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildInformation() {
    final author = _author;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _info(
            'Creado',
            _formatDate(_wish.createdAt),
            Icons.add_circle_outline_rounded,
          ),
          const SizedBox(height: 16),
          _info(
            'Fecha límite',
            _formatDate(_wish.dueDate),
            Icons.calendar_today_outlined,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (author != null)
                ProfileAvatar(
                  profile: author,
                  size: 34,
                  borderColor: AppColors.coral,
                )
              else
                const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 34,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: _labelValue(
                  'Propuesto por',
                  author?.name ?? _wish.proposedBy,
                ),
              ),
            ],
          ),
          if (_wish.hasNote) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            _labelValue('Nota', _wish.note!.trim()),
          ],
        ],
      ),
    );
  }

  Widget _info(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 22),
        const SizedBox(width: 12),
        Expanded(child: _labelValue(label, value)),
      ],
    );
  }

  Widget _labelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.inactive,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPendingActions() {
    return [
      const Text(
        'Preparados para hacerlo',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 7),
      const Text(
        'Cada persona confirma desde su propia cuenta.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 16),
      _personRow(_currentProfile!, true),
      const SizedBox(height: 14),
      _personRow(_partnerProfile!, false),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: _busy ? null : _toggleReady,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(
          _currentUserIsReady ? 'Quitar mi confirmación' : 'Estoy listo/a',
        ),
      ),
      const SizedBox(height: 22),
      const Divider(color: AppColors.border),
      const SizedBox(height: 12),
      const Text(
        '¿Ya lo hicieron?',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 7),
      const Text(
        'Registren el cumplimiento con el botón inferior '
        'y guarden su momento.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: _busy ? null : _editWish,
          child: const Text(
            'Editar deseo',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _personRow(UserProfile profile, bool current) {
    final ready = _wish.readyUserIds.contains(profile.id);

    return Row(
      children: [
        ProfileAvatar(
          profile: profile,
          size: 36,
          borderColor: current ? AppColors.pink : AppColors.lavender,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _labelValue(
            '${profile.name}${current ? ' (tú)' : ''}',
            ready ? 'Ya confirmó' : 'Aún no confirma',
          ),
        ),
        Icon(
          ready
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: ready ? const Color(0xFF9ED9BC) : AppColors.inactive,
          size: 23,
        ),
      ],
    );
  }

  Widget _buildCompleted() {
    final completedById = _wish.completedByUserId;

    String completedByName = _wish.completedByName ?? 'Usuario no disponible';

    for (final profile in [_currentProfile, _partnerProfile]) {
      if (profile != null && profile.id == completedById) {
        completedByName = profile.name;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _info(
          'Cumplido',
          _formatDate(_wish.completedAt!),
          Icons.check_circle_outline_rounded,
        ),
        const SizedBox(height: 16),
        _info(
          'Registrado por',
          completedByName,
          Icons.person_outline_rounded,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Ver o añadir recuerdo',
          onPressed: () => _return(addMemory: true),
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  return '${date.day} de ${months[date.month - 1]} de ${date.year}';
}
