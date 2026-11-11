import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../app_paths.dart';

/// SQL built from strings is open to injection; values go in as bound
/// variables instead.
class NoRawSqlInterpolation extends AnalysisRule {
  static const LintCode code = LintCode(
    'no_raw_sql_interpolation',
    'Build SQL with bound variables, not string interpolation.',
    correctionMessage: 'Use ? placeholders and pass the values as variables.',
  );

  NoRawSqlInterpolation()
    : super(
        name: 'no_raw_sql_interpolation',
        description: 'No string-built SQL.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (libRelativePath(context.definingUnit.file.path) == null) return;
    registry.addMethodInvocation(this, _Visitor(this));
  }
}

const _sqlMethods = {
  'customSelect',
  'customStatement',
  'customUpdate',
  'customInsert',
  'rawQuery',
  'rawInsert',
  'rawUpdate',
  'rawDelete',
};

/// Names other APIs use too (`Process.execute('Hello $name')`): flagged only
/// when the text starts like SQL.
const _genericMethods = {'execute'};

final _sqlStart = RegExp(
  r'^\s*(select|insert|update|delete|create|drop|alter|pragma|with|replace)\b',
  caseSensitive: false,
);

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    final generic = _genericMethods.contains(name);
    if (!generic && !_sqlMethods.contains(name)) return;
    final positional = node.argumentList.arguments.where(
      (a) => a is! NamedArgument,
    );
    if (positional.isEmpty) return;
    final sql = positional.first.argumentExpression;
    final built =
        sql is StringInterpolation ||
        (sql is AdjacentStrings &&
            sql.strings.any((part) => part is StringInterpolation)) ||
        (sql is BinaryExpression && sql.operator.type == TokenType.PLUS);
    if (!built) return;
    if (generic && !_sqlStart.hasMatch(_leadingText(sql) ?? '')) return;
    rule.reportAtNode(sql);
  }

  /// The fixed text a string expression starts with, if it starts with one.
  String? _leadingText(Expression e) => switch (e) {
    SimpleStringLiteral(:final value) => value,
    StringInterpolation(:final elements) =>
      elements.first is InterpolationString
          ? (elements.first as InterpolationString).value
          : null,
    AdjacentStrings(:final strings) => _leadingText(strings.first),
    BinaryExpression(:final leftOperand) => _leadingText(leftOperand),
    _ => null,
  };
}
