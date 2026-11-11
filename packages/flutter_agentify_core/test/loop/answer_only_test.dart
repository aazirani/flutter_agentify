import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:test/test.dart';

import 'loop_fixtures.dart';

void main() {
  test('a model without tool calling gets no tools and the run emits '
      'AnswerOnly once', () async {
    final f = LoopFixture([
      ScriptedStep.text('From the screen: 2 items.'),
    ], model: const ModelConfig(model: 'tiny', toolCalling: false));
    final events = await f.send('How many items?');
    expect(events.whereType<AnswerOnly>(), hasLength(1));
    expect(events.first, isA<AnswerOnly>());
    expect(f.provider.requests.single.tools, isEmpty);
    expect(
      f.provider.requests.single.system,
      contains('No tools are available'),
    );
    expect(f.session.answerOnly, isTrue);
  });

  test(
    'toolsUnsupported switches to answer-only and repeats the step',
    () async {
      final f = LoopFixture([
        ScriptedStep.error(
          const LlmError(
            'gemma does not support tools',
            status: 400,
            toolsUnsupported: true,
          ),
        ),
        ScriptedStep.text('ok'),
      ]);
      expect(f.session.answerOnly, isFalse);
      final events = await f.send('Hi');
      expect(events.map((e) => e.runtimeType), [AnswerOnly, TextDelta, Done]);
      expect(f.provider.requests[0].tools, isNotEmpty);
      expect(f.provider.requests[1].tools, isEmpty);
      expect(f.session.answerOnly, isTrue);
      expect(f.delays, isEmpty);
    },
  );

  test('answerOnly stays on for the next run with the same model', () async {
    final f = LoopFixture([
      ScriptedStep.error(
        const LlmError(
          'does not support tools',
          status: 400,
          toolsUnsupported: true,
        ),
      ),
      ScriptedStep.text('one'),
      ScriptedStep.text('two'),
    ]);
    await f.send('Hi');
    final second = await f.send('Again');
    expect(second.first, isA<AnswerOnly>());
    expect(f.provider.requests[2].tools, isEmpty);
  });
}
