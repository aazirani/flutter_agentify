import 'dart:async';
import 'dart:convert';

import '../secrets/redactor.dart';
import '../text.dart';

/// Where the person is in the app, written by the router adapter.
class NavigationState {
  const NavigationState({
    required this.route,
    required this.location,
    this.params = const {},
    this.selectedIds = const [],
  });

  /// The route pattern, such as `/items/:id`.
  final String route;

  /// The actual location, such as `/items/42`.
  final String location;
  final Map<String, String> params;

  /// Ids of the records the person has selected on screen.
  final List<String> selectedIds;

  Map<String, Object?> toJson() => {
    'route': route,
    'location': location,
    'params': params,
    'selectedIds': selectedIds,
  };
}

/// Reads what a screen shows: a bounded, JSON-encodable summary of the
/// visible records.
typedef ViewScreen = FutureOr<Object?> Function(NavigationState navigation);

/// One entry of the screen-context table, keyed by route pattern.
class ScreenContext {
  const ScreenContext(ViewScreen this.view);

  /// For a route that has nothing to report beyond where the person is.
  const ScreenContext.nothing() : view = null;

  final ViewScreen? view;
}

/// What the assistant can know about the app's current state.
class AppContext {
  AppContext({
    required this.screens,
    NavigationState? initial,
    this.viewTimeout = const Duration(seconds: 2),
  }) : _navigation =
           initial ?? const NavigationState(route: '/', location: '/');

  /// How long the current-screen block waits for a screen's view before it
  /// falls back to the navigation state.
  final Duration viewTimeout;

  /// The screen-context table, keyed by route pattern.
  final Map<String, ScreenContext> screens;

  NavigationState _navigation;
  NavigationState get navigation => _navigation;

  /// Set by the router adapter; the `navigate` action calls it.
  Future<void> Function(String location)? onNavigate;

  /// Called by the router adapter only. The assistant navigates through the
  /// `navigate` action instead.
  void setNavigation(NavigationState state) => _navigation = state;

  void setSelection(List<String> ids) => _navigation = NavigationState(
    route: _navigation.route,
    location: _navigation.location,
    params: _navigation.params,
    selectedIds: List.unmodifiable(ids),
  );

  /// Whether [location] matches one of the route patterns in [screens]. A
  /// location with a scheme or a host, or that does not parse, never does.
  bool matchesRoute(String location) {
    final uri = Uri.tryParse(location);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return false;
    final path = _segments(uri.path);
    return screens.keys.any((pattern) {
      final parts = _segments(pattern);
      if (parts.length != path.length) return false;
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].startsWith(':')) {
          if (path[i].isEmpty) return false;
        } else if (parts[i] != path[i]) {
          return false;
        }
      }
      return true;
    });
  }

  static List<String> _segments(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  /// A fresh read: the navigation state and what the current screen shows.
  Future<Object?> viewScreen() async {
    final view = screens[_navigation.route]?.view;
    return {
      'navigation': _navigation.toJson(),
      'screen': view == null ? null : await view(_navigation),
    };
  }

  /// The `<current-screen>` block attached to each new user message, at most
  /// [maxChars] long. Falls back to the navigation state when the screen has
  /// no view or its view fails.
  Future<String> currentScreenBlock({int maxChars = 2000}) async {
    var json = jsonEncode({'navigation': _navigation.toJson()});
    if (screens[_navigation.route]?.view != null) {
      try {
        json = jsonEncode(await viewScreen().timeout(viewTimeout));
      } catch (_) {
        // A failing view still leaves the navigation state to report.
      }
    }
    // `<` as \u003c keeps the JSON valid but stops data closing the block.
    json = const Redactor().redact(json).replaceAll('<', r'\u003c');
    const open = '<current-screen>\n';
    const close = '\n</current-screen>';
    const cutNote = '…[cut]';
    final room = maxChars - open.length - close.length;
    if (json.length > room) {
      json = cutText(json, room - cutNote.length, suffix: cutNote);
    }
    return '$open$json$close';
  }
}
