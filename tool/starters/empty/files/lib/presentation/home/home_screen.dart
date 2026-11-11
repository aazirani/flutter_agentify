import 'package:flutter/material.dart';
import 'package:flutter_agentify/core/theme/app_spacing.dart';
import 'package:flutter_agentify/presentation/assistant/assistant_toggle_button.dart';
import 'package:flutter_agentify/utils/locale/app_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The first screen: a welcome, and the way to the assistant and Settings.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    String tr(String key, String fallback) =>
        AppLocalizations.of(context)?.translate(key) ?? fallback;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('app_name', 'App')),
        centerTitle: true,
        actions: [
          const AssistantToggleButton(),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: tr('settings', 'Settings'),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: AppSpacing.padding6,
          child: ConstrainedBox(
            // Keeps lines short enough to read on wide windows.
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    tr('welcome', 'Welcome'),
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                Text(
                  tr(
                    'home_intro',
                    'Open the assistant to try it, or change the theme and the '
                        'language in Settings.',
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space6),
                FilledButton.icon(
                  onPressed: () => toggleAssistant(context, ref),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(tr('assistant_open', 'Assistant')),
                ),
                const SizedBox(height: AppSpacing.space2),
                TextButton(
                  onPressed: () => context.go('/settings'),
                  child: Text(tr('settings', 'Settings')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
