import 'package:flutter_agentify_core/cli.dart';
import 'package:test/test.dart';

import '../doctor/temp_repo.dart';

void main() {
  test('finds lines containing every word, case-insensitive', () async {
    final docs = await tempRepo({
      'approval.md':
          '# Approval\nAn action that Needs Approval waits.\nApproval only.\n',
      'actions.md': 'Every action needs a test.\n',
    });
    final out = StringBuffer();
    final code = await runDocsSearch(
      ['--query', 'needs approval'],
      docDir: docs,
      out: out,
    );
    expect(code, 0);
    expect(
      out.toString(),
      'approval.md:2: An action that Needs Approval waits.\n',
    );
  });

  test('returns 1 when nothing matches', () async {
    final docs = await tempRepo({'a.md': 'nothing here\n'});
    expect(
      await runDocsSearch(
        ['--query', 'zebra'],
        docDir: docs,
        out: StringBuffer(),
      ),
      1,
    );
  });

  test('--list prints the page names', () async {
    final docs = await tempRepo({'b.md': '', 'a.md': '', 'notes.txt': ''});
    final out = StringBuffer();
    expect(await runDocsSearch(['--list'], docDir: docs, out: out), 0);
    expect(out.toString(), 'a.md\nb.md\n');
  });

  test('no query returns 64', () async {
    final docs = await tempRepo({});
    expect(
      await runDocsSearch(
        [],
        docDir: docs,
        out: StringBuffer(),
        err: StringBuffer(),
      ),
      64,
    );
  });
}
