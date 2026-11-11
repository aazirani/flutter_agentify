import 'package:flutter/material.dart';
import 'package:flutter_agentify/core/theme/app_theme.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/domain/entities/app_theme_mode.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  for (final mode in [AppThemeMode.light, AppThemeMode.dark]) {
    testWidgets('the send icon is onPrimary in ${mode.name} mode', (
      tester,
    ) async {
      final settings = InMemorySettingsRepository();
      await settings.setThemeMode(mode);
      await settings.setAssistantSettings(const AssistantSettings(model: 't'));
      await pumpFullApp(
        tester,
        locale: english,
        settings: settings,
        provider: ScriptedProvider([]),
      );
      await openAssistant(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(AssistantChat),
          matching: find.byType(TextField),
        ),
        'Hi',
      );
      await tester.pumpAndSettle();
      final icon = find.descendant(
        of: find.byTooltip('Send'),
        matching: find.byIcon(Icons.send),
      );
      final colors = Theme.of(tester.element(icon)).colorScheme;
      final glyph = tester.widget<RichText>(
        find.descendant(of: icon, matching: find.byType(RichText)),
      );
      expect(glyph.text.style?.color, colors.onPrimary);
    });
  }

  testWidgets('icon buttons are at least 48 square', (tester) async {
    await pumpFullApp(tester, locale: english);
    final size = tester.getSize(find.byTooltip('Settings').first);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('dialog actions sit side by side, not full width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const AlertDialog(
          content: Text('Delete this?'),
          actions: [
            TextButton(onPressed: null, child: Text('Cancel')),
            FilledButton(onPressed: null, child: Text('Delete')),
          ],
        ),
      ),
    );
    expect(
      tester.getCenter(find.text('Cancel')).dy,
      tester.getCenter(find.text('Delete')).dy,
    );
    expect(
      tester.getSize(find.byType(FilledButton)).width,
      lessThan(tester.getSize(find.byType(AlertDialog)).width / 2),
    );
  });
}
