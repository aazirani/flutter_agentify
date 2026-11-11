import 'package:flutter/material.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/domain/entities/app_theme_mode.dart';
import 'package:flutter_agentify/presentation/providers/theme_provider.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  test('is system by default', () {
    final container = setUpTestServices();
    expect(container.read(currentThemeModeProvider), ThemeMode.system);
  });

  test('follows set_theme_mode run through the registry', () async {
    final container = setUpTestServices();
    expect(container.read(currentThemeModeProvider), ThemeMode.system);
    final registry = ServiceLocator.getIt<ActionRegistry>();
    final actions = ServiceLocator.getIt<AppActions>();
    await registry.run(actions.setThemeMode, AppThemeMode.dark);
    expect(container.read(currentThemeModeProvider), ThemeMode.dark);
  });
}
