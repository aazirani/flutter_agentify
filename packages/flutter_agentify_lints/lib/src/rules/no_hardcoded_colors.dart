import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../app_paths.dart';
import '../flutter_elements.dart';

/// Colors come from the theme, so light, dark and custom themes stay
/// consistent. `lib/core/theme/` is where the palette itself is defined.
class NoHardcodedColors extends AnalysisRule {
  static const LintCode code = LintCode(
    'no_hardcoded_colors',
    'Use a theme color, not a hardcoded one.',
    correctionMessage: 'Use Theme.of(context).colorScheme or a theme token.',
  );

  NoHardcodedColors()
    : super(
        name: 'no_hardcoded_colors',
        description: 'Colors come from theme tokens, not literals.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final path = libRelativePath(context.definingUnit.file.path);
    if (path == null || path.startsWith('core/theme/')) return;
    final visitor = _Visitor(this);
    registry
      ..addPrefixedIdentifier(this, visitor)
      ..addPropertyAccess(this, visitor)
      ..addInstanceCreationExpression(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _checkColorsMember(node, node.prefix, node.identifier.name);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    // `material.Colors.white`: the target is the prefixed class name.
    if (target is PrefixedIdentifier) {
      _checkColorsMember(node, target.identifier, node.propertyName.name);
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (isFlutterElement(node.constructorName.type.element, 'Color')) {
      rule.reportAtNode(node);
    }
  }

  void _checkColorsMember(AstNode node, SimpleIdentifier owner, String name) {
    if (name == 'transparent') return;
    if (isFlutterElement(owner.element, 'Colors')) rule.reportAtNode(node);
  }
}
