import 'package:shared_preferences/shared_preferences.dart';

/// Local, offline-first preferences owned by the Account tab.
///
/// Values live in memory after [load] so widgets can read them synchronously
/// and are mirrored into SharedPreferences so they survive a restart.
class AccountPreferences {
  AccountPreferences._();

  static final AccountPreferences instance = AccountPreferences._();

  static const String _pushNotificationsKey = 'unisafe_push_notifications';
  static const String _anonymousReportingKey = 'unisafe_anonymous_reporting';
  static const String _citizenAadhaarPhotoKey = 'unisafe_citizen_aadhaar_photo';

  bool _pushNotificationsEnabled = true;
  bool _anonymousReportingEnabled = false;
  String? _citizenAadhaarPhoto;

  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool get anonymousReportingEnabled => _anonymousReportingEnabled;
  String? get citizenAadhaarPhoto => _citizenAadhaarPhoto;

  /// Reads persisted values into memory. Safe to call once at startup.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pushNotificationsEnabled = prefs.getBool(_pushNotificationsKey) ?? true;
      _anonymousReportingEnabled =
          prefs.getBool(_anonymousReportingKey) ?? false;
      _citizenAadhaarPhoto = prefs.getString(_citizenAadhaarPhotoKey);
    } catch (_) {
      // Storage restricted (private mode / web restrictions): keep defaults.
    }
  }

  Future<void> setPushNotifications(bool value) async {
    _pushNotificationsEnabled = value;
    await _persist(_pushNotificationsKey, value);
  }

  Future<void> setAnonymousReporting(bool value) async {
    _anonymousReportingEnabled = value;
    await _persist(_anonymousReportingKey, value);
  }

  Future<void> setCitizenAadhaarPhoto(String? base64Photo) async {
    _citizenAadhaarPhoto = base64Photo;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (base64Photo != null) {
        await prefs.setString(_citizenAadhaarPhotoKey, base64Photo);
      } else {
        await prefs.remove(_citizenAadhaarPhotoKey);
      }
    } catch (_) {}
  }

  Future<void> _persist(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }
}
