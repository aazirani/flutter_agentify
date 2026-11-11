import 'dart:io';

import 'package:flutter_agentify_core/doctor.dart';

Future<void> main(List<String> args) async {
  exitCode = await runDoctor(args);
}
