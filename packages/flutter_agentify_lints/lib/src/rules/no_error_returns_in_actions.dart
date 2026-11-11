import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import 'agent_action_types.dart';

final _errorText = RegExp(
  r'^\s*(error|failed|failure|could not|unable to)',
  caseSensitive: false,
);

/// An action reports failure by throwing `ActionFailure`; a returned error
/// value reads as success to the model and to the screen.
class NoErrorReturnsInActions extends AnalysisRule {
  static const LintCode code = LintCode(
    'no_error_returns_in_actions',
    'Throw ActionFailure instead of returning an error value.',
    correctionMessage: "Use throw ActionFailure('code', 'message').",
  );

  NoErrorReturnsInActions()
    : super(
        name: 'no_error_returns_in_actions',
        description: 'Actions throw typed failures, never return errors.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme != 'run') return;
    final owner = node.declaredFragment?.element.enclosingElement;
    if (owner is! InterfaceElement || !isAgentAction(owner)) return;

    final body = node.body;
    if (body is ExpressionFunctionBody) {
      if (_isErrorValue(body.expression)) rule.reportAtNode(body.expression);
      return;
    }
    body.accept(_Returns(rule));
  }
}

/// Visits the returns of one method body, not of nested functions.
class _Returns extends RecursiveAstVisitor<void> {
  _Returns(this.rule);

  final AnalysisRule rule;

  @override
  void visitReturnStatement(ReturnStatement node) {
    final value = node.expression;
    if (value != null && _isErrorValue(value)) rule.reportAtNode(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {}
}

bool _isErrorValue(Expression expression) => switch (expression) {
  SetOrMapLiteral(:final elements) => elements.any(
    (e) =>
        e is MapLiteralEntry &&
        switch ((e.key, e.value)) {
          (SimpleStringLiteral(value: 'error' || 'errors'), _) => true,
          (
            SimpleStringLiteral(value: 'success'),
            BooleanLiteral(value: false),
          ) =>
            true,
          _ => false,
        },
  ),
  SimpleStringLiteral(:final value) => _errorText.hasMatch(value),
  _ => false,
};
