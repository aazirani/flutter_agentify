import 'dart:io';

import 'package:flutter_agentify_core/cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await runDocsSearch(args);
}
