import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_agentify_lints/src/rules/no_hardcoded_colors.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

@reflectiveTest
class NoHardcodedColorsTest extends AnalysisRuleTest with RuleTestSupport {
  @override
  void setUp() {
    addFlutterStubs();
    rule = NoHardcodedColors();
    super.setUp();
  }

  String get _presentation => '$testPackageLibPath/presentation/a.dart';

  Future<void> _expectLint(String path, String body, String snippet) async {
    final code = "import 'package:flutter/material.dart';\n$body\n";
    newFile(path, code);
    await assertDiagnosticsInFile(path, [at(code, snippet)]);
  }

  Future<void> _expectNone(String path, String body) async {
    newFile(path, "import 'package:flutter/material.dart';\n$body\n");
    await assertNoDiagnosticsInFile(path);
  }

  void test_colors_member() async {
    await _expectLint(_presentation, 'final c = Colors.white;', 'Colors.white');
  }

  void test_color_constructor() async {
    await _expectLint(
      _presentation,
      'final c = Color(0xFF112233);',
      'Color(0xFF112233)',
    );
  }

  void test_color_fromARGB() async {
    await _expectLint(
      _presentation,
      'final c = Color.fromARGB(255, 1, 2, 3);',
      'Color.fromARGB(255, 1, 2, 3)',
    );
  }

  void test_transparent_allowed() async {
    await _expectNone(_presentation, 'final c = Colors.transparent;');
  }

  void test_theme_folder_allowed() async {
    await _expectNone(
      '$testPackageLibPath/core/theme/a.dart',
      'final c = Color(0xFF112233);',
    );
  }

  void test_outside_lib_allowed() async {
    await _expectNone(
      '$testPackageRootPath/test/a_test.dart',
      'final c = Colors.white;',
    );
  }

  void test_unrelated_Colors_class() async {
    newFile(
      _presentation,
      'class Colors { static const white = 1; } final c = Colors.white;\n',
    );
    await assertNoDiagnosticsInFile(_presentation);
  }
}

void main() =>
    defineReflectiveSuite(() => defineReflectiveTests(NoHardcodedColorsTest));
