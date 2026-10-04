import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models/memory_location.dart';

class PhotonLocationRepository {
  PhotonLocationRepository({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  static const endpoint = String.fromEnvironment(
    'PHOTON_ENDPOINT',
    defaultValue: 'https://photon.komoot.io/api/',
  );

  final Map<String, List<MemoryLocation>> _cache = {};

  Future<List<MemoryLocation>> search(String query) async {
    final text = query.trim();

    if (text.length < 3 || text.length > 150) {
      throw StateError('Escribe entre 3 y 150 caracteres.');
    }

    final cacheKey = text.toLowerCase();
    final cached = _cache[cacheKey];

    if (cached != null) return cached;

    final uri = Uri.parse(endpoint).replace(
      queryParameters: {
        'q': text,
        'limit': '5',
      },
    );

    final response = await _client.get(uri).timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode == 429) {
      throw StateError(
        'El buscador está ocupado. '
        'Espera un momento e intenta de nuevo.',
      );
    }

    if (response.statusCode != 200) {
      throw StateError(
        'No pudimos consultar los lugares. Intenta nuevamente.',
      );
    }

    final data = jsonDecode(
      utf8.decode(response.bodyBytes),
    ) as Map<String, dynamic>;

    final features = data['features'] as List;
    final results = <MemoryLocation>[];

    for (final item in features) {
      try {
        final feature = Map<String, dynamic>.from(item as Map);

        final properties = Map<String, dynamic>.from(
          feature['properties'] as Map,
        );

        final geometry = feature['geometry'] as Map;
        final coordinates = geometry['coordinates'] as List;

        final pieces = <String>[];

        for (final field in [
          'name',
          'street',
          'city',
          'state',
          'country',
        ]) {
          final value = properties[field];

          if (value is String) {
            final cleanValue = value.trim();

            if (cleanValue.isNotEmpty &&
                !pieces.contains(cleanValue)) {
              pieces.add(cleanValue);
            }
          }
        }

        var label = pieces.join(', ');

        if (label.length > 300) {
          label = label.substring(0, 300);
        }

        final location = MemoryLocation(
          label: label,
          latitude: (coordinates[1] as num).toDouble(),
          longitude: (coordinates[0] as num).toDouble(),
        );

        location.validate();

        final alreadyAdded = results.any(
          (result) =>
              result.label == location.label &&
              result.latitude == location.latitude &&
              result.longitude == location.longitude,
        );

        if (!alreadyAdded) {
          results.add(location);
        }
      } catch (_) {
        // Omite resultados mal formados.
      }
    }

    if (_cache.length >= 30) {
      _cache.remove(_cache.keys.first);
    }

    final locations = List<MemoryLocation>.unmodifiable(results);

    _cache[cacheKey] = locations;

    return locations;
  }

  void dispose() {
    _client.close();
  }
}