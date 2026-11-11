import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

/// The app's database connection on every platform (a web worker on web).
QueryExecutor openAppConnection() => driftDatabase(
  name: 'flutter_agentify',
  web: DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.dart.js'),
    onResult: (result) {
      if (result.missingFeatures.isNotEmpty) {
        debugPrint(
          'Drift web: using ${result.chosenImplementation} '
          '(missing: ${result.missingFeatures})',
        );
      }
    },
  ),
);
