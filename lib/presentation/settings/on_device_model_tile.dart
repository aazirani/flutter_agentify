import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_agentify/ai/model_route.dart';
import 'package:flutter_agentify/ai/on_device_model.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/presentation/action_failure_message.dart';
import 'package:flutter_agentify/presentation/providers/assistant_settings_provider.dart';
import 'package:flutter_agentify/utils/locale/app_localization.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _t(BuildContext context, String key) =>
    AppLocalizations.of(context)?.translate(key) ?? key;

/// Asks before downloading [spec], naming it and its size.
Future<bool> confirmOnDeviceDownload(
  BuildContext context,
  OnDeviceModelSpec spec,
) => _confirm(
  context,
  title: _t(context, 'on_device_download_title'),
  body: _t(context, 'on_device_download_body'),
  action: _t(context, 'on_device_download'),
  spec: spec,
);

/// Asks before deleting [spec]. [onlyModel]: no server answers without it.
Future<bool> confirmOnDeviceDelete(
  BuildContext context,
  OnDeviceModelSpec spec, {
  required bool onlyModel,
}) => _confirm(
  context,
  title: _t(context, 'on_device_delete_title'),
  body: _t(
    context,
    onlyModel ? 'on_device_delete_body_only' : 'on_device_delete_body',
  ),
  action: _t(context, 'on_device_delete'),
  spec: spec,
);

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  required OnDeviceModelSpec spec,
}) async {
  String fill(String text) => text
      .replaceAll('{model}', spec.label)
      .replaceAll('{size}', formatModelSize(onDeviceDownloadBytes(spec)));
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(fill(title)),
      content: Text(fill(body)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(_t(context, 'on_device_cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Runs an on-device action; a failure shows as a message.
void _run(BuildContext context, AgentAction<Null, Object?> action) =>
    unawaited(() async {
      try {
        await ServiceLocator.getIt<ActionRegistry>().run(action, null);
      } on ActionFailure catch (failure) {
        if (context.mounted) showActionFailure(context, failure);
      }
    }());

/// Whether the in-app model's settings are worth showing: not when the app
/// leaves it off on the web and a server answers instead.
bool showOnDeviceSettings(OnDeviceModelState? state, AssistantSetup setup) =>
    state != null &&
    !(setup.mode == ModelMode.both &&
        state is ModelUnsupported &&
        state.reason == UnsupportedReason.webDisabled);

/// The model inside the app in Settings: its name, size and state, and
/// Download, Cancel, Retry or Delete.
class OnDeviceModelTile extends ConsumerWidget {
  const OnDeviceModelTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onDeviceModelStateProvider);
    final setup = ref.watch(activeSetupProvider);
    final spec = setup.onDevice?.model;
    if (spec == null || state == null || !showOnDeviceSettings(state, setup)) {
      return const SizedBox.shrink();
    }
    String t(String key) => _t(context, key);
    final actions = ServiceLocator.getIt<AppActions>();
    final size = formatModelSize(onDeviceDownloadBytes(spec));
    Widget button(String key, VoidCallback onPressed) =>
        TextButton(onPressed: onPressed, child: Text(t(key)));
    final download = button('on_device_download', () async {
      if (await confirmOnDeviceDownload(context, spec) && context.mounted) {
        _run(context, actions.downloadOnDeviceModel);
      }
    });
    final delete = button('on_device_delete', () async {
      final onlyModel = setup.mode == ModelMode.onDevice;
      if (await confirmOnDeviceDelete(context, spec, onlyModel: onlyModel) &&
          context.mounted) {
        _run(context, actions.deleteOnDeviceModel);
      }
    });
    // Retry downloads again after a failed download, else loads again.
    final retry = button(
      'assistant_retry',
      () => _run(context, actions.downloadOnDeviceModel),
    );

    // The state line, the progress bar (null spins, absent when idle) and
    // the buttons.
    final (
      String status,
      double? progress,
      List<Widget> buttons,
    ) = switch (state) {
      ModelNotDownloaded() => (
        '$size · ${t('on_device_not_downloaded')}',
        -1,
        [download],
      ),
      ModelDownloading(:final percent) => (
        formatDownloadProgress(t('on_device_downloading'), state),
        percent / 100,
        [
          button(
            'on_device_cancel',
            () => _run(context, actions.cancelOnDeviceModelDownload),
          ),
        ],
      ),
      ModelDownloaded() => (
        '$size · ${t('on_device_downloaded')}',
        -1,
        [delete],
      ),
      ModelLoading() => (t('on_device_loading'), null, const <Widget>[]),
      ModelReady() => ('$size · ${t('on_device_ready')}', -1, [delete]),
      ModelUnsupported(:final reason) => (
        t(switch (reason) {
          UnsupportedReason.notEnoughMemory => 'on_device_no_memory',
          UnsupportedReason.webDisabled => 'on_device_web_off',
          _ => 'on_device_unsupported',
        }),
        -1,
        const <Widget>[],
      ),
      ModelFailed(:final kind) => (
        t(switch (kind) {
          OnDeviceFailure.download => 'on_device_download_failed',
          OnDeviceFailure.memory => 'on_device_memory_failed',
          _ => 'on_device_load_failed',
        }),
        -1,
        // A failed download leaves nothing on disk to delete.
        kind == OnDeviceFailure.download ? [retry] : [retry, delete],
      ),
    };
    final value = progress;
    // One button fits at the end of the row; two, or large text, go below.
    final inRow =
        buttons.length == 1 && MediaQuery.textScalerOf(context).scale(1) <= 1.3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Subheader(t('on_device_menu')),
        ListTile(
          leading: const Icon(Icons.memory),
          title: Text(spec.label),
          subtitle: Semantics(liveRegion: true, child: Text(status)),
          trailing: inRow ? buttons.single : null,
        ),
        if (value == null || value >= 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(value: value),
          ),
        if (buttons.isNotEmpty && !inRow)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              children: buttons,
            ),
          ),
      ],
    );
  }
}

/// In `ModelMode.both`: whether the model on this device answers once it is
/// ready, or the model server. Without a server there is nothing to choose.
class AnswersWithTile extends ConsumerWidget {
  const AnswersWithTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A device that cannot run the model leaves only the server.
    if (ref.watch(onDeviceModelStateProvider) is ModelUnsupported) {
      return const SizedBox.shrink();
    }
    String t(String key) => _t(context, key);
    final serverReady = ref.watch(assistantSettingsProvider).isConfigured;
    // Without a server, the device answers whatever was chosen.
    final useDevice = !serverReady || ref.watch(useOnDeviceModelProvider);
    final actions = ServiceLocator.getIt<AppActions>();
    void set(bool value) => unawaited(() async {
      try {
        await ServiceLocator.getIt<ActionRegistry>().run(
          actions.setUseOnDeviceModel,
          value,
        );
      } on ActionFailure catch (failure) {
        if (context.mounted) showActionFailure(context, failure);
      }
    }());
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('assistant_answers_with'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.memory),
                label: Text(t('on_device_choice_device')),
              ),
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.dns_outlined),
                label: Text(t('on_device_choice_server')),
              ),
            ],
            showSelectedIcon: false,
            selected: {useDevice},
            onSelectionChanged: serverReady ? (s) => set(s.first) : null,
          ),
          const SizedBox(height: 4),
          Text(
            t(
              !serverReady
                  ? 'on_device_use_needs_server'
                  : useDevice
                  ? 'on_device_use_hint'
                  : 'on_device_use_server_hint',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Subheader extends StatelessWidget {
  const _Subheader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
