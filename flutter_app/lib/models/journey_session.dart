class JourneySession {
  final String id;
  final String citizenId;
  final double startLatitude;
  final double startLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final String destinationName;
  final double latestLatitude;
  final double latestLongitude;
  final DateTime lastLocationUpdate;
  final String status; // 'active', 'completed', 'cancelled'
  final DateTime startedAt;
  final DateTime? endedAt;
  final String trackingToken;
  final DateTime tokenExpiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JourneySession({
    required this.id,
    required this.citizenId,
    required this.startLatitude,
    required this.startLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.destinationName,
    required this.latestLatitude,
    required this.latestLongitude,
    required this.lastLocationUpdate,
    required this.status,
    required this.startedAt,
    this.endedAt,
    required this.trackingToken,
    required this.tokenExpiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Status helpers
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isTokenExpired => DateTime.now().toUtc().isAfter(tokenExpiresAt.toUtc());
  bool get isLiveTrackingActive => isActive && !isTokenExpired;

  factory JourneySession.fromJson(Map<String, dynamic> json) {
    return JourneySession(
      id: json['id'] as String,
      citizenId: json['citizen_id'] as String,
      startLatitude: (json['start_latitude'] as num).toDouble(),
      startLongitude: (json['start_longitude'] as num).toDouble(),
      destinationLatitude: (json['destination_latitude'] as num).toDouble(),
      destinationLongitude: (json['destination_longitude'] as num).toDouble(),
      destinationName: (json['destination_name'] as String?) ?? '',
      latestLatitude: (json['latest_latitude'] as num).toDouble(),
      latestLongitude: (json['latest_longitude'] as num).toDouble(),
      lastLocationUpdate: DateTime.parse(json['last_location_update'] as String),
      status: (json['status'] as String?) ?? 'active',
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      trackingToken: (json['tracking_token'] as String?) ?? '',
      tokenExpiresAt: DateTime.parse(json['token_expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'citizen_id': citizenId,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'destination_name': destinationName,
      'latest_latitude': latestLatitude,
      'latest_longitude': latestLongitude,
      'last_location_update': lastLocationUpdate.toIso8601String(),
      'status': status,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'tracking_token': trackingToken,
      'token_expires_at': tokenExpiresAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  JourneySession copyWith({
    String? id,
    String? citizenId,
    double? startLatitude,
    double? startLongitude,
    double? destinationLatitude,
    double? destinationLongitude,
    String? destinationName,
    double? latestLatitude,
    double? latestLongitude,
    DateTime? lastLocationUpdate,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
    String? trackingToken,
    DateTime? tokenExpiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JourneySession(
      id: id ?? this.id,
      citizenId: citizenId ?? this.citizenId,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      destinationLatitude: destinationLatitude ?? this.destinationLatitude,
      destinationLongitude: destinationLongitude ?? this.destinationLongitude,
      destinationName: destinationName ?? this.destinationName,
      latestLatitude: latestLatitude ?? this.latestLatitude,
      latestLongitude: latestLongitude ?? this.latestLongitude,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      trackingToken: trackingToken ?? this.trackingToken,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'JourneySession(id: $id, citizenId: $citizenId, status: $status, destination: $destinationName, latest: ($latestLatitude, $latestLongitude))';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JourneySession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
