import 'dart:async';

import 'package:http/http.dart' as http;

import '../text.dart';
import 'llm_types.dart';

/// A request that failed outside the HTTP status: retried only when the
/// network dropped or timed out, never for a malformed reply or a
/// certificate error.
LlmError connectionError(Object error) => switch (error) {
  FormatException() || TypeError() => LlmError(
    'The reply could not be read: $error',
    kind: LlmErrorKind.badReply,
  ),
  TimeoutException() => timeoutError(),
  _ => LlmError(
    'The connection failed: $error',
    kind: LlmErrorKind.connection,
    retryable: error is http.ClientException,
  ),
};

var _fallbackIds = 0;

/// An id for a tool call the server gave none (or an empty one), unique
/// within a thread: a repeated id breaks the pairing of calls and results.
String fallbackCallId() =>
    'call_${DateTime.now().microsecondsSinceEpoch}_${_fallbackIds++}';

/// [body] cut to a length fit for a chat message; an HTML error page is
/// never shown whole.
String shortBody(String body) => cutText(body.trim(), 300, suffix: '...');

const _months = [
  'jan', 'feb', 'mar', 'apr', 'may', 'jun', //
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];
final _httpDate = RegExp(r'(\d{1,2}) (\w{3}) (\d{4}) (\d\d):(\d\d):(\d\d)');

/// The wait a `Retry-After` header asks for: seconds, or an HTTP date. Null
/// when absent or unreadable. (Parsed here because `dart:io` is not
/// available on the web.)
Duration? parseRetryAfter(String? value) {
  final text = value?.trim() ?? '';
  final seconds = int.tryParse(text);
  if (seconds != null) return Duration(seconds: seconds < 0 ? 0 : seconds);
  final g = [
    for (final part
        in _httpDate.firstMatch(text)?.groups([1, 2, 3, 4, 5, 6]) ??
            const <String?>[])
      part ?? '',
  ];
  final month = g.isEmpty ? -1 : _months.indexOf(g[1].toLowerCase());
  if (month < 0) return null;
  final n = [
    for (final i in [0, 2, 3, 4, 5]) int.parse(g[i]),
  ];
  final at = DateTime.utc(n[1], month + 1, n[0], n[2], n[3], n[4]);
  final wait = at.difference(DateTime.now().toUtc());
  return wait.isNegative ? Duration.zero : wait;
}

/// The server sent nothing for [llmIdleTimeout].
LlmError timeoutError() => const LlmError(
  'The model server stopped responding.',
  kind: LlmErrorKind.timeout,
  retryable: true,
);

/// Aborts a request when no bytes arrive for [idle]: [trigger] completes
/// then, and [touch] restarts the wait. [stop] ends the watch.
class IdleWatch {
  IdleWatch(this.idle) {
    touch();
  }

  final Duration idle;
  final _fired = Completer<void>();
  Timer? _timer;

  /// Completes when the wait ran out.
  Future<void> get trigger => _fired.future;

  bool get fired => _fired.isCompleted;

  void touch() {
    _timer?.cancel();
    _timer = Timer(idle, () {
      if (!_fired.isCompleted) _fired.complete();
    });
  }

  void stop() => _timer?.cancel();
}
