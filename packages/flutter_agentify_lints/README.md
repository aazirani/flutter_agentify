# flutter_agentify_lints

Analyzer rules that keep the architecture correct.

## Use

Add the plugin to the app's `analysis_options.yaml`:

```yaml
plugins:
  flutter_agentify_lints:
    path: packages/flutter_agentify_lints
    diagnostics:
      domain_layer_boundaries: true
      no_error_returns_in_actions: true
      no_hardcoded_colors: true
      no_hardcoded_strings: true
      no_navigator_push: true
      no_raw_sql_interpolation: true
      no_secret_literals: true
      presentation_layer_boundaries: true
      ui_calls_actions: true
```

This package is used by path and is not on pub.dev.
