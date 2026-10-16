import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service to provide a consistent, unique device identifier across sessions and app launches.
class DeviceService {
  static const String _deviceIdKey = 'unisafe_device_unique_id';
  static String? _cachedDeviceId;

  /// Retrieves the persistent device ID from local storage.
  /// Generates and stores a new UUID if one does not already exist.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString(_deviceIdKey);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await prefs.setString(_deviceIdKey, id);
      }
      _cachedDeviceId = id;
      return id;
    } catch (_) {
      // Fallback in-memory UUID if storage is restricted
      _cachedDeviceId ??= const Uuid().v4();
      return _cachedDeviceId!;
    }
  }

  /// Synchronous getter if already resolved, or a fallback temporary ID.
  static String get currentDeviceId => _cachedDeviceId ?? 'device-web-session';

  static const String _myReportsKey = 'unisafe_my_submitted_report_ids';

  /// Saves a report ID to local storage as submitted on this device.
  static Future<void> saveMyReportId(String reportId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_myReportsKey) ?? [];
      if (!list.contains(reportId)) {
        list.add(reportId);
        await prefs.setStringList(_myReportsKey, list);
      }
    } catch (_) {}
  }

  /// Retrieves report IDs submitted on this device.
  static Future<List<String>> getMyReportIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_myReportsKey) ?? [];
    } catch (_) {
      return [];
    }
  }
}
