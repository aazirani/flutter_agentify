import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/layer_boundaries.dart';
import 'src/rules/no_error_returns_in_actions.dart';
import 'src/rules/no_hardcoded_colors.dart';
import 'src/rules/no_hardcoded_strings.dart';
import 'src/rules/no_navigator_push.dart';
import 'src/rules/no_raw_sql_interpolation.dart';
import 'src/rules/no_secret_literals.dart';
import 'src/rules/ui_calls_actions.dart';

final plugin = FlutterAgentifyLintsPlugin();

/// Analyzer plugin with the rules that keep a Flutter Agentify app's
/// architecture correct. Each rule is off until it is listed under
/// `diagnostics:` in `analysis_options.yaml`.
class FlutterAgentifyLintsPlugin extends Plugin {
  @override
  String get name => 'flutter_agentify_lints';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerLintRule(DomainLayerBoundaries())
      ..registerLintRule(NoErrorReturnsInActions())
      ..registerLintRule(NoHardcodedColors())
      ..registerLintRule(NoHardcodedStrings())
      ..registerLintRule(NoNavigatorPush())
      ..registerLintRule(NoRawSqlInterpolation())
      ..registerLintRule(NoSecretLiterals())
      ..registerLintRule(PresentationLayerBoundaries())
      ..registerLintRule(UiCallsActions());
  }
}
