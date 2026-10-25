class SavedDestination {
  final String id;
  final String citizenId;
  final String destinationName;
  final String? address;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedDestination({
    required this.id,
    required this.citizenId,
    required this.destinationName,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavedDestination.fromJson(Map<String, dynamic> json) {
    return SavedDestination(
      id: json['id'] as String,
      citizenId: json['citizen_id'] as String,
      destinationName: json['destination_name'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'citizen_id': citizenId,
      'destination_name': destinationName,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SavedDestination copyWith({
    String? id,
    String? citizenId,
    String? destinationName,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedDestination(
      id: id ?? this.id,
      citizenId: citizenId ?? this.citizenId,
      destinationName: destinationName ?? this.destinationName,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
