import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _alwaysAllow = 'assistant_always_allow';

/// The actions the person allowed for good, kept across restarts.
class PrefsApprovalPrefs implements ApprovalPrefs {
  PrefsApprovalPrefs(this._prefs);

  final SharedPreferences _prefs;

  @override
  bool isAlwaysAllowed(String action) =>
      (_prefs.getStringList(_alwaysAllow) ?? const []).contains(action);

  @override
  Future<void> setAlwaysAllowed(String action, bool value) async {
    final allowed = {...?_prefs.getStringList(_alwaysAllow)};
    if (value) {
      allowed.add(action);
    } else {
      allowed.remove(action);
    }
    await _prefs.setStringList(_alwaysAllow, allowed.toList()..sort());
  }

  @override
  Future<void> clear() async => _prefs.remove(_alwaysAllow);
}
