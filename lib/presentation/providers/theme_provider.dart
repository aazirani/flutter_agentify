import 'package:flutter/material.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/entities/app_theme_mode.dart';
import 'package:flutter_agentify/domain/repositories/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_provider.g.dart';

/// The saved theme choice. Refreshed by the change-event adapter after
/// `set_theme_mode` runs, whoever ran it.
@Riverpod(keepAlive: true)
ThemeMode currentThemeMode(Ref ref) =>
    switch (ServiceLocator.getIt<SettingsRepository>().getThemeMode()) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
