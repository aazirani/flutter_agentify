@Tags(['template'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/apply_tutorial.dart';

const _tutorial = '''
Create `lib/a.dart`:

```dart
const a = 1;
```

Replace `lib/b.dart` with:

```dart
const b = 2;
```

In `lib/b.dart`, replace:

```dart
const b = 2;
```

with:

```dart
const b = 3;
```

```bash
flutter run
```
''';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('tutorial_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/lib/b.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('const b = 0;\n');
  });

  test('creates, replaces and edits files as the steps say', () {
    expect(applyTutorial(_tutorial, dir.path), isEmpty);
    expect(File('${dir.path}/lib/a.dart').readAsStringSync(), 'const a = 1;\n');
    expect(File('${dir.path}/lib/b.dart').readAsStringSync(), 'const b = 3;\n');
  });

  test('an edit whose text is not found exactly once is reported', () {
    final problems = applyTutorial(
      _tutorial.replaceFirst(
        'const b = 2;\n```\n\nwith',
        'const b = 9;\n```\n\nwith',
      ),
      dir.path,
    );
    expect(problems.single, contains('found 0 times'));
  });

  test('an edit introduced mid-sentence is applied too', () {
    const tutorial = '''
A test lists it. In `lib/b.dart`, replace:

```dart
const b = 0;
```

with:

```dart
const b = 5;
```
''';
    expect(applyTutorial(tutorial, dir.path), isEmpty);
    expect(File('${dir.path}/lib/b.dart').readAsStringSync(), 'const b = 5;\n');
  });

  test('a step it cannot read is reported, not skipped', () {
    expect(
      applyTutorial('Then in `lib/b.dart` replace:\n', dir.path).single,
      contains('cannot read'),
    );
  });
}
