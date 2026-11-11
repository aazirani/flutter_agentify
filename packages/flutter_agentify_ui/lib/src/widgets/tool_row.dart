import 'package:flutter/material.dart';

import '../assistant_controller.dart';
import '../assistant_strings.dart';
import 'message_bubble.dart';

/// One tool the assistant ran: its label and whether it is running, failed,
/// was declined or was stopped.
class ToolRow extends StatelessWidget {
  const ToolRow({super.key, required this.tool, required this.strings});

  final ToolRowData tool;
  final AssistantStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // A person's own choice (reject, stop) is not a failure: neutral, not red.
    final (String? status, IconData icon, Color color) = switch (tool) {
      ToolRowData(running: true) => (
        strings.toolRunning,
        Icons.check,
        colors.primary,
      ),
      ToolRowData(isError: true, errorCode: 'declined') => (
        strings.toolDeclined,
        Icons.block,
        colors.onSurfaceVariant,
      ),
      // Stopped by the person, or cut off by the loop limit: not run.
      ToolRowData(isError: true, errorCode: 'cancelled' || 'loop_limit') => (
        strings.toolStopped,
        Icons.stop_circle_outlined,
        colors.onSurfaceVariant,
      ),
      ToolRowData(isError: true) => (
        strings.toolFailed,
        Icons.error_outline,
        colors.error,
      ),
      _ => (null, Icons.check, colors.primary),
    };
    final label = strings.actionLabel(tool.name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 16,
            child: tool.running
                ? const CircularProgressIndicator(strokeWidth: 2)
                : Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          // Loose, so a line in the other direction than the app still
          // starts next to the icon.
          Flexible(
            child: Text(
              label,
              // The label's own direction keeps its words and the dot in
              // order when it differs from the app's.
              textDirection: textDirectionOf(label),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          // Its own widget, so a long label cannot hide the outcome.
          if (status != null)
            Text(
              ' · $status',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
