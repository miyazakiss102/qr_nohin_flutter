import 'package:shared_preferences/shared_preferences.dart';

class AppSavedSettings {
  final bool duplicateVibrationEnabled;
  final bool overlayEnabled;

  const AppSavedSettings({
    required this.duplicateVibrationEnabled,
    required this.overlayEnabled,
  });
}

class AppSettingsService {
  static const String _keyDuplicateVibrationEnabled =
      'duplicate_vibration_enabled';
  static const String _keyOverlayEnabled = 'overlay_enabled';

  static Future<AppSavedSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    return AppSavedSettings(
      duplicateVibrationEnabled:
          prefs.getBool(_keyDuplicateVibrationEnabled) ?? true,
      overlayEnabled: prefs.getBool(_keyOverlayEnabled) ?? true,
    );
  }

  static Future<void> save({
    required bool duplicateVibrationEnabled,
    required bool overlayEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      _keyDuplicateVibrationEnabled,
      duplicateVibrationEnabled,
    );
    await prefs.setBool(_keyOverlayEnabled, overlayEnabled);
  }
}
