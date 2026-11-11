import 'package:flutter/material.dart';
import 'package:flutter_agentify/ai/go_router_adapter.dart';
import 'package:flutter_agentify/utils/routes/app_router.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _router() => GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => child,
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/items/:id',
          builder: (_, _) => const SizedBox(),
          routes: [GoRoute(path: 'edit', builder: (_, _) => const SizedBox())],
        ),
      ],
    ),
  ],
);

void main() {
  test('routePatterns lists every route, including those inside a shell', () {
    expect(routePatterns(AppRouter.router), ['/', '/settings']);
    expect(routePatterns(_router()), ['/', '/items/:id', '/items/:id/edit']);
  });

  testWidgets('navigation updates AppContext', (tester) async {
    final router = _router();
    final appContext = AppContext(screens: const {});
    attachRouter(router, appContext);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/items/42');
    await tester.pumpAndSettle();
    expect(appContext.navigation.route, '/items/:id');
    expect(appContext.navigation.location, '/items/42');
    expect(appContext.navigation.params, {'id': '42'});
  });

  testWidgets('onNavigate moves the router', (tester) async {
    final router = _router();
    final appContext = AppContext(screens: const {});
    attachRouter(router, appContext);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await appContext.onNavigate?.call('/items/7/edit');
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/items/7/edit');
    expect(appContext.navigation.route, '/items/:id/edit');
  });

  testWidgets('detaching stops the updates and the navigate hook', (
    tester,
  ) async {
    final router = _router();
    final appContext = AppContext(screens: const {});
    final detach = attachRouter(router, appContext);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    detach();
    router.go('/items/42');
    await tester.pumpAndSettle();
    expect(appContext.navigation.location, '/');
    expect(appContext.onNavigate, isNull);
  });
}
