import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

/// A small model for tests: no engine, no download.
const testModelSpec = OnDeviceModelSpec(
  id: 'test',
  label: 'Test model',
  url: 'https://example.com/test.litertlm',
  sizeBytes: 100,
  minRamBytes: 1,
  config: ModelConfig(model: 'device-model'),
);

/// A started in-app model on [engine].
Future<OnDeviceModelController> startedModel(FakeOnDeviceEngine engine) async {
  final model = OnDeviceModelController(
    engine: engine,
    spec: testModelSpec,
    marker: InMemoryLoadMarker(),
  );
  addTearDown(model.dispose);
  await model.start();
  return model;
}
