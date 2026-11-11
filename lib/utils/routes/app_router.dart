import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_agentify/presentation/assistant/assistant_shell.dart';
import 'package:flutter_agentify/presentation/home/home_screen.dart';
import 'package:flutter_agentify/presentation/settings/settings_screen.dart';
import 'package:flutter_agentify/utils/locale/app_localization.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    routes: [
      // One shell around every screen: the assistant is mounted once and
      // keeps its conversation while the person navigates. A new route needs
      // an entry in lib/ai/screen_contexts.dart (the parity test checks).
      ShellRoute(
        builder: (context, state, child) => AssistantShell(child: child),
        routes: [
          // A screen opened from Home is nested under it, so back (and the
          // app bar's back button) returns to Home, however it was opened.
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          (AppLocalizations.of(context)?.translate('page_not_found') ??
                  'page_not_found')
              .replaceFirst('{}', state.uri.path),
        ),
      ),
    ),
  );
}
