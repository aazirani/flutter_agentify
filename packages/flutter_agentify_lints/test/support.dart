import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/src/analysis_rule/pub_package_resolution.dart';

/// Shared helpers for the rule tests.
mixin RuleTestSupport on AnalysisRuleTest {
  /// Adds a small stand-in for `package:flutter` with the members the rules
  /// look at.
  void addFlutterStubs() {
    newPackage('flutter')
      ..addFile('lib/widgets.dart', _widgets)
      ..addFile('lib/material.dart', _material);
  }

  /// Adds a stand-in for `package:flutter_agentify_core` with the action
  /// types the rules look at.
  void addCoreStubs() {
    newPackage('flutter_agentify_core')
        .addFile('lib/flutter_agentify_core.dart', _core);
  }

  /// The lint expected at the first occurrence of [snippet] in [code].
  ExpectedDiagnostic at(String code, String snippet) =>
      lint(code.indexOf(snippet), snippet.length);
}

const _widgets = r'''
class BuildContext {}

abstract class Widget {
  const Widget();
}

class NavigatorState {
  Future<T?> push<T>(Object route) async => null;
  Future<T?> pushNamed<T>(String name) async => null;
  Future<T?> pushReplacement<T>(Object route) async => null;
  void pop<T>([T? result]) {}
}

class Navigator {
  static NavigatorState of(BuildContext context) => NavigatorState();
  static Future<T?> push<T>(BuildContext context, Object route) async => null;
  static Future<T?> pushNamed<T>(BuildContext context, String name) async =>
      null;
  static void pop<T>(BuildContext context, [T? result]) {}
}

class Color {
  const Color(int value);
  const Color.fromARGB(int a, int r, int g, int b);
  const Color.fromRGBO(int r, int g, int b, double opacity);
}

class Text extends Widget {
  const Text(String data, {String? semanticsLabel});
  const Text.rich(TextSpan textSpan);
}

class TextSpan {
  const TextSpan({String? text});
}

class Semantics extends Widget {
  const Semantics({String? label, Widget? child});
}
''';

const _material = r'''
export 'widgets.dart';

import 'widgets.dart';

class Colors {
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);
}

class Tab extends Widget {
  const Tab({String? text});
}

class Tooltip extends Widget {
  const Tooltip({String? message});
}

class InputDecoration {
  const InputDecoration({
    String? labelText,
    String? hintText,
    String? helperText,
    String? errorText,
  });
}

class IconButton extends Widget {
  const IconButton({String? tooltip});
}
''';

const _core = r'''
abstract class AgentAction<I, O> {
  Future<O> run(I input, Object context);
}

class ActionRegistry {
  Future<O> run<I, O>(AgentAction<I, O> action, I input) async => throw '';
}

abstract class ThreadStore {
  Future<List<String>> threads();
  Future<void> deleteThread(String id);
}

abstract class MemoryStore {
  Future<List<String>> all();
  Future<void> save(String text);
}

abstract class ApprovalPrefs {
  bool isAlwaysAllowed(String action);
  Future<void> clear();
}
''';
