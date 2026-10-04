class MemoryLocation {
  const MemoryLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;

  void validate() {
    if (label.trim().isEmpty ||
        label.length > 300 ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw StateError('El lugar seleccionado no es válido.');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory MemoryLocation.fromMap(Map<String, dynamic> data) {
    final location = MemoryLocation(
      label: data['label'] as String,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
    );

    location.validate();

    return location;
  }
}