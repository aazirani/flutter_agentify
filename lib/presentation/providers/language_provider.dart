import 'dart:ui' as ui;

import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
import 'package:flutter_agentify/domain/repositories/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'language_provider.g.dart';

/// The device's language code.
@Riverpod(keepAlive: true)
String deviceLanguage(Ref ref) =>
    ui.PlatformDispatcher.instance.locale.languageCode;

/// The app's language: the person's choice, else the device language when
/// the app supports it, else the first in `kSupportedLanguages`. Refreshed
/// after `set_language` runs.
@Riverpod(keepAlive: true)
String currentLocale(Ref ref) {
  final saved = ServiceLocator.getIt<SettingsRepository>().getLocale();
  bool supported(String? code) =>
      kSupportedLanguages.any((l) => l.locale == code);
  if (saved != null && supported(saved)) return saved;
  final device = ref.watch(deviceLanguageProvider);
  return supported(device) ? device : kSupportedLanguages.first.locale;
}
