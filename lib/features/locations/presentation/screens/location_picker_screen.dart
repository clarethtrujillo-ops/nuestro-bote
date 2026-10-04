import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/photon_location_repository.dart';
import '../../domain/models/memory_location.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState
    extends State<LocationPickerScreen> {
  final _controller = TextEditingController();
  final _repository = PhotonLocationRepository();

  List<MemoryLocation> _results = [];

  bool _loading = false;
  bool _searched = false;

  String? _error;
  DateTime? _lastRequest;

  @override
  void dispose() {
    _controller.dispose();
    _repository.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_loading) return;

    final now = DateTime.now();

    if (_lastRequest != null &&
        now.difference(_lastRequest!) <
            const Duration(seconds: 1)) {
      return;
    }

    _lastRequest = now;

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
      _results = [];
    });

    try {
      final results = await _repository.search(
        _controller.text,
      );

      if (!mounted) return;

      setState(() {
        _results = results;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error is StateError
            ? error.message.toString()
            : 'No pudimos conectar con el buscador. '
                'Revisa tu conexión e intenta nuevamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lugar del recuerdo'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.all(20),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                const Text(
                  '¿Dónde lo vivieron?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Escribe el nombre del lugar y la ciudad '
                  'para encontrarlo más fácilmente.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  enabled: !_loading,
                  maxLength: 150,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Playa del Postiguet, Alicante',
                    hintStyle: const TextStyle(
                      color: AppColors.inactive,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: AppColors.background,
                  ),
                  child: Text(
                    _loading ? 'Buscando…' : 'Buscar lugar',
                  ),
                ),
                const SizedBox(height: 20),
                if (_loading)
                  const LinearProgressIndicator(
                    color: AppColors.coral,
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                if (!_loading &&
                    _error == null &&
                    _searched &&
                    _results.isEmpty)
                  const Text(
                    'No encontramos resultados. '
                    'Prueba añadiendo la ciudad.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                for (final location in _results)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.place_outlined,
                      color: AppColors.coral,
                    ),
                    title: Text(
                      location.label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () {
                      Navigator.of(context).pop(location);
                    },
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Datos: © OpenStreetMap contributors\n'
                  'Búsqueda: Photon',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}