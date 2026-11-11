import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../app_paths.dart';
import '../flutter_elements.dart';

/// Text the user reads goes through localization, so every language gets it.
/// Literals with no letters (symbols, separators, pure interpolation) pass.
class NoHardcodedStrings extends AnalysisRule {
  static const LintCode code = LintCode(
    'no_hardcoded_strings',
    'User-visible text must come from localization.',
    correctionMessage:
        'Add a key to assets/lang/*.json and use AppLocalizations.',
  );

  NoHardcodedStrings()
    : super(
        name: 'no_hardcoded_strings',
        description: 'User-visible strings go through localization.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (libRelativePath(context.definingUnit.file.path) == null) return;
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }
}

const _textWidgets = {'Text', 'SelectableText'};

const _textParameters = {
  'labelText',
  'hintText',
  'helperText',
  'errorText',
  'tooltip',
  'message',
  'semanticLabel',
  'semanticsLabel',
  'label',
  'text',
  'title',
  'prefixText',
  'suffixText',
};

final _letter = RegExp(r'\p{L}', unicode: true);

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final widget = node.constructorName.type.element;
    if (!isFromFlutter(widget)) return;

    final arguments = node.argumentList.arguments;
    if (_textWidgets.contains(widget?.name)) {
      final positional = arguments.where((a) => a is! NamedArgument);
      if (positional.isNotEmpty) _check(positional.first.argumentExpression);
    }
    for (final argument in arguments.whereType<NamedArgument>()) {
      if (_textParameters.contains(argument.name.lexeme)) {
        _check(argument.argumentExpression);
      }
    }
  }

  void _check(Expression expression) {
    // Both branches of `cond ? 'Yes' : 'No'` are read.
    if (expression is ConditionalExpression) {
      _check(expression.thenExpression);
      _check(expression.elseExpression);
      return;
    }
    if (expression is ParenthesizedExpression) {
      _check(expression.expression);
      return;
    }
    final text = _literalText(expression);
    if (text != null && _letter.hasMatch(text)) rule.reportAtNode(expression);
  }

  /// The fixed text of a string literal (interpolated parts left out), or
  /// `null` when [expression] is not a string literal.
  String? _literalText(Expression expression) => switch (expression) {
    SimpleStringLiteral(:final value) => value,
    AdjacentStrings(:final strings) => strings.map(_literalText).join(),
    StringInterpolation(:final elements) =>
      elements.whereType<InterpolationString>().map((e) => e.value).join(),
    _ => null,
  };
}
