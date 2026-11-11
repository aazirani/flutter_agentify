import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:go_router/go_router.dart';

/// The full path pattern of every `GoRoute`, including routes inside shells
/// and nested routes, in declaration order.
List<String> routePatterns(GoRouter router) =>
    _patterns(router.configuration.routes, '/');

List<String> _patterns(List<RouteBase> routes, String parent) => [
  for (final route in routes)
    ...switch (route) {
      GoRoute(:final path) => [
        _join(parent, path),
        ..._patterns(route.routes, _join(parent, path)),
      ],
      _ => _patterns(route.routes, parent),
    },
];

String _join(String parent, String path) => path.startsWith('/')
    ? path
    : parent.endsWith('/')
    ? '$parent$path'
    : '$parent/$path';

/// Keeps [appContext]'s navigation state in step with [router], and lets the
/// assistant's `navigate` action move the router. Returns a function that
/// undoes both.
void Function() attachRouter(GoRouter router, AppContext appContext) {
  void update() {
    if (router.routerDelegate.currentConfiguration.isEmpty) return;
    final state = router.state;
    appContext.setNavigation(
      NavigationState(
        route: state.fullPath ?? state.uri.path,
        location: state.uri.toString(),
        params: state.pathParameters,
        selectedIds: appContext.navigation.selectedIds,
      ),
    );
  }

  router.routerDelegate.addListener(update);
  appContext.onNavigate = (location) async => router.go(location);
  update();
  return () {
    router.routerDelegate.removeListener(update);
    appContext.onNavigate = null;
  };
}
