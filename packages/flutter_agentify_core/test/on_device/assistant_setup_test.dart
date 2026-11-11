import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:test/test.dart';

const _spec = OnDeviceModelSpec(
  id: 'm',
  label: 'M',
  url: 'https://example.com/m',
  sizeBytes: 1,
  minRamBytes: 1,
  config: ModelConfig(model: 'm'),
);

void main() {
  test('onDevice and both need an on-device model', () {
    expect(
      setupProblems(
        const AssistantSetup(mode: ModelMode.onDevice),
        presetNeedsKey: (_) => false,
      ),
      hasLength(1),
    );
    expect(
      setupProblems(
        const AssistantSetup(mode: ModelMode.both),
        presetNeedsKey: (_) => false,
      ),
      hasLength(1),
    );
  });

  test('onDevice with a model is consistent', () {
    expect(
      setupProblems(
        const AssistantSetup(
          mode: ModelMode.onDevice,
          onDevice: OnDeviceSetup(model: _spec),
        ),
        presetNeedsKey: (_) => true,
      ),
      isEmpty,
    );
  });

  test('server with userEditable false needs a model and a keyless preset', () {
    const locked = ServerSetup(userEditable: false);
    expect(
      setupProblems(
        const AssistantSetup(mode: ModelMode.server, server: locked),
        presetNeedsKey: (_) => false,
      ),
      hasLength(1),
    );
    expect(
      setupProblems(
        const AssistantSetup(
          mode: ModelMode.server,
          server: ServerSetup(model: 'm', userEditable: false),
        ),
        presetNeedsKey: (_) => true,
      ),
      hasLength(1),
    );
  });

  test('the defaults are consistent', () {
    expect(
      setupProblems(
        const AssistantSetup(mode: ModelMode.server),
        presetNeedsKey: (_) => false,
      ),
      isEmpty,
    );
  });
}
