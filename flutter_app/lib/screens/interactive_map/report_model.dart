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

  ReportModel({
    String? id,
    required this.location,
    required this.category,
    required this.title,
    required this.description,
    this.imagePath,
    this.imageBytes,
  }) : id = id ?? const Uuid().v4();

  ReportModel copyWith({
    String? id,
    LatLng? location,
    IssueCategory? category,
    String? title,
    String? description,
    String? imagePath,
    Uint8List? imageBytes,
  }) {
    return ReportModel(
      id: id ?? this.id,
      location: location ?? this.location,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }
}
