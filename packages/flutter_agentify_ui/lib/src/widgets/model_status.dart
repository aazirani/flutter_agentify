import 'package:flutter/material.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';

import '../assistant_strings.dart';

/// Which model answers, and the in-app model's state with what the person can
/// do about it. Callbacks left null hide their buttons.
class ModelStatus {
  const ModelStatus({
    required this.answeredBy,
    this.serverLabel,
    this.serverModel,
    this.deviceLabel,
    this.state,
    this.sizeBytes,
    this.askBeforeDownload = true,
    this.offerDismissed = false,
    this.usesDevice = true,
    this.onDownload,
    this.onNotNow,
    this.onCancel,
    this.onRetry,
    this.onDelete,
    this.onUseDevice,
    this.onOpenSettings,
  });

  final AnsweredBy answeredBy;

  /// The server's name for the header, such as "Ollama".
  final String? serverLabel;

  /// The server's model for the header, such as "llama3.2".
  final String? serverModel;

  /// The in-app model's name, such as "Gemma 4 E2B".
  final String? deviceLabel;

  /// The in-app model's state; null when the app has none.
  final OnDeviceModelState? state;

  /// The download size the offer names.
  final int? sizeBytes;

  /// Whether to offer the download in a card before it starts.
  final bool askBeforeDownload;

  /// The person chose "Not now": no card, Download stays in the menu.
  final bool offerDismissed;

  /// Whether the person chose the in-app model over the server.
  final bool usesDevice;

  final VoidCallback? onDownload;
  final VoidCallback? onNotNow;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;

  /// Switches between the in-app model (true) and the server; null when
  /// there is nothing to choose.
  final ValueChanged<bool>? onUseDevice;

  /// Opens the server settings when the in-app model cannot run here.
  final VoidCallback? onOpenSettings;

  /// The header's second line, naming the model; null when none answers.
  String? label(AssistantStrings strings) => switch (answeredBy) {
    AnsweredBy.device => _join(deviceLabel, strings.onDevice),
    AnsweredBy.server => _join(serverLabel, serverModel),
    AnsweredBy.none => null,
  };

  /// Download, the switch between device and server, and Delete model, for
  /// the chat's menu.
  List<(String, VoidCallback)> menu(AssistantStrings strings) {
    final state = this.state;
    final failedDownload =
        state is ModelFailed && state.kind == OnDeviceFailure.download;
    final canDownload = state is ModelNotDownloaded || failedDownload;
    final installed = state is ModelDownloaded || state is ModelReady;
    final canDelete = installed || (state is ModelFailed && !failedDownload);
    final size = sizeBytes;
    return [
      if (onDownload case final download? when canDownload)
        (
          size == null
              ? strings.onDeviceDownload
              : '${strings.onDeviceDownload} (${formatModelSize(size)})',
          download,
        ),
      if (onUseDevice case final use? when installed)
        usesDevice
            ? (
                strings.useServer.replaceAll(
                  '{server}',
                  serverLabel ?? strings.modelServer,
                ),
                () => use(false),
              )
            : (strings.useDevice, () => use(true)),
      if (onDelete case final delete? when canDelete)
        (strings.onDeviceDelete, delete),
    ];
  }
}

String? _join(String? a, String? b) {
  final parts = [
    for (final part in [a, b])
      if (part != null && part.trim().isNotEmpty) part.trim(),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// "2.6 GB" for 2588147712, isolated so a right-to-left sentence keeps the
/// number before its unit.
String formatModelSize(int bytes) =>
    '\u2066${bytes >= 1e9 ? '${(bytes / 1e9).toStringAsFixed(1)} GB' : '${(bytes / 1e6).ceil()} MB'}\u2069';

/// "958 MB of 2.6 GB" from [text] with `{received}`, `{total}` and
/// `{percent}`.
String formatDownloadProgress(String text, ModelDownloading state) => text
    .replaceAll('{received}', formatModelSize(state.received))
    .replaceAll('{total}', formatModelSize(state.total))
    .replaceAll('{percent}', '${state.percent}');

/// The in-app model's card, progress row or state line; empty when there is
/// nothing to say.
class ModelStatusView extends StatelessWidget {
  const ModelStatusView({
    super.key,
    required this.status,
    required this.strings,
  });

  final ModelStatus status;
  final AssistantStrings strings;

  @override
  Widget build(BuildContext context) {
    final noModel = status.answeredBy == AnsweredBy.none;
    return switch (status.state) {
      ModelNotDownloaded()
          when noModel ||
              (status.askBeforeDownload && !status.offerDismissed) =>
        _Offer(status: status, strings: strings),
      final ModelDownloading downloading => _Row(
        text: formatDownloadProgress(strings.onDeviceDownloading, downloading),
        // Constant while it runs: only the start is announced, not each tick.
        announce: formatDownloadProgress(
          strings.onDeviceDownloading,
          ModelDownloading(0, downloading.total),
        ),
        progress: downloading.percent / 100,
        actions: [
          if (status.onCancel case final cancel?)
            _button(strings.onDeviceCancel, cancel),
        ],
      ),
      ModelLoading() => _Row(text: strings.onDeviceLoading, progress: null),
      // Downloaded but not loaded: loading starts when the chat opens.
      ModelDownloaded() when noModel => _Row(
        text: strings.onDeviceLoading,
        progress: null,
      ),
      ModelUnsupported(:final reason) when noModel => _Row(
        text: reason == UnsupportedReason.notEnoughMemory
            ? strings.onDeviceNoMemory
            : strings.onDeviceUnsupported,
        actions: [
          if (status.onOpenSettings case final open?)
            _button(strings.openSettings, open),
        ],
      ),
      ModelFailed(:final kind) => _Row(
        text: switch (kind) {
          OnDeviceFailure.download => strings.onDeviceDownloadFailed,
          OnDeviceFailure.memory => strings.onDeviceMemoryFailed,
          _ => strings.onDeviceLoadFailed,
        },
        actions: [
          if (status.onRetry case final retry?) _button(strings.retry, retry),
          // A failed download leaves nothing on disk to delete.
          if (status.onDelete case final delete?
              when kind != OnDeviceFailure.download)
            _button(strings.onDeviceDelete, delete),
        ],
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

Widget _button(String label, VoidCallback onPressed) => TextButton(
  // Its own size: an app theme may make buttons full width.
  style: TextButton.styleFrom(minimumSize: const Size(64, 40)),
  onPressed: onPressed,
  child: Text(label),
);

class _Offer extends StatelessWidget {
  const _Offer({required this.status, required this.strings});

  final ModelStatus status;
  final AssistantStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = status.sizeBytes;
    return Semantics(
      container: true,
      label: strings.onDeviceOfferTitle,
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.onDeviceOfferTitle,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                strings.onDeviceOfferBody
                    .replaceAll('{model}', status.deviceLabel ?? strings.model)
                    .replaceAll(
                      '{size}',
                      size == null ? '' : formatModelSize(size),
                    ),
                style: theme.textTheme.bodyMedium,
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  spacing: 4,
                  children: [
                    if (status.onNotNow case final notNow?)
                      _button(strings.onDeviceNotNow, notNow),
                    if (status.onDownload case final download?)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 40),
                        ),
                        onPressed: download,
                        child: Text(strings.onDeviceDownload),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of state, an optional progress bar and buttons.
class _Row extends StatelessWidget {
  const _Row({
    required this.text,
    this.announce,
    this.progress = -1,
    this.actions = const [],
  });

  final String text;

  /// What a screen reader announces when the state changes; [text] when null.
  final String? announce;

  /// 0 to 1; null spins; below 0 shows no bar.
  final double? progress;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final value = progress;
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Buttons move under the text when both do not fit, such as
            // with large text.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  liveRegion: true,
                  label: announce ?? text,
                  excludeSemantics: true,
                  child: Text(text),
                ),
                Wrap(children: actions),
              ],
            ),
            if (value == null || value >= 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8, top: 4),
                child: LinearProgressIndicator(
                  value: value,
                  semanticsLabel: text,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
