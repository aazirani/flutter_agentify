import 'dart:async';

/// Lets one side ask another to stop: a run, a model request, an action.
class CancelToken {
  final _cancelled = Completer<void>();

  /// Asks to stop. Calling it again does nothing.
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when [cancel] is called.
  Future<void> get whenCancelled => _cancelled.future;
}
