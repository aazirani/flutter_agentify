import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../assistant_strings.dart';
import 'message_bubble.dart';

/// The text field and its send button, which turns into a stop button while
/// a reply is running. With a hardware keyboard, Enter sends and Shift+Enter
/// starts a new line; the field keeps focus after sending.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.running,
    required this.strings,
    required this.onSend,
    required this.onStop,
    this.stopping = false,
  });

  final bool running;

  /// Stop was pressed and the run is still ending: the stop button is
  /// disabled and says so.
  final bool stopping;
  final AssistantStrings strings;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;

  @override
  State<Composer> createState() => _ComposerState();
}

/// Desktop and web have a hardware keyboard, where Return sends.
bool get _keyboardSends =>
    kIsWeb ||
    switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };

class _ComposerState extends State<Composer> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text;
    if (text.trim().isEmpty || widget.running) return;
    _text.clear();
    widget.onSend(text);
    _focus.requestFocus();
  }

  /// Enter sends, but not while an input method is still composing a word.
  void _enter() {
    if (!_text.value.composing.isValid) _send();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _text.text.trim().isNotEmpty && !widget.running;
    final strings = widget.strings;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): _enter,
                const SingleActivator(LogicalKeyboardKey.numpadEnter): _enter,
              },
              child: TextField(
                controller: _text,
                focusNode: _focus,
                minLines: 1,
                maxLines: 5,
                textDirection: textDirectionOf(_text.text),
                textInputAction: _keyboardSends
                    ? TextInputAction.newline
                    : TextInputAction.send,
                onSubmitted: (_) => _send(),
                // Keeps the keyboard and focus after a send.
                onEditingComplete: () {},
                decoration: InputDecoration(
                  hintText: strings.inputHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          widget.running
              ? IconButton.filledTonal(
                  onPressed: widget.stopping ? null : widget.onStop,
                  tooltip: widget.stopping ? strings.stopping : strings.stop,
                  icon: const Icon(Icons.stop),
                )
              : IconButton.filled(
                  onPressed: canSend ? _send : null,
                  tooltip: strings.send,
                  icon: const Icon(Icons.send),
                ),
        ],
      ),
    );
  }
}
