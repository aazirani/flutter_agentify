import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_agentify_lints/src/rules/no_raw_sql_interpolation.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

const _db = '''
class Db {
  void customSelect(String sql) {}
  void customStatement(String sql) {}
  void rawQuery(String sql) {}
  void execute(String sql) {}
}
void log(String message) {}
''';

@reflectiveTest
class NoRawSqlInterpolationTest extends AnalysisRuleTest with RuleTestSupport {
  @override
  void setUp() {
    rule = NoRawSqlInterpolation();
    super.setUp();
  }

  String _code(String statement) =>
      '${_db}void f(Db db, String id) { $statement }\n';

  void test_interpolated_customSelect() async {
    final code = _code(r"db.customSelect('SELECT * FROM t WHERE id = $id');");
    await assertDiagnostics(code, [
      at(code, r"'SELECT * FROM t WHERE id = $id'"),
    ]);
  }

  void test_concatenated_rawQuery() async {
    final code = _code("db.rawQuery('SELECT * FROM t WHERE id = ' + id);");
    await assertDiagnostics(code, [
      at(code, "'SELECT * FROM t WHERE id = ' + id"),
    ]);
  }

  void test_adjacent_strings_with_interpolation() async {
    final code = _code(
      r"db.customSelect('SELECT * FROM t ' 'WHERE id = $id');",
    );
    await assertDiagnostics(code, [
      at(code, r"'SELECT * FROM t ' 'WHERE id = $id'"),
    ]);
  }

  void test_execute_with_sql_text() async {
    final code = _code(r"db.execute('DELETE FROM t WHERE id = $id');");
    await assertDiagnostics(code, [
      at(code, r"'DELETE FROM t WHERE id = $id'"),
    ]);
  }

  void test_execute_with_other_text_allowed() async {
    await assertNoDiagnostics(_code(r"db.execute('Hello $id');"));
  }

  void test_plain_literal_allowed() async {
    await assertNoDiagnostics(
      _code("db.customSelect('SELECT * FROM t WHERE id = ?');"),
    );
  }

  void test_other_method_allowed() async {
    await assertNoDiagnostics(_code(r"log('value $id');"));
  }
}

void main() => defineReflectiveSuite(
  () => defineReflectiveTests(NoRawSqlInterpolationTest),
);
