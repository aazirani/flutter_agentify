import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_agentify_lints/src/rules/no_hardcoded_strings.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

@reflectiveTest
class NoHardcodedStringsTest extends AnalysisRuleTest with RuleTestSupport {
  @override
  void setUp() {
    addFlutterStubs();
    rule = NoHardcodedStrings();
    super.setUp();
  }

  String get _presentation => '$testPackageLibPath/presentation/a.dart';

  String _code(String body) =>
      "import 'package:flutter/material.dart';\n$body\n";

  Future<void> _expectLint(String body, String snippet) async {
    final code = _code(body);
    newFile(_presentation, code);
    await assertDiagnosticsInFile(_presentation, [at(code, snippet)]);
  }

  Future<void> _expectNone(String body, {String? path}) async {
    final file = path ?? _presentation;
    newFile(file, _code(body));
    await assertNoDiagnosticsInFile(file);
  }

  void test_text_literal() async {
    await _expectLint("final w = Text('Settings');", "'Settings'");
  }

  void test_text_interpolated() async {
    await _expectLint(
      r"Widget f(String name) => Text('Hello $name');",
      r"'Hello $name'",
    );
  }

  void test_only_interpolation_allowed() async {
    await _expectNone(r"Widget f(String a, String b) => Text('$a $b');");
  }

  void test_symbol_allowed() async {
    await _expectNone("final w = Text('•');");
  }

  void test_empty_allowed() async {
    await _expectNone("final w = Text('');");
  }

  void test_semantics_label() async {
    await _expectLint("final w = Semantics(label: 'Close');", "'Close'");
  }

  void test_tab_text() async {
    await _expectLint("final w = Tab(text: 'Home');", "'Home'");
  }

  void test_text_span() async {
    await _expectLint(
      "final w = Text.rich(TextSpan(text: 'Hello'));",
      "'Hello'",
    );
  }

  void test_conditional_text() async {
    final code = _code("Widget f(bool b) => Text(b ? 'Yes' : 'No');");
    newFile(_presentation, code);
    await assertDiagnosticsInFile(_presentation, [
      at(code, "'Yes'"),
      at(code, "'No'"),
    ]);
  }

  void test_conditional_without_letters_allowed() async {
    await _expectNone("Widget f(bool b) => Text(b ? '+' : '-');");
  }

  void test_decoration_label() async {
    await _expectLint(
      "final d = InputDecoration(labelText: 'Title');",
      "'Title'",
    );
  }

  void test_tooltip() async {
    await _expectLint("final w = IconButton(tooltip: 'Close');", "'Close'");
  }

  void test_variable_allowed() async {
    await _expectNone('Widget f(String s) => Text(s);');
  }

  void test_outside_lib_allowed() async {
    await _expectNone(
      "final w = Text('Settings');",
      path: '$testPackageRootPath/test/a_test.dart',
    );
  }
}

void main() =>
    defineReflectiveSuite(() => defineReflectiveTests(NoHardcodedStringsTest));
