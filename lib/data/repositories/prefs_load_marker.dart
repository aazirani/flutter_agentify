import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'on_device_model_loading';

/// Remembers across launches that the in-app model was being loaded.
class PrefsLoadMarker implements LoadMarker {
  PrefsLoadMarker(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<bool> isSet() async => _prefs.getBool(_key) ?? false;

  @override
  Future<void> set(bool value) =>
      value ? _prefs.setBool(_key, true) : _prefs.remove(_key);
}
