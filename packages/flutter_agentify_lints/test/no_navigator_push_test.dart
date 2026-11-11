import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_agentify_lints/src/rules/no_navigator_push.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

@reflectiveTest
class NoNavigatorPushTest extends AnalysisRuleTest with RuleTestSupport {
  @override
  void setUp() {
    addFlutterStubs();
    rule = NoNavigatorPush();
    super.setUp();
  }

  void test_static_push() async {
    const code = '''
import 'package:flutter/widgets.dart';
void f(BuildContext c) { Navigator.push(c, Object()); }
''';
    await assertDiagnostics(code, [at(code, 'Navigator.push(c, Object())')]);
  }

  void test_state_pushNamed() async {
    const code = '''
import 'package:flutter/widgets.dart';
void f(BuildContext c) { Navigator.of(c).pushNamed('/x'); }
''';
    await assertDiagnostics(code, [
      at(code, "Navigator.of(c).pushNamed('/x')"),
    ]);
  }

  void test_prefixed_static_push() async {
    const code = '''
import 'package:flutter/widgets.dart' as w;
void f(w.BuildContext c) { w.Navigator.push(c, Object()); }
''';
    await assertDiagnostics(code, [at(code, 'w.Navigator.push(c, Object())')]);
  }

  void test_pop_is_allowed() async {
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';
void f(BuildContext c) { Navigator.of(c).pop(); Navigator.pop(c); }
''');
  }

  void test_other_push_is_allowed() async {
    await assertNoDiagnostics('''
class Stack { void push(int v) {} }
void f(Stack s) { s.push(1); }
''');
  }
}

void main() =>
    defineReflectiveSuite(() => defineReflectiveTests(NoNavigatorPushTest));
