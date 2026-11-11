import 'dart:ffi';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';

// The processors LiteRT-LM ships native libraries for.
const _engineAbis = {
  Abi.androidArm64,
  Abi.iosArm64,
  Abi.macosArm64,
  Abi.linuxX64,
  Abi.linuxArm64,
  Abi.windowsX64,
};

/// Why this host cannot run the engine at all; null when it can.
UnsupportedReason? hostUnsupported() =>
    _engineAbis.contains(Abi.current()) ? null : UnsupportedReason.platform;
