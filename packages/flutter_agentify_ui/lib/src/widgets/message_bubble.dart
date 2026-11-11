import 'package:flutter/material.dart';

final _strong = RegExp(
  r'[A-Za-zÀ-ɏͰ-ϿЀ-ӿ]|'
  r'[֐-ࣿיִ-﷿ﹰ-﻿]',
);
final _rtl = RegExp(r'[֐-ࣿיִ-﷿ﹰ-﻿]');

/// The direction of [text] from its first strong letter: right-to-left for
/// Hebrew and Arabic script (Persian included), left-to-right for Latin,
/// Greek and Cyrillic; null when it has none of these.
TextDirection? textDirectionOf(String text) {
  final letter = _strong.firstMatch(text)?.group(0);
  if (letter == null) return null;
  return _rtl.hasMatch(letter) ? TextDirection.rtl : TextDirection.ltr;
}

/// One message: the person's on the end side, the assistant's on the start
/// side. Its text runs in its own direction, which may differ from the app's.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.fromUser,
    required this.text,
    this.selectable = false,
  });

  final bool fromUser;
  final String text;

  /// Whether the text can be selected and copied.
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: fromUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: fromUser
                ? colors.primaryContainer
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Directionality(
            textDirection: textDirectionOf(text) ?? Directionality.of(context),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: fromUser ? colors.onPrimaryContainer : colors.onSurface,
              ),
              child: selectable ? SelectableText(text) : Text(text),
            ),
          ),
        ),
      ),
    );
  }
}
