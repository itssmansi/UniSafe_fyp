import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class InstantCaptureDraft {
  final String id;
  final Uint8List? imageBytes;
  final String? imagePath;
  final double latitude;
  final double longitude;
  final DateTime capturedAt;
  final String? locationAddress;

  InstantCaptureDraft({
    required this.id,
    this.imageBytes,
    this.imagePath,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.locationAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'base64Bytes': imageBytes != null ? base64Encode(imageBytes!) : null,
      'imagePath': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'capturedAt': capturedAt.toIso8601String(),
      'locationAddress': locationAddress,
    };
  }

  factory InstantCaptureDraft.fromJson(Map<String, dynamic> json) {
    Uint8List? bytes;
    if (json['base64Bytes'] != null) {
      try {
        bytes = base64Decode(json['base64Bytes'] as String);
      } catch (_) {}
    }

    return InstantCaptureDraft(
      id: json['id'] as String,
      imageBytes: bytes,
      imagePath: json['imagePath'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      capturedAt: DateTime.tryParse(json['capturedAt'] as String? ?? '') ?? DateTime.now(),
      locationAddress: json['locationAddress'] as String?,
    );
  }
}

class InstantCaptureService {
  InstantCaptureService._();
  static final InstantCaptureService instance = InstantCaptureService._();

  static const String _storageKey = 'unisafe_instant_capture_drafts_v1';

  Future<List<InstantCaptureDraft>> getDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonListStr = prefs.getStringList(_storageKey) ?? [];
      final List<InstantCaptureDraft> drafts = [];
      for (final raw in jsonListStr) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          drafts.add(InstantCaptureDraft.fromJson(map));
        } catch (_) {}
      }
      // Sort newest first
      drafts.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      return drafts;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveDraft(InstantCaptureDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonListStr = prefs.getStringList(_storageKey) ?? [];
      final jsonStr = jsonEncode(draft.toJson());
      jsonListStr.insert(0, jsonStr);
      await prefs.setStringList(_storageKey, jsonListStr);
    } catch (e) {
      // ignore
    }
  }

  Future<void> deleteDrafts(List<String> ids) async {
    try {
      if (ids.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final jsonListStr = prefs.getStringList(_storageKey) ?? [];
      final idSet = ids.toSet();
      final List<String> updated = [];
      for (final raw in jsonListStr) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          if (!idSet.contains(map['id'])) {
            updated.add(raw);
          }
        } catch (_) {}
      }
      await prefs.setStringList(_storageKey, updated);
    } catch (e) {
      // ignore
    }
  }

  Future<int> getDraftCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey) ?? [];
      return list.length;
    } catch (_) {
      return 0;
    }
  }
}
