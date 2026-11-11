import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_theme_mode.dart';
import '../../domain/entities/assistant_settings.dart';
import '../../domain/repositories/settings_repository.dart';

const _themeMode = 'theme_mode';
const _locale = 'locale';
const _preset = 'assistant_preset';
const _baseUrl = 'assistant_base_url';
const _model = 'assistant_model';
const _toolCalling = 'assistant_tool_calling';
const _contextWindow = 'assistant_context_window';
// @on-device:begin
const _offerDismissed = 'on_device_offer_dismissed';
const _useOnDevice = 'use_on_device_model';
// @on-device:end

class PrefsSettingsRepository implements SettingsRepository {
  /// [defaults] are used for anything not saved yet.
  PrefsSettingsRepository(this._prefs, {AssistantSettings? defaults})
    : _defaults = defaults ?? const AssistantSettings();

  final SharedPreferences _prefs;
  final AssistantSettings _defaults;

  @override
  AppThemeMode getThemeMode() {
    final stored = _prefs.getString(_themeMode);
    return AppThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => AppThemeMode.system,
    );
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) =>
      _prefs.setString(_themeMode, mode.name);

  @override
  String? getLocale() => _prefs.getString(_locale);

  @override
  Future<void> setLocale(String locale) => _prefs.setString(_locale, locale);

  @override
  AssistantSettings getAssistantSettings() {
    final defaults = _defaults;
    return AssistantSettings(
      presetId: _prefs.getString(_preset) ?? defaults.presetId,
      baseUrl: _prefs.getString(_baseUrl) ?? defaults.baseUrl,
      model: _prefs.getString(_model) ?? defaults.model,
      toolCalling: _prefs.getBool(_toolCalling),
      contextWindow: _prefs.getInt(_contextWindow),
    );
  }

  @override
  Future<void> setAssistantSettings(AssistantSettings settings) async {
    await _prefs.setString(_preset, settings.presetId);
    await _prefs.setString(_baseUrl, settings.baseUrl);
    await _prefs.setString(_model, settings.model);
    if (settings.toolCalling case final value?) {
      await _prefs.setBool(_toolCalling, value);
    } else {
      await _prefs.remove(_toolCalling);
    }
    if (settings.contextWindow case final value?) {
      await _prefs.setInt(_contextWindow, value);
    } else {
      await _prefs.remove(_contextWindow);
    }
  }
  // @on-device:begin

  @override
  bool getOnDeviceOfferDismissed() => _prefs.getBool(_offerDismissed) ?? false;

  @override
  Future<void> setOnDeviceOfferDismissed(bool value) =>
      _prefs.setBool(_offerDismissed, value);

  @override
  bool getUseOnDeviceModel() => _prefs.getBool(_useOnDevice) ?? true;

  @override
  Future<void> setUseOnDeviceModel(bool value) =>
      _prefs.setBool(_useOnDevice, value);
  // @on-device:end
}
