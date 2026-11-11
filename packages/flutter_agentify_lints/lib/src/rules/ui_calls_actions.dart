import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../app_paths.dart';
import 'agent_action_types.dart';
import 'layer_boundaries.dart';

/// Screens change data only through `registry.run(action, input)`, so the
/// assistant can do the same and every change is recorded. They may read
/// through repository members named `watch…` or `get…`, and through the
/// reading members of the core stores.
class UiCallsActions extends AnalysisRule {
  static const LintCode code = LintCode(
    'ui_calls_actions',
    'Change data through an action: registry.run(...), not {0}.',
    correctionMessage:
        'Add or reuse an action in lib/domain/actions/ and call it with '
        'registry.run.',
  );

  UiCallsActions()
    : super(
        name: 'ui_calls_actions',
        description: 'Screens change data only through actions.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final path = libRelativePath(context.definingUnit.file.path);
    if (layerOf(path) != 'presentation') return;
    final visitor = _Visitor(this);
    registry
      ..addMethodInvocation(this, visitor)
      ..addPrefixedIdentifier(this, visitor)
      ..addPropertyAccess(this, visitor);
  }
}

/// The members of flutter_agentify_core's stores that change data.
const _coreStoreWrites = {
  'ThreadStore': {'createThread', 'append', 'summarize', 'deleteThread'},
  'MemoryStore': {'save', 'delete'},
  'ApprovalPrefs': {'setAlwaysAllowed', 'clear'},
};

bool _writesCoreStore(InterfaceType type, String method) {
  bool isWrite(InterfaceType t) =>
      t.element.library.uri.toString().startsWith(
        'package:flutter_agentify_core/',
      ) &&
      (_coreStoreWrites[t.element.name]?.contains(method) ?? false);
  return isWrite(type) || type.element.allSupertypes.any(isWrite);
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitMethodInvocation(MethodInvocation node) =>
      _check(node, node.realTarget?.staticType, node.methodName.name);

  // Tear-offs such as `onPressed: repo.deleteItem`.
  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.element is! MethodElement) return;
    _check(node, node.prefix.staticType, node.identifier.name);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.element is! MethodElement) return;
    _check(node, node.realTarget.staticType, node.propertyName.name);
  }

  void _check(AstNode node, DartType? type, String method) {
    if (type is! InterfaceType) return;
    final typeName = type.element.name ?? '';

    final library = type.element.library.firstFragment.source.fullName;
    final fromRepositories =
        libRelativePath(library)?.startsWith('domain/repositories/') ?? false;
    final reads = method.startsWith('watch') || method.startsWith('get');
    final writesRepository = fromRepositories && !reads;
    final runsActionDirectly = method == 'run' && isAgentAction(type.element);

    if (writesRepository ||
        runsActionDirectly ||
        _writesCoreStore(type, method)) {
      rule.reportAtNode(node, arguments: ['$typeName.$method']);
    }
  }
}
