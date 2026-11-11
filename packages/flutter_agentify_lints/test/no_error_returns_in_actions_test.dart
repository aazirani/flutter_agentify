import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_agentify_lints/src/rules/no_error_returns_in_actions.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

@reflectiveTest
class NoErrorReturnsInActionsTest extends AnalysisRuleTest
    with RuleTestSupport {
  @override
  void setUp() {
    addCoreStubs();
    rule = NoErrorReturnsInActions();
    super.setUp();
  }

  String _action(
    String returned, {
    String base = 'AgentAction<String, Object?>',
  }) =>
      '''
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
class Find extends $base {
  @override
  Future<Object?> run(String input, Object context) async {
    if (input.isEmpty) return $returned;
    return {'id': '1'};
  }
}
''';

  void test_error_map() async {
    final code = _action("{'error': 'nope'}");
    await assertDiagnostics(code, [at(code, "return {'error': 'nope'};")]);
  }

  void test_success_false() async {
    final code = _action("{'success': false}");
    await assertDiagnostics(code, [at(code, "return {'success': false};")]);
  }

  void test_error_string() async {
    final code = _action("'Error: not found'");
    await assertDiagnostics(code, [at(code, "return 'Error: not found';")]);
  }

  void test_could_not_string() async {
    final code = _action("'Could not find it'");
    await assertDiagnostics(code, [at(code, "return 'Could not find it';")]);
  }

  void test_normal_return() async {
    await assertNoDiagnostics(_action("{'id': '2'}"));
  }

  void test_other_class() async {
    await assertNoDiagnostics('''
class Helper {
  Future<Object?> run(String input, Object context) async {
    return {'error': 'nope'};
  }
}
''');
  }

  void test_other_method_of_an_action() async {
    await assertNoDiagnostics('''
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
class Find extends AgentAction<String, Object?> {
  @override
  Future<Object?> run(String input, Object context) async => {'id': '1'};
  Object? describe() { return {'error': 'fine here'}; }
}
''');
  }
}

void main() => defineReflectiveSuite(
  () => defineReflectiveTests(NoErrorReturnsInActionsTest),
);
