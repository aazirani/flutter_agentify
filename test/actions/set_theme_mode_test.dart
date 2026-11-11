import 'package:flutter_agentify/domain/entities/app_theme_mode.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test('stores the mode and records a receipt', () async {
    final h = ActionsHarness();
    final result = await h.call('set_theme_mode', {'mode': 'dark'});
    expect(h.settings.getThemeMode(), AppThemeMode.dark);
    expect(result.receipts.single.summary, 'Theme set to dark');
    // The chat shows it in the app's language through receipt_theme_dark.
    expect(result.receipts.single.key, 'theme_dark');
    expect(result.receipts.single.resource, 'settings');
  });

  test(
    'an unknown mode is invalid_input and lists the allowed values',
    () async {
      final h = ActionsHarness();
      await expectLater(
        h.call('set_theme_mode', {'mode': 'purple'}),
        throwsA(
          isA<ActionFailure>()
              .having((f) => f.code, 'code', 'invalid_input')
              .having(
                (f) => f.message,
                'message',
                contains('system, light, dark'),
              ),
        ),
      );
    },
  );
}
