import 'package:analyzer/error/error.dart';
// ignore: implementation_imports
import 'package:analyzer/src/diagnostic/diagnostic.dart' as diag;
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_agentify_lints/src/rules/layer_boundaries.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

@reflectiveTest
class DomainLayerBoundariesTest extends AnalysisRuleTest with RuleTestSupport {
  // Fixture imports are never used, and the test SDK has no dart:ui.
  @override
  List<DiagnosticCode> get ignoredDiagnosticCodes => [
    ...super.ignoredDiagnosticCodes,
    diag.unusedImport,
    diag.uriDoesNotExist,
  ];

  @override
  void setUp() {
    addFlutterStubs();
    rule = DomainLayerBoundaries();
    super.setUp();
    newFile('$testPackageLibPath/data/b.dart', 'class B {}\n');
    newFile('$testPackageLibPath/presentation/b.dart', 'class P {}\n');
    newFile('$testPackageLibPath/domain/b.dart', 'class D {}\n');
  }

  String get _domain => '$testPackageLibPath/domain/a.dart';
  String get _data => '$testPackageLibPath/data/a.dart';

  Future<void> _expectLint(String path, String import) async {
    final code = "import '$import';\n";
    newFile(path, code);
    await assertDiagnosticsInFile(path, [at(code, code.trim())]);
  }

  Future<void> _expectNone(String path, String import) async {
    newFile(path, "import '$import';\n");
    await assertNoDiagnosticsInFile(path);
  }

  void test_domain_imports_flutter() async {
    await _expectLint(_domain, 'package:flutter/widgets.dart');
  }

  void test_domain_imports_dart_ui() async {
    await _expectLint(_domain, 'dart:ui');
  }

  void test_domain_imports_data_package_uri() async {
    await _expectLint(_domain, 'package:test/data/b.dart');
  }

  void test_domain_imports_data_relative() async {
    await _expectLint(_domain, '../data/b.dart');
  }

  void test_domain_imports_presentation() async {
    await _expectLint(_domain, 'package:test/presentation/b.dart');
  }

  void test_domain_imports_domain() async {
    await _expectNone(_domain, 'package:test/domain/b.dart');
  }

  void test_domain_imports_other_flutter_package() async {
    await _expectLint(
      _domain,
      'package:flutter_riverpod/flutter_riverpod.dart',
    );
    await _expectLint(
      _domain,
      'package:flutter_localizations/flutter_localizations.dart',
    );
  }

  void test_domain_imports_agentify_core() async {
    await _expectNone(_domain, 'package:flutter_agentify_core/a.dart');
  }

  void test_domain_exports_flutter() async {
    const code = "export 'package:flutter/widgets.dart';\n";
    newFile(_domain, code);
    await assertDiagnosticsInFile(_domain, [at(code, code.trim())]);
  }

  void test_domain_exports_data() async {
    const code = "export '../data/b.dart';\n";
    newFile(_domain, code);
    await assertDiagnosticsInFile(_domain, [at(code, code.trim())]);
  }

  void test_data_imports_flutter() async {
    await _expectNone(_data, 'package:flutter/widgets.dart');
  }
}

void main() {
  test('layerOf', () {
    expect(layerOf('domain/x.dart'), 'domain');
    expect(layerOf('core/x.dart'), isNull);
    expect(layerOf(null), isNull);
  });
  defineReflectiveSuite(() => defineReflectiveTests(DomainLayerBoundariesTest));
}
