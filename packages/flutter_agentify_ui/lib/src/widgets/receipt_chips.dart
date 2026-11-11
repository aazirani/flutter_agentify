import 'package:flutter/material.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';

import '../assistant_strings.dart';
import 'message_bubble.dart';

/// What really changed, under the reply it belongs to. A change the action
/// could not read back shows a question mark and says so.
class ReceiptChips extends StatelessWidget {
  const ReceiptChips({
    super.key,
    required this.receipts,
    required this.strings,
  });

  final List<Receipt> receipts;
  final AssistantStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final receipt in receipts)
          if (receipt.verified)
            _chip(Icons.task_alt, colors.primary, strings.receiptLabel(receipt))
          else
            Tooltip(
              message: strings.receiptUnverified,
              child: _chip(
                Icons.help_outline,
                colors.onSurfaceVariant,
                strings.receiptLabel(receipt),
              ),
            ),
      ],
    );
  }

  Widget _chip(IconData icon, Color color, String summary) => Chip(
    avatar: Icon(icon, size: 16, color: color),
    // Its own direction: an English summary in a right-to-left app keeps
    // its quotes and full stop in place.
    label: Text(summary, textDirection: textDirectionOf(summary)),
    visualDensity: VisualDensity.compact,
  );
}
