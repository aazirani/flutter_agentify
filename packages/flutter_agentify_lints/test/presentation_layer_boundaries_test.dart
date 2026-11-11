import 'package:analyzer/error/error.dart';
// ignore: implementation_imports
import 'package:analyzer/src/diagnostic/diagnostic.dart' as diag;
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_agentify_lints/src/rules/layer_boundaries.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

@reflectiveTest
class PresentationLayerBoundariesTest extends AnalysisRuleTest
    with RuleTestSupport {
  // Fixture imports are never used.
  @override
  List<DiagnosticCode> get ignoredDiagnosticCodes => [
    ...super.ignoredDiagnosticCodes,
    diag.unusedImport,
  ];

  @override
  void setUp() {
    rule = PresentationLayerBoundaries();
    super.setUp();
    newFile('$testPackageLibPath/data/b.dart', 'class B {}\n');
    newFile('$testPackageLibPath/domain/b.dart', 'class D {}\n');
  }

  String get _presentation => '$testPackageLibPath/presentation/a.dart';

  void test_imports_data() async {
    const code = "import 'package:test/data/b.dart';\n";
    newFile(_presentation, code);
    await assertDiagnosticsInFile(_presentation, [at(code, code.trim())]);
  }

  void test_imports_domain() async {
    newFile(_presentation, "import 'package:test/domain/b.dart';\n");
    await assertNoDiagnosticsInFile(_presentation);
  }

  void test_relative_import_of_data() async {
    const code = "import '../data/b.dart';\n";
    newFile(_presentation, code);
    await assertDiagnosticsInFile(_presentation, [at(code, code.trim())]);
  }
}

void main() => defineReflectiveSuite(
  () => defineReflectiveTests(PresentationLayerBoundariesTest),
);
