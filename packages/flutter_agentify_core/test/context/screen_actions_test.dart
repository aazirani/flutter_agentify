import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:test/test.dart';

void main() {
  late AppContext ctx;
  late ActionRegistry reg;
  var reads = 0;

  setUp(() {
    reads = 0;
    ctx = AppContext(
      screens: {
        '/': ScreenContext((_) => {'reads': ++reads}),
        '/items/:id': const ScreenContext.nothing(),
      },
    );
    reg = ActionRegistry([ViewScreenAction(ctx), NavigateAction(ctx)]);
  });

  test('view_screen returns a fresh read', () async {
    final first = await reg.call('view_screen', {}, caller: Caller.assistant);
    final second = await reg.call(
      'view_screen',
      null,
      caller: Caller.assistant,
    );
    expect(first.content, contains('"reads":1'));
    expect(second.content, contains('"reads":2'));
    expect(reg.find('view_screen')?.readOnly, isTrue);
    expect(reg.find('view_screen')?.maxResultChars, 8000);
  });

  test('navigate calls onNavigate with the location', () async {
    final visited = <String>[];
    ctx.onNavigate = (location) async => visited.add(location);
    await reg.call('navigate', {
      'location': '/items/42',
    }, caller: Caller.assistant);
    expect(visited, ['/items/42']);
    expect(reg.find('navigate')?.readOnly, isTrue);
  });

  test('navigate to an unknown route fails with unknown_route and lists the '
      'patterns', () async {
    ctx.onNavigate = (_) async {};
    await expectLater(
      reg.call('navigate', {'location': '/nope'}, caller: Caller.assistant),
      throwsA(
        isA<ActionFailure>()
            .having((f) => f.code, 'code', 'unknown_route')
            .having((f) => f.details?['routes'], 'routes', ['/', '/items/:id']),
      ),
    );
  });

  test(
    'navigate without an adapter fails with navigation_unavailable',
    () async {
      await expectLater(
        reg.call('navigate', {'location': '/'}, caller: Caller.assistant),
        throwsA(
          isA<ActionFailure>().having(
            (f) => f.code,
            'code',
            'navigation_unavailable',
          ),
        ),
      );
    },
  );

  test('builtInActionNames lists the four built-ins', () {
    expect(builtInActionNames, {
      'view_screen',
      'navigate',
      'save_memory',
      'delete_memory',
    });
  });
}
