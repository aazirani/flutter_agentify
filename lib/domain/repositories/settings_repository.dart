import '../entities/app_theme_mode.dart';
import '../entities/assistant_settings.dart';

/// The person's settings.
abstract class SettingsRepository {
  /// [AppThemeMode.system] until the person chooses.
  AppThemeMode getThemeMode();

  Future<void> setThemeMode(AppThemeMode mode);

  /// Null until the person chooses a language.
  String? getLocale();

  Future<void> setLocale(String locale);

  AssistantSettings getAssistantSettings();

  Future<void> setAssistantSettings(AssistantSettings settings);
  // @on-device:begin

  /// Whether the person answered the in-app model's offer with "Not now".
  bool getOnDeviceOfferDismissed();

  Future<void> setOnDeviceOfferDismissed(bool value);

  /// Whether the in-app model answers when it is ready, in `ModelMode.both`.
  /// True until the person turns it off.
  bool getUseOnDeviceModel();

  Future<void> setUseOnDeviceModel(bool value);
  // @on-device:end
}
