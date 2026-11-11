import 'package:flutter/material.dart';
import 'package:flutter_agentify/core/theme/app_theme.dart';
import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
import 'package:flutter_agentify/presentation/providers/language_provider.dart';
import 'package:flutter_agentify/presentation/providers/theme_provider.dart';
import 'package:flutter_agentify/utils/locale/app_localization.dart';
import 'package:flutter_agentify/utils/routes/app_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final locale = ref.watch(currentLocaleProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.translate('app_name') ?? '',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(locale: locale),
      darkTheme: AppTheme.dark(locale: locale),
      themeMode: themeMode,
      routerConfig: AppRouter.router,
      locale: Locale(locale),
      supportedLocales: kSupportedLanguages
          .map((l) => Locale(l.locale))
          .toList(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
