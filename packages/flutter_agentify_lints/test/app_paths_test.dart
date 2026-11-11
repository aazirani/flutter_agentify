import 'package:flutter_agentify_lints/src/app_paths.dart';
import 'package:test/test.dart';

void main() {
  test('libRelativePath', () {
    expect(libRelativePath('/a/app/lib/domain/x.dart'), 'domain/x.dart');
    expect(libRelativePath(r'C:\a\app\lib\domain\x.dart'), 'domain/x.dart');
    expect(libRelativePath('/a/lib/b/lib/c.dart'), 'c.dart');
    expect(libRelativePath('/a/app/test/x.dart'), isNull);
  });
}
