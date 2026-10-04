import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../jar/presentation/widgets/jar_bottom_navigation.dart';
import '../../../wishes/data/firestore_wish_repository.dart';
import '../../../wishes/domain/models/wish.dart';
import '../../data/firestore_memory_repository.dart';
import '../../domain/models/memory_record.dart';
import '../../../locations/domain/models/memory_location.dart';
import '../../../locations/presentation/screens/location_picker_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

export '../../domain/models/memory_record.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({
    required this.coupleId,
    this.wish,
    super.key,
  });

  final String coupleId;

  // Si se recibe un deseo cumplido, abre su formulario
  // después de cargar los datos actuales de Firestore.
  final Wish? wish;

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  MemoryLocation? _location;
  bool _openingScreen = false;
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  final _repository = FirestoreMemoryRepository();
  final _wishRepository = FirestoreWishRepository();

  StreamSubscription<List<MemoryRecord>>? _memorySubscription;
  StreamSubscription<List<Wish>>? _wishSubscription;

  List<MemoryRecord> _records = [];
  List<Wish> _completedWishes = [];

  Wish? _editingWish;
  MemoryRecord? _editingRecord;

  Uint8List? _newPhoto;
  bool _removePhoto = false;

  late DateTime _selectedDate;

  bool _loading = true;
  bool _saving = false;
  bool _pickingPhoto = false;
  bool _showOnlyMemories = false;
  bool _initialFormOpened = false;

  String? _error;

  bool get _busy => _saving || _pickingPhoto || _openingScreen;

  bool get _hasExistingPhoto =>
      _editingRecord?.hasPhoto == true && !_removePhoto;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dayOnly(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _memorySubscription?.cancel();
    _wishSubscription?.cancel();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    await _memorySubscription?.cancel();
    await _wishSubscription?.cancel();

    if (!mounted) return;

    final memoriesReady = Completer<void>();
    final wishesReady = Completer<void>();

    void handleError(
      Object error,
      StackTrace stackTrace,
      Completer<void> ready,
    ) {
      debugPrint('[RECUERDOS] $error');

      if (!ready.isCompleted) {
        ready.completeError(error, stackTrace);
        return;
      }

      if (!mounted) return;

      setState(() {
        _error = memoryErrorMessage(error);
      });
    }

    try {
      _memorySubscription = _repository.watchMemories(widget.coupleId).listen(
        (records) {
          if (!mounted) return;

          setState(() {
            _records = records;
          });

          if (!memoriesReady.isCompleted) memoriesReady.complete();
        },
        onError: (Object error, StackTrace stackTrace) {
          handleError(error, stackTrace, memoriesReady);
        },
      );

      _wishSubscription = _wishRepository.watchWishes(widget.coupleId).listen(
        (wishes) {
          if (!mounted) return;

          setState(() {
            _completedWishes = wishes.where((wish) => wish.isCompleted).toList()
              ..sort(
                (first, second) =>
                    second.completedAt!.compareTo(first.completedAt!),
              );
          });

          if (!wishesReady.isCompleted) wishesReady.complete();
        },
        onError: (Object error, StackTrace stackTrace) {
          handleError(error, stackTrace, wishesReady);
        },
      );

      await Future.wait<void>([
        memoriesReady.future,
        wishesReady.future,
      ]).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      setState(() {
        _loading = false;

        if (!_initialFormOpened) {
          _initialFormOpened = true;
          final requestedId = widget.wish?.id;

          for (final wish in _completedWishes) {
            if (requestedId != null && wish.id == requestedId) {
              _prepareForm(wish);
              break;
            }
          }
        }
      });
    } catch (error) {
      final memorySubscription = _memorySubscription;
      final wishSubscription = _wishSubscription;

      _memorySubscription = null;
      _wishSubscription = null;

      if (memorySubscription != null) {
        unawaited(memorySubscription.cancel());
      }

      if (wishSubscription != null) {
        unawaited(wishSubscription.cancel());
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error is TimeoutException
            ? 'Firebase no respondió a tiempo. Intenta nuevamente.'
            : memoryErrorMessage(error);
      });
    }
  }

  MemoryRecord? _recordFor(Wish wish) {
    for (final record in _records) {
      if (record.wishId == wish.id) return record;
    }

    return null;
  }

  void _prepareForm(Wish wish) {
    final record = _recordFor(wish);
    _location = record?.location;
    final today = _dayOnly(DateTime.now());

    var date = _dayOnly(
      record?.date ?? wish.completedAt ?? today,
    );

    if (date.isAfter(today)) date = today;
    if (date.isBefore(DateTime(1900))) date = DateTime(1900);

    _editingWish = wish;
    _editingRecord = record;
    _descriptionController.text = record?.description ?? '';
    _selectedDate = date;
    _newPhoto = null;
    _removePhoto = false;
  }

  void _openForm(Wish wish) {
    if (_busy || !wish.isCompleted) return;

    setState(() {
      _prepareForm(wish);
    });
  }

  void _returnToJar() {
    if (_busy) return;

    FocusScope.of(context).unfocus();

    Navigator.of(context).pop<MemoriesResult>(
      MemoriesResult(
        records: List<MemoryRecord>.unmodifiable(_records),
      ),
    );
  }

  void _goBack() {
    if (_busy) return;

    FocusScope.of(context).unfocus();

    if (_editingWish != null) {
      setState(() {
        _editingWish = null;
        _editingRecord = null;
        _newPhoto = null;
        _removePhoto = false;
      });
    } else {
      _returnToJar();
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

  Future<void> _pickPhoto() async {
    if (_busy) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _pickingPhoto = true;
    });

    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );

      if (image == null) return;

      final original = await image.readAsBytes();
      final compressed = await _repository.compressPhoto(original);

      if (!mounted) return;

      setState(() {
        _newPhoto = compressed;
        _removePhoto = false;
      });

      _showMessage('Foto preparada para guardar.');
    } catch (error) {
      if (mounted) _showMessage(memoryErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _pickingPhoto = false;
        });
      }
    }
  }

  void _clearPhoto() {
    if (_busy) return;

    setState(() {
      _newPhoto = null;
      _removePhoto = true;
    });
  }

  Future<void> _selectDate() async {
    if (_busy) return;

    FocusScope.of(context).unfocus();

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: _dayOnly(DateTime.now()),
      helpText: 'FECHA DEL RECUERDO',
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

  Future<void> _saveMemory() async {
    if (_busy) return;

    final wish = _editingWish;
    final wishId = wish?.id;

    if (wish == null || wishId == null || !wish.isCompleted) {
      _showMessage('No encontramos el deseo cumplido.');
      return;
    }

    final description = _descriptionController.text.trim();

    if (description.isEmpty && _newPhoto == null && !_hasExistingPhoto) {
      _showMessage('Añade una foto o escribe algo que quieran recordar.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
    });

    try {
      await _repository.saveMemory(
        coupleId: widget.coupleId,
        wishId: wishId,
        date: _selectedDate,
        description: description,
        expectedVersion: _editingRecord?.version ?? 0,
        location: _location,
        newPhoto: _newPhoto,
        removePhoto: _removePhoto,
      );

      if (!mounted) return;

      setState(() {
        _editingWish = null;
        _editingRecord = null;
        _newPhoto = null;
        _removePhoto = false;
      });

      _showMessage('El recuerdo fue guardado en su bote.');
    } catch (error) {
      if (mounted) _showMessage(memoryErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _selectLocation() async {
    if (_busy) return;

    FocusScope.of(context).unfocus();
    _openingScreen = true;

    try {
      final location = await Navigator.of(context).push<MemoryLocation>(
        MaterialPageRoute<MemoryLocation>(
          builder: (_) => const LocationPickerScreen(),
        ),
      );

      if (!mounted || location == null) return;

      setState(() {
        _location = location;
      });
    } finally {
      _openingScreen = false;
    }
  }

  Future<void> _openProfile() async {
    if (_busy) return;

    FocusScope.of(context).unfocus();
    _openingScreen = true;

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(
            coupleId: widget.coupleId,
          ),
        ),
      );
    } finally {
      _openingScreen = false;
    }
  }

  void _selectDestination(int index) {
    if (_busy) return;

    if (index == 0) {
      _returnToJar();
    } else if (index == 1) {
      if (_editingWish != null) {
        _goBack();
      }
    } else if (index == 2) {
      _openProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    final showFormButton = !_loading && _error == null && _editingWish != null;

    return PopScope<MemoriesResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        bottomNavigationBar: SafeArea(
          top: false,
          bottom: keyboardVisible,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showFormButton)
                Align(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        18,
                        10,
                        18,
                        10,
                      ),
                      child: PrimaryButton(
                        label: _saving
                            ? 'Guardando…'
                            : _pickingPhoto
                                ? 'Preparando foto…'
                                : 'Guardar recuerdo',
                        onPressed: _saveMemory,
                      ),
                    ),
                  ),
                ),
              if (!keyboardVisible)
                JarBottomNavigation(
                  selectedIndex: 1,
                  onDestinationSelected: _selectDestination,
                ),
            ],
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox(
                width: double.infinity,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    28,
                  ),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    if (_loading)
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.coral,
                        ),
                      )
                    else if (_error != null) ...[
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      PrimaryButton(
                        label: 'Intentar nuevamente',
                        onPressed: _load,
                      ),
                    ] else if (_editingWish != null)
                      ..._buildForm()
                    else
                      ..._buildList(),
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
    return Row(
      children: [
        IconButton(
          onPressed: _busy ? null : _goBack,
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
        if (_editingWish != null)
          TextButton(
            onPressed: _busy ? null : _goBack,
            child: const Text(
              'Después',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }

  List<Widget> _buildList() {
    final memoryCount = _completedWishes
        .where(
          (wish) => _recordFor(wish)?.hasMemory == true,
        )
        .length;

    final visible = _showOnlyMemories
        ? _completedWishes
            .where(
              (wish) => _recordFor(wish)?.hasMemory == true,
            )
            .toList()
        : _completedWishes;

    return [
      const Text(
        'Nuestros recuerdos',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Lo que vivieron juntos merece quedarse.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 20),
      Text(
        '$memoryCount ${memoryCount == 1 ? 'recuerdo' : 'recuerdos'}'
        ' · ${_completedWishes.length} deseos cumplidos',
        style: const TextStyle(
          color: AppColors.inactive,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _filter('Todos los cumplidos', false),
          _filter('Con recuerdo', true),
        ],
      ),
      const SizedBox(height: 20),
      if (visible.isEmpty)
        _buildEmpty()
      else
        for (final wish in visible) ...[
          _buildCompletedCard(wish),
          const SizedBox(height: 16),
        ],
    ];
  }

  Widget _filter(String label, bool onlyMemories) {
    return ChoiceChip(
      label: Text(label),
      selected: _showOnlyMemories == onlyMemories,
      onSelected: (_) {
        setState(() {
          _showOnlyMemories = onlyMemories;
        });
      },
      selectedColor: AppColors.coral.withValues(alpha: 0.18),
      backgroundColor: AppColors.surface,
      checkmarkColor: AppColors.coral,
      labelStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 11,
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.photo_library_outlined,
            color: AppColors.lavender,
            size: 38,
          ),
          const SizedBox(height: 14),
          Text(
            _completedWishes.isEmpty
                ? 'Sus momentos están por venir'
                : 'Todavía no hay recuerdos guardados',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _completedWishes.isEmpty
                ? 'Marca un deseo como cumplido desde su detalle. '
                    'Después podrás añadir su recuerdo.'
                : 'Abre Todos los cumplidos y añade un recuerdo.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(Wish wish) {
    final record = _recordFor(wish);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (record?.hasPhoto == true)
            _StoredPhoto(
              coupleId: widget.coupleId,
              record: record!,
              repository: _repository,
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wish.category.label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.coral,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  wish.description,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                _trace(
                  Icons.add_circle_outline_rounded,
                  'Creado: ${_formatDate(wish.createdAt)}',
                ),
                const SizedBox(height: 6),
                _trace(
                  Icons.check_circle_outline_rounded,
                  'Cumplido: ${_formatDate(wish.completedAt!)}',
                ),
                if (wish.completedByName != null) ...[
                  const SizedBox(height: 6),
                  _trace(
                    Icons.person_outline_rounded,
                    'Registrado por ${wish.completedByName}',
                  ),
                ],
                const SizedBox(height: 12),
                                if (record != null) ...[
                  if (record.location != null) ...[
                    _trace(
                      Icons.place_outlined,
                      record.location!.label,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Recuerdo del ${_formatDate(record.date)}',
                    style: const TextStyle(
                      color: AppColors.inactive,
                      fontSize: 10,
                    ),
                  ),
                  if (record.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      record.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ] else
                  const Text(
                    'Cumplido, todavía sin recuerdo.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _openForm(wish),
                  icon: Icon(
                    record == null
                        ? Icons.add_photo_alternate_outlined
                        : Icons.edit_outlined,
                    size: 18,
                  ),
                  label: Text(
                    record == null ? 'Añadir recuerdo' : 'Editar recuerdo',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.coral,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trace(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.inactive),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildForm() {
    final wish = _editingWish!;
    final hasPhoto = _newPhoto != null || _hasExistingPhoto;

    return [
      const Text(
        'DESEO CUMPLIDO',
        style: TextStyle(
          color: AppColors.coral,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _editingRecord == null ? 'Guarden este momento' : 'Su recuerdo',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        wish.description,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 20),
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 180,
          width: double.infinity,
          child: _newPhoto != null
              ? Image.memory(
                  _newPhoto!,
                  fit: BoxFit.cover,
                )
              : _hasExistingPhoto
                  ? _StoredPhoto(
                      coupleId: widget.coupleId,
                      record: _editingRecord!,
                      repository: _repository,
                    )
                  : Material(
                      color: AppColors.surface,
                      child: InkWell(
                        onTap: _busy ? null : _pickPhoto,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: AppColors.lavender,
                              size: 36,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Añadir una foto',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
      if (hasPhoto)
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _busy ? null : _pickPhoto,
              child: const Text('Cambiar foto'),
            ),
            TextButton(
              onPressed: _busy ? null : _clearPhoto,
              child: const Text('Quitar foto'),
            ),
          ],
        ),
      if (_pickingPhoto) ...[
        const SizedBox(height: 10),
        const LinearProgressIndicator(
          color: AppColors.coral,
          backgroundColor: AppColors.surface,
        ),
      ],
      const SizedBox(height: 18),
      const Text(
        '¿Cómo fue?',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _descriptionController,
        enabled: !_busy,
        minLines: 3,
        maxLines: 5,
        maxLength: 200,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          height: 1.4,
        ),
        decoration: InputDecoration(
          hintText: 'Cuenta algo que quieran recordar de ese momento.',
          hintStyle: const TextStyle(
            color: AppColors.inactive,
            fontSize: 12,
          ),
          counterStyle: const TextStyle(
            color: AppColors.inactive,
            fontSize: 10,
          ),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.coral),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy ? null : _selectDate,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 19,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatDate(_selectedDate),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(
          Icons.place_outlined,
          color: AppColors.lavender,
        ),
        title: Text(
          _location?.label ?? 'Añadir lugar (opcional)',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
          ),
        ),
        subtitle: const Text(
          'Buscar ciudad, dirección o sitio',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
        onTap: _busy ? null : _selectLocation,
        trailing: _location == null
            ? null
            : IconButton(
                tooltip: 'Quitar lugar',
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          _location = null;
                        });
                      },
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Pueden guardar una foto, un texto o ambos.',
        style: TextStyle(
          color: AppColors.inactive,
          fontSize: 11,
          height: 1.4,
        ),
      ),
    ];
  }
}

class _StoredPhoto extends StatefulWidget {
  const _StoredPhoto({
    required this.coupleId,
    required this.record,
    required this.repository,
  });

  final String coupleId;
  final MemoryRecord record;
  final FirestoreMemoryRepository repository;

  @override
  State<_StoredPhoto> createState() => _StoredPhotoState();
}

class _StoredPhotoState extends State<_StoredPhoto> {
  late Future<Uint8List> _photo;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant _StoredPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.coupleId != widget.coupleId ||
        oldWidget.record.wishId != widget.record.wishId ||
        oldWidget.record.photoVersion != widget.record.photoVersion) {
      _loadPhoto();
    }
  }

  void _loadPhoto() {
    _photo = widget.repository.loadPhoto(
      coupleId: widget.coupleId,
      wishId: widget.record.wishId,
      photoVersion: widget.record.photoVersion!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: FutureBuilder<Uint8List>(
        future: _photo,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.coral,
                strokeWidth: 2,
              ),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(_loadPhoto);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Volver a cargar la foto'),
              ),
            );
          }

          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 180,
            errorBuilder: (_, error, stackTrace) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: AppColors.textSecondary,
                size: 30,
              ),
            ),
          );
        },
      ),
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
