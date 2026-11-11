import 'dart:convert';

import 'package:flutter/material.dart';

import '../assistant_controller.dart';
import '../assistant_strings.dart';
import 'message_bubble.dart';

/// Asks the person to approve, always allow or reject one action call. An
/// action that offers no "Always allow" is destructive, so its Approve
/// button uses the error colors.
class ApprovalCard extends StatelessWidget {
  const ApprovalCard({
    super.key,
    required this.approval,
    required this.strings,
    required this.onApprove,
    required this.onAlwaysAllow,
    required this.onReject,
  });

  final PendingApproval approval;
  final AssistantStrings strings;
  final VoidCallback? onApprove;
  final VoidCallback? onAlwaysAllow;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Their own size: an app theme may make buttons full width.
    const size = Size(64, 40);
    String shown(Object? value) => value is String ? value : jsonEncode(value);
    final args = [
      for (final MapEntry(:key, :value) in approval.args.entries)
        Text(
          '$key: ${shown(value)}',
          // The value's own direction, so a Persian value keeps its
          // punctuation in place (the key reads fine either way).
          textDirection: textDirectionOf(shown(value)),
          textAlign: TextAlign.start,
          // A long value must not push the buttons off screen.
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
    ];
    return Semantics(
      container: true,
      liveRegion: true,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.needsApprovalTitle,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                strings.actionLabel(approval.action),
                style: theme.textTheme.labelLarge,
              ),
              if (approval.summary case final summary?) ...[
                Text(
                  // Model-steerable text: one tidy line, never fake lines.
                  summary.replaceAll(RegExp(r'\s+'), ' ').trim(),
                  textDirection: textDirectionOf(summary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                if (args.isNotEmpty)
                  ExpansionTile(
                    title: Text(
                      strings.details,
                      style: theme.textTheme.bodySmall,
                    ),
                    dense: true,
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    children: args,
                  ),
              ] else
                ...args,
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton(
                    style: approval.allowAlways
                        ? FilledButton.styleFrom(minimumSize: size)
                        : FilledButton.styleFrom(
                            minimumSize: size,
                            backgroundColor: colors.error,
                            foregroundColor: colors.onError,
                          ),
                    onPressed: onApprove,
                    child: Text(strings.approve),
                  ),
                  if (approval.allowAlways)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: size),
                      onPressed: onAlwaysAllow,
                      child: Text(strings.alwaysAllow),
                    ),
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: size),
                    onPressed: onReject,
                    child: Text(strings.reject),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
