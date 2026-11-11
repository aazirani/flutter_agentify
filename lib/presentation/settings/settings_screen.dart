import 'package:flutter/material.dart';
import 'package:flutter_agentify/ai/model_route.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/domain/entities/app_theme_mode.dart';
import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
import 'package:flutter_agentify/presentation/action_failure_message.dart';
import 'package:flutter_agentify/presentation/assistant/assistant_toggle_button.dart';
import 'package:flutter_agentify/presentation/providers/language_provider.dart';
import 'package:flutter_agentify/presentation/providers/theme_provider.dart';
import 'package:flutter_agentify/presentation/settings/assistant_settings_section.dart';
import 'package:flutter_agentify/presentation/settings/memories_tile.dart';
// @on-device:begin
import 'package:flutter_agentify/presentation/settings/on_device_model_tile.dart';
// @on-device:end
import 'package:flutter_agentify/utils/locale/app_localization.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final currentLocale = ref.watch(currentLocaleProvider);
    final setup = ref.watch(activeSetupProvider);

    final themeButtons = SegmentedButton<ThemeMode>(
      // Icons only, to fit a phone; the tooltip names each one.
      segments: [
        ButtonSegment(
          value: ThemeMode.system,
          icon: const Icon(Icons.brightness_auto),
          tooltip: _t(context, 'system'),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: const Icon(Icons.light_mode),
          tooltip: _t(context, 'light'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: const Icon(Icons.dark_mode),
          tooltip: _t(context, 'dark'),
        ),
      ],
      showSelectedIcon: false,
      selected: {themeMode},
      onSelectionChanged: (modes) => _run(
        context,
        (registry, actions) => registry.run(
          actions.setThemeMode,
          AppThemeMode.values.byName(modes.first.name),
        ),
      ),
    );
    // With large text the buttons go under the title, which keeps its width.
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t(context, 'settings')),
        actions: const [AssistantToggleButton()],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          // Fields stay readable on a wide window.
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: Text(_t(context, 'theme')),
                subtitle: largeText
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_themeModeLabel(context, themeMode)),
                          const SizedBox(height: 8),
                          themeButtons,
                        ],
                      )
                    : Text(_themeModeLabel(context, themeMode)),
                trailing: largeText ? null : themeButtons,
              ),

              const Divider(),

              ListTile(
                leading: const Icon(Icons.language),
                title: Text(_t(context, 'language')),
                subtitle: Text(languageFor(currentLocale).language),
                onTap: () => _showLanguagePicker(context, ref, currentLocale),
              ),

              const Divider(),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _t(context, 'assistant_section'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              // @on-device:begin
              if (setup.usesDevice && setup.mode == ModelMode.both)
                const AnswersWithTile(),
              if (setup.usesDevice) const OnDeviceModelTile(),
              // @on-device:end
              if (setup.usesServer && setup.server.userEditable)
                const AssistantSettingsSection(),
              const MemoriesTile(),

              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: Text(_t(context, 'assistant_reset_approvals')),
                onTap: () => _resetApprovals(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Changes a setting through its action; a failure shows as a message
  /// and gives false.
  Future<bool> _run(
    BuildContext context,
    Future<Object?> Function(ActionRegistry registry, AppActions actions)
    change,
  ) async {
    try {
      await change(
        ServiceLocator.getIt<ActionRegistry>(),
        ServiceLocator.getIt<AppActions>(),
      );
      return true;
    } on ActionFailure catch (failure) {
      if (context.mounted) showActionFailure(context, failure);
      return false;
    }
  }

  Future<void> _resetApprovals(BuildContext context) async {
    final reset = await _run(
      context,
      (registry, actions) => registry.run(actions.resetApprovals, null),
    );
    if (!reset || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t(context, 'assistant_reset_approvals_done'))),
    );
  }

  String _t(BuildContext context, String key) =>
      AppLocalizations.of(context)?.translate(key) ?? key;

  String _themeModeLabel(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return _t(context, 'system');
      case ThemeMode.light:
        return _t(context, 'light');
      case ThemeMode.dark:
        return _t(context, 'dark');
    }
  }

  void _showLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    String currentLocale,
  ) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_t(context, 'select_language')),
        children: [
          RadioGroup<String>(
            groupValue: currentLocale,
            onChanged: (value) {
              if (value != null) {
                Navigator.pop(context);
                _run(
                  context,
                  (registry, actions) =>
                      registry.run(actions.setLanguage, value),
                );
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: kSupportedLanguages.map((language) {
                // Each language in its own name, so a person who cannot read
                // the current one still finds theirs.
                return RadioListTile<String>(
                  title: Text('${language.flagEmoji} ${language.language}'),
                  value: language.locale,
                  selected: language.locale == currentLocale,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
