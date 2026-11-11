import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../flutter_elements.dart';

/// Navigation goes through GoRouter, so screens never push routes with
/// Flutter's `Navigator`. Popping is still allowed (dialogs, sheets).
class NoNavigatorPush extends AnalysisRule {
  static const LintCode code = LintCode(
    'no_navigator_push',
    'Navigate with GoRouter, not Navigator.',
    correctionMessage: 'Use context.go or context.push.',
  );

  NoNavigatorPush()
    : super(
        name: 'no_navigator_push',
        description: 'Navigation goes through GoRouter, not Navigator.push.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final method = node.methodName.name;
    final pushes =
        method.startsWith('push') ||
        method.startsWith('restorablePush') ||
        method == 'popAndPushNamed';
    if (!pushes) return;

    final target = node.target;
    if (target == null) return;
    // `Navigator.push` and `material.Navigator.push`.
    final onNavigatorClass = switch (target) {
      SimpleIdentifier(:final element) => isFlutterElement(
        element,
        'Navigator',
      ),
      PrefixedIdentifier(:final identifier) => isFlutterElement(
        identifier.element,
        'Navigator',
      ),
      _ => false,
    };
    final type = target.staticType;
    final onNavigatorState =
        type is InterfaceType &&
        isFlutterElement(type.element, 'NavigatorState');
    if (onNavigatorClass || onNavigatorState) rule.reportAtNode(node);
  }
}
