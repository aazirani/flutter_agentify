import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';

/// Why this browser cannot run the engine at all; null when it can.
UnsupportedReason? hostUnsupported() {
  final navigator = globalContext.getProperty<JSObject?>('navigator'.toJS);
  return navigator != null && navigator.has('gpu')
      ? null
      : UnsupportedReason.noWebGpu;
}
