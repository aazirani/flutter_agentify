@Tags(['cli'])
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/cli.dart';

void main() {
  setUp(resetCliDatabase);

  test('create then list round-trips through the CLI', () async {
    final create = await runCli(['create_item', '{"title":"From CLI"}']);
    expect(create.exitCode, 0, reason: '${create.stderr}');
    expect(create.stdout, contains('receipt: Created item "From CLI"'));
    final list = await runCli(['list_items', '{}']);
    expect(list.exitCode, 0, reason: '${list.stderr}');
    expect(list.stdout, contains('From CLI'));
  });

  test('--list names the five item actions', () async {
    final result = await runCli(['--list']);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final names = (result.stdout as String).trim().split('\n');
    expect(
      names,
      containsAll([
        'list_items',
        'get_item',
        'create_item',
        'update_item',
        'delete_item',
      ]),
    );
  });
}
