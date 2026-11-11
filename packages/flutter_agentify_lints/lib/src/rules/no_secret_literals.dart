import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Shapes of well-known API keys and private keys.
///
/// flutter_agentify_core keeps the same list, in the same order, for its
/// asset scan and runtime redaction; change both together.
final List<RegExp> secretPatterns = [
  RegExp(r'(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}'),
  RegExp(r'AIza[0-9A-Za-z_-]{35}'),
  RegExp(r'gh[pousr]_[A-Za-z0-9]{36,}'),
  RegExp(r'github_pat_[A-Za-z0-9_]{22,}'),
  RegExp(r'xox[abprs]-[A-Za-z0-9-]{10,}'),
  RegExp(r'(?<![A-Z0-9])AKIA[0-9A-Z]{16}'),
  RegExp(r'(?<![A-Za-z0-9])[sr]k_(?:live|test)_[A-Za-z0-9]{20,}'),
  RegExp(r'(?<![A-Za-z0-9])gsk_[A-Za-z0-9]{20,}'),
  RegExp(r'(?<![A-Za-z0-9])hf_[A-Za-z0-9]{30,}'),
  RegExp(r'(?<![A-Za-z0-9])xai-[A-Za-z0-9]{40,}'),
  RegExp(
    r'(?<![A-Za-z0-9_-])eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}',
  ),
  RegExp(r'[Bb]earer\s+(?=[A-Za-z0-9._~+/=-]*\d)[A-Za-z0-9._~+/=-]{20,}'),
  RegExp(
    r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|$)',
  ),
];

bool looksLikeSecret(String text) =>
    secretPatterns.any((p) => p.hasMatch(text));

/// Keys never go in source: anything compiled into an app can be read back
/// out of it. Applies to every Dart file, tests included.
class NoSecretLiterals extends AnalysisRule {
  static const LintCode code = LintCode(
    'no_secret_literals',
    'This looks like an API key. Keys never go in source.',
    correctionMessage:
        'Let the user enter the key, or call the model through your own '
        'proxy.',
  );

  NoSecretLiterals()
    : super(
        name: 'no_secret_literals',
        description: 'No API-key-looking string literals in source.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry.addSimpleStringLiteral(this, visitor);
    registry.addAdjacentStrings(this, visitor);
    registry.addStringInterpolation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) => _check(node);

  /// `'sk-' 'abc…'` is one string.
  @override
  void visitAdjacentStrings(AdjacentStrings node) => _check(node);

  @override
  void visitStringInterpolation(StringInterpolation node) => _check(node);

  void _check(StringLiteral node) {
    // A part of a larger literal is checked with it.
    if (node.parent is AdjacentStrings) return;
    if (_segments(node).any(looksLikeSecret)) rule.reportAtNode(node);
  }

  /// The fixed text of [node], cut where an interpolated value comes in.
  List<String> _segments(StringLiteral node) {
    switch (node) {
      case SimpleStringLiteral(:final value):
        return [value];
      case StringInterpolation(:final elements):
        return [
          for (final e in elements.whereType<InterpolationString>()) e.value,
        ];
      case AdjacentStrings(:final strings):
        final result = <String>[];
        final joined = StringBuffer();
        for (final part in strings) {
          if (part is SimpleStringLiteral) {
            joined.write(part.value);
          } else {
            result
              ..add(joined.toString())
              ..addAll(_segments(part));
            joined.clear();
          }
        }
        return result..add(joined.toString());
    }
  }
}
