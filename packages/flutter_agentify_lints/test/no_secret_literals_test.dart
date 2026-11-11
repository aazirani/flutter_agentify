import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_agentify_lints/src/rules/no_secret_literals.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

// Every fake key is built from pieces, so this file never holds one as a
// single literal (the rule runs on test folders too).
@reflectiveTest
class NoSecretLiteralsTest extends AnalysisRuleTest with RuleTestSupport {
  @override
  void setUp() {
    rule = NoSecretLiterals();
    super.setUp();
  }

  Future<void> _expectLintFor(String key) async {
    final code = "const k = '$key';\n";
    await assertDiagnostics(code, [at(code, "'$key'")]);
  }

  void test_openai_style_key() async {
    await _expectLintFor('sk-' + 'a' * 30);
  }

  void test_google_key() async {
    await _expectLintFor('AIza' + 'b' * 35);
  }

  void test_private_key_header() async {
    await _expectLintFor('-----BEGIN RSA ' + 'PRIVATE KEY-----');
  }

  void test_aws_key() async {
    await _expectLintFor('AKIA' + 'A' * 16);
  }

  void test_stripe_live_key() async {
    await _expectLintFor('sk_' + 'live_' + 'a' * 24);
  }

  void test_github_fine_grained_token() async {
    await _expectLintFor('github_' + 'pat_' + 'a' * 30);
  }

  void test_groq_key() async {
    await _expectLintFor('gsk_' + 'a' * 30);
  }

  void test_hugging_face_token() async {
    await _expectLintFor('hf_' + 'a' * 34);
  }

  void test_xai_key() async {
    await _expectLintFor('xai-' + 'a' * 60);
  }

  void test_jwt() async {
    await _expectLintFor('eyJ' + 'a' * 12 + '.eyJ' + 'b' * 12 + '.' + 'c' * 12);
  }

  void test_bearer_token() async {
    await _expectLintFor('Bearer ' + 'abc123' * 5);
  }

  void test_stripe_test_key() async {
    await _expectLintFor('sk_' + 'test_' + 'a' * 24);
  }

  void test_adjacent_strings_key() async {
    final code = "const k = 'sk-' '${'a' * 30}';\n";
    await assertDiagnostics(code, [at(code, "'sk-' '${'a' * 30}'")]);
  }

  void test_key_after_interpolation_in_same_literal() async {
    final code = "String f(String a) => '\$a sk-${'a' * 30}';\n";
    await assertDiagnostics(code, [at(code, "'\$a sk-${'a' * 30}'")]);
  }

  void test_ordinary_words_allowed() async {
    await assertNoDiagnostics(
      "const k = ['half_${'x' * 40}', 'Bearer authentication', "
      "'hf_short', 'gsk_x', 'xai-short', 'eyJ.eyJ.x', "
      "'Bearer ${'a' * 30}'];\n",
    );
  }

  void test_short_sk_allowed() async {
    await assertNoDiagnostics("const k = 'sk-short';\n");
  }

  void test_sk_inside_a_word_allowed() async {
    await assertNoDiagnostics("const k = '${'risk-' + 'assessment-' * 3}';\n");
  }

  void test_applies_in_test_folder() async {
    final path = '$testPackageRootPath/test/a_test.dart';
    final key = 'sk-' + 'a' * 30;
    final code = "const k = '$key';\n";
    newFile(path, code);
    await assertDiagnosticsInFile(path, [at(code, "'$key'")]);
  }
}

void main() =>
    defineReflectiveSuite(() => defineReflectiveTests(NoSecretLiteralsTest));
