import '../../domain/entities/app_theme_mode.dart';
import '../../domain/entities/assistant_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Settings that last until the process ends: for the action CLI and tests.
class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository({
    AssistantSettings defaults = const AssistantSettings(),
  }) : _assistant = defaults;

  AppThemeMode _themeMode = AppThemeMode.system;
  String? _locale;
  AssistantSettings _assistant;
  // @on-device:begin
  bool _offerDismissed = false;
  bool _useOnDevice = true;
  // @on-device:end

  @override
  AppThemeMode getThemeMode() => _themeMode;

  @override
  Future<void> setThemeMode(AppThemeMode mode) async => _themeMode = mode;

  @override
  String? getLocale() => _locale;

  @override
  Future<void> setLocale(String locale) async => _locale = locale;

  @override
  AssistantSettings getAssistantSettings() => _assistant;

  @override
  Future<void> setAssistantSettings(AssistantSettings settings) async =>
      _assistant = settings;
  // @on-device:begin

  @override
  bool getOnDeviceOfferDismissed() => _offerDismissed;

  @override
  Future<void> setOnDeviceOfferDismissed(bool value) async =>
      _offerDismissed = value;

  @override
  bool getUseOnDeviceModel() => _useOnDevice;

  @override
  Future<void> setUseOnDeviceModel(bool value) async => _useOnDevice = value;
  // @on-device:end
}
