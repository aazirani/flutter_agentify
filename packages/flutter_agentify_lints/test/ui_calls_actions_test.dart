import 'package:analyzer/error/error.dart';
// ignore: implementation_imports
import 'package:analyzer/src/diagnostic/diagnostic.dart' as diag;
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_agentify_lints/src/rules/ui_calls_actions.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

@reflectiveTest
class UiCallsActionsTest extends AnalysisRuleTest with RuleTestSupport {
  // Each fixture imports everything; not every test uses every import.
  @override
  List<DiagnosticCode> get ignoredDiagnosticCodes => [
    ...super.ignoredDiagnosticCodes,
    diag.unusedImport,
  ];

  @override
  void setUp() {
    addCoreStubs();
    rule = UiCallsActions();
    super.setUp();
    newFile('$testPackageLibPath/domain/repositories/items_repository.dart', '''
abstract class ItemsRepository {
  Stream<List<String>> watchItems();
  Future<String?> getItem(String id);
  Future<void> createItem({required String title});
}
''');
    newFile('$testPackageLibPath/domain/entities/item.dart', '''
class Item {
  Map<String, Object?> toJson() => {};
}
''');
    newFile('$testPackageLibPath/domain/actions/create_item.dart', '''
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
class CreateItem extends AgentAction<String, String> {
  @override
  Future<String> run(String input, Object context) async => input;
}
''');
  }

  String _code(String body) =>
      '''
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:test/domain/actions/create_item.dart';
import 'package:test/domain/entities/item.dart';
import 'package:test/domain/repositories/items_repository.dart';
void f(
  ItemsRepository repo,
  ActionRegistry registry,
  Item item,
  ThreadStore threads,
  MemoryStore memories,
  ApprovalPrefs approvalPrefs,
) { $body }
''';

  Future<void> _expect(
    String body,
    String? lintAt, {
    String folder = 'presentation',
  }) async {
    final path = '$testPackageLibPath/$folder/a.dart';
    final code = _code(body);
    newFile(path, code);
    await assertDiagnosticsInFile(path, [if (lintAt != null) at(code, lintAt)]);
  }

  void test_repository_write() async {
    await _expect(
      "repo.createItem(title: 'x');",
      "repo.createItem(title: 'x')",
    );
  }

  void test_repository_watch_and_get() async {
    await _expect("repo.watchItems(); repo.getItem('a');", null);
  }

  void test_action_run_directly() async {
    await _expect(
      "CreateItem().run('x', Object());",
      "CreateItem().run('x', Object())",
    );
  }

  void test_registry_run() async {
    await _expect("registry.run(CreateItem(), 'x');", null);
  }

  void test_entity_method() async {
    await _expect('item.toJson();', null);
  }

  void test_core_store_write() async {
    await _expect("threads.deleteThread('a');", "threads.deleteThread('a')");
    await _expect("memories.save('x');", "memories.save('x')");
  }

  void test_core_store_read() async {
    await _expect(
      "threads.threads(); memories.all(); approvalPrefs.isAlwaysAllowed('a');",
      null,
    );
  }

  void test_approval_prefs_clear() async {
    await _expect('approvalPrefs.clear();', 'approvalPrefs.clear()');
  }

  void test_repository_write_tear_off() async {
    await _expect(
      'final g = repo.createItem; g(title: "x");',
      'repo.createItem',
    );
  }

  void test_repository_read_tear_off() async {
    await _expect('final g = repo.watchItems; g();', null);
  }

  void test_outside_presentation() async {
    await _expect("repo.createItem(title: 'x');", null, folder: 'ai');
  }
}

void main() =>
    defineReflectiveSuite(() => defineReflectiveTests(UiCallsActionsTest));
