import 'package:flutter/material.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';

import 'assistant_strings.dart';

/// For debugging: what the model got on the last request. The system text,
/// the tools sent, and the last run's tool calls with their results.
class AssistantInspector extends StatelessWidget {
  const AssistantInspector({
    super.key,
    required this.session,
    this.strings = const AssistantStrings(),
  });

  final AgentSession session;
  final AssistantStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = session.debugSnapshot;
    if (snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(strings.inspectorEmpty, textAlign: TextAlign.center),
        ),
      );
    }
    final code = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(strings.inspectorTitle, style: theme.textTheme.titleLarge),
        heading(strings.inspectorSystem),
        SelectableText(snapshot.system, style: code),
        heading(strings.inspectorTools),
        SelectableText(snapshot.activeTools.join(', '), style: code),
        heading(strings.inspectorCalls),
        for (final call in snapshot.lastCalls)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectableText(
              '${call.name} → ${call.content}',
              style: code?.copyWith(
                color: call.isError ? theme.colorScheme.error : null,
              ),
            ),
          ),
      ],
    );
  }
}
