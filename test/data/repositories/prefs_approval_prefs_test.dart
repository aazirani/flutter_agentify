import 'package:flutter_agentify/data/repositories/prefs_approval_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'always-allow survives a new instance over the same preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await PrefsApprovalPrefs(prefs).setAlwaysAllowed('delete_memory', true);
      final again = PrefsApprovalPrefs(await SharedPreferences.getInstance());
      expect(again.isAlwaysAllowed('delete_memory'), isTrue);
      expect(again.isAlwaysAllowed('save_memory'), isFalse);
    },
  );

  test('setAlwaysAllowed(false) removes the action', () async {
    SharedPreferences.setMockInitialValues({
      'assistant_always_allow': ['delete_memory', 'wipe'],
    });
    final prefs = PrefsApprovalPrefs(await SharedPreferences.getInstance());
    await prefs.setAlwaysAllowed('delete_memory', false);
    expect(prefs.isAlwaysAllowed('delete_memory'), isFalse);
    expect(prefs.isAlwaysAllowed('wipe'), isTrue);
  });

  test('clear removes every always-allow for good', () async {
    SharedPreferences.setMockInitialValues({
      'assistant_always_allow': ['delete_memory', 'wipe'],
    });
    await PrefsApprovalPrefs(await SharedPreferences.getInstance()).clear();
    final again = PrefsApprovalPrefs(await SharedPreferences.getInstance());
    expect(again.isAlwaysAllowed('delete_memory'), isFalse);
    expect(again.isAlwaysAllowed('wipe'), isFalse);
  });
}
