import 'package:flutter_agentify_core/doctor.dart';
import 'package:test/test.dart';

import 'temp_repo.dart';

void main() {
  test(
    'dead relative links fail; anchors, web links and code blocks do not',
    () async {
      final root = await tempRepo({
        'README.md':
            '[ok](docs/a.md#part) [web](https://x.dev) [top](#top) [dead](docs/gone.md)\n'
            '```\n[in code](nope.md)\n```\n',
        'docs/a.md':
            '[up](../README.md) [space](my%20file.md) ![pic](img/none.png)',
        'docs/my file.md': '',
        'packages/p/doc/x.md': '[bad](../../missing.md)',
      });
      final result = await DocLinksCheck().run(DoctorContext(root: root));
      expect(result.status, CheckStatus.fail);
      expect(result.messages, hasLength(3));
      expect(
        result.messages.join('\n'),
        allOf(
          contains('README.md:1: docs/gone.md'),
          contains('img/none.png'),
          contains('missing.md'),
        ),
      );
    },
  );

  test('a repo without docs passes', () async {
    final root = await tempRepo({'README.md': 'hello'});
    expect(
      (await DocLinksCheck().run(DoctorContext(root: root))).status,
      CheckStatus.pass,
    );
  });
}
