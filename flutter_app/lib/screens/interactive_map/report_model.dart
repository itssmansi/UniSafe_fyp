import 'dart:typed_data';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

enum IssueCategory {
  infrastructure,
  sanitation,
  safety,
  greenery,
}

class ReportModel {
  final String id;
  final LatLng location;
  final IssueCategory category;
  final String title;
  final String description;
  final String? imagePath;
  final Uint8List? imageBytes;
  final String? citizenId;
  final String? citizenName;
  final String? address;
  final String status;
  final int upvoteCount;
  final DateTime? createdAt;

  ReportModel({
    String? id,
    required this.location,
    required this.category,
    required this.title,
    required this.description,
    this.imagePath,
    this.imageBytes,
    this.citizenId,
    this.citizenName,
    this.address,
    this.status = 'pending',
    this.upvoteCount = 0,
    this.createdAt,
  }) : id = id ?? const Uuid().v4();

  ReportModel copyWith({
    String? id,
    LatLng? location,
    IssueCategory? category,
    String? title,
    String? description,
    String? imagePath,
    Uint8List? imageBytes,
    String? citizenId,
    String? citizenName,
    String? address,
    String? status,
    int? upvoteCount,
    DateTime? createdAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      location: location ?? this.location,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      imageBytes: imageBytes ?? this.imageBytes,
      citizenId: citizenId ?? this.citizenId,
      citizenName: citizenName ?? this.citizenName,
      address: address ?? this.address,
      status: status ?? this.status,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ReportModel.fromSupabase(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble() ?? 19.0760;
    final lng = (json['longitude'] as num?)?.toDouble() ?? 72.8777;

    final rawDesc = (json['description'] as String?) ?? '';
    String title = 'Report';
    String description = rawDesc;

    if (rawDesc.contains('\n')) {
      final parts = rawDesc.split('\n');
      title = parts.first.trim();
      description = parts.sublist(1).join('\n').trim();
    } else if (rawDesc.isNotEmpty) {
      title = rawDesc;
    }

    final catStr = (json['category'] as String?)?.toLowerCase().trim();
    IssueCategory category = IssueCategory.infrastructure;
    if (catStr != null) {
      if (catStr.contains('sanitation') || catStr.contains('garbage') || catStr.contains('waste')) {
        category = IssueCategory.sanitation;
      } else if (catStr.contains('safety') || catStr.contains('security') || catStr.contains('hazard')) {
        category = IssueCategory.safety;
      } else if (catStr.contains('greenery') || catStr.contains('tree') || catStr.contains('plant')) {
        category = IssueCategory.greenery;
      }
    }

    // Citizen relation data if joined
    String? citizenName;
    if (json['citizens'] != null && json['citizens'] is Map) {
      citizenName = json['citizens']['name']?.toString();
    }

    DateTime? createdAt;
    if (json['created_at'] != null) {
      createdAt = DateTime.tryParse(json['created_at'].toString());
    }

    return ReportModel(
      id: json['id']?.toString() ?? const Uuid().v4(),
      location: LatLng(lat, lng),
      category: category,
      title: title,
      description: description,
      imagePath: json['image_url']?.toString(),
      citizenId: json['citizen_id']?.toString(),
      citizenName: citizenName,
      address: json['address']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      upvoteCount: (json['upvote_count'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toSupabase({String? reporterCitizenId}) {
    final combinedDescription = title.isNotEmpty && description.isNotEmpty && title != description
        ? '$title\n$description'
        : (title.isNotEmpty ? title : description);

    final map = <String, dynamic>{
      'id': id,
      'category': category.name,
      'description': combinedDescription,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'status': status,
      'upvote_count': upvoteCount,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };

    final effectiveCitizenId = reporterCitizenId ?? citizenId;
    if (effectiveCitizenId != null && effectiveCitizenId.isNotEmpty) {
      map['citizen_id'] = effectiveCitizenId;
    }

    if (address != null && address!.isNotEmpty) {
      map['address'] = address;
    }

    if (imagePath != null && (imagePath!.startsWith('http') || imagePath!.startsWith('blob:'))) {
      map['image_url'] = imagePath;
    }

    return map;
  }
}
