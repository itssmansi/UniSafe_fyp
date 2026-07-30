import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

enum IssueCategory {
  infrastructure,
  flood,
  garbage,
  other,
}

class ReportModel {
  final String id;
  final LatLng location;
  final IssueCategory category;
  final String title;
  final String description;
  final String? imagePath;

  ReportModel({
    String? id,
    required this.location,
    required this.category,
    required this.title,
    required this.description,
    this.imagePath,
  }) : id = id ?? const Uuid().v4();
}
