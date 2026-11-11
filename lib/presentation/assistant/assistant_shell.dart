// @on-device:begin
import 'dart:async';

// @on-device:end
import 'package:flutter/material.dart';
import 'package:flutter_agentify/ai/assistant_providers.dart';
import 'package:flutter_agentify/ai/model_route.dart';
import 'package:flutter_agentify/core/widgets/states/states.dart';
// @on-device:begin
import 'package:flutter_agentify/ai/on_device_model.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/presentation/action_failure_message.dart';
import 'package:flutter_agentify/presentation/settings/on_device_model_tile.dart';
// @on-device:end
import 'package:flutter_agentify/presentation/assistant/assistant_strings_l10n.dart';
import 'package:flutter_agentify/presentation/providers/assistant_settings_provider.dart';
import 'package:flutter_agentify/utils/locale/app_localization.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screens at least this wide show the assistant as a side panel.
const assistantPanelBreakpoint = 840.0;

const _panelWidth = 380.0;

/// Wraps every screen (mounted once by the router's shell route), so the
/// assistant keeps its state across navigation.
class AssistantShell extends ConsumerWidget {
  const AssistantShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(assistantPanelOpenProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!open || constraints.maxWidth < assistantPanelBreakpoint) {
          return child;
        }
        return Row(
          children: [
            Expanded(child: child),
            const VerticalDivider(width: 1),
            SizedBox(
              width: _panelWidth,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                child: const SafeArea(child: AssistantPanel()),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The chat, or what stands in for it before a model is set up.
class AssistantPanel extends ConsumerWidget {
  const AssistantPanel({super.key, this.inSheet = false});

  /// Shown in a bottom sheet, which closes before going to Settings.
  final bool inSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(assistantSessionProvider);
    final controller = ref.watch(assistantControllerProvider);
    String t(String key) => AppLocalizations.of(context)?.translate(key) ?? key;
    // A sheet closes first, so Settings is not hidden behind it.
    void openSettings() {
      final router = GoRouter.of(context);
      if (inSheet) Navigator.of(context).pop();
      router.go('/settings');
    }

    return session.when(
      loading: () => const LoadingState(),
      error: (_, _) => ErrorState(
        message: t('error_generic'),
        onRetry: () => ref.invalidate(assistantSessionProvider),
      ),
      data: (session) {
        if (session == null) {
          return EmptyState(
            icon: Icons.auto_awesome_outlined,
            title: t('assistant_setup_title'),
            description: t('assistant_setup_body'),
            actionLabel: t('assistant_setup_action'),
            onAction: openSettings,
          );
        }
        if (controller == null) return const LoadingState();
        return Padding(
          padding: EdgeInsets.only(
            bottom: inSheet ? MediaQuery.viewInsetsOf(context).bottom : 0,
          ),
          child: AssistantChat(
            controller: controller,
            strings: assistantStringsOf(context),
            inspect: session,
            onOpenSettings: openSettings,
            onClose: inSheet
                ? () => Navigator.of(context).pop()
                : ref.read(assistantPanelOpenProvider.notifier).toggle,
            modelStatus: _modelStatus(context, ref, openSettings),
          ),
        );
      },
    );
  }
}

/// Which model answers, with the in-app model's state when the app has one.
ModelStatus _modelStatus(
  BuildContext context,
  WidgetRef ref,
  VoidCallback openSettings,
) {
  final route = ref.watch(modelRouteProvider);
  final settings = ref.watch(assistantSettingsProvider);
  final server = providerPresets
      .where((p) => p.id == settings.presetId)
      .firstOrNull
      ?.label;
  // @on-device:begin
  if (_onDeviceStatus(context, ref, route, server, openSettings)
      case final status?) {
    return status;
  }
  // @on-device:end
  return ModelStatus(
    answeredBy: route,
    serverLabel: server,
    serverModel: settings.model,
  );
}
// @on-device:begin

ModelStatus? _onDeviceStatus(
  BuildContext context,
  WidgetRef ref,
  AnsweredBy route,
  String? server,
  VoidCallback openSettings,
) {
  final setup = ref.watch(activeSetupProvider);
  final device = setup.onDevice;
  final state = ref.watch(onDeviceModelStateProvider);
  if (device == null || !showOnDeviceSettings(state, setup)) return null;
  final actions = ServiceLocator.getIt<AppActions>();
  void run(AgentAction<Null, Object?> action) => unawaited(() async {
    try {
      await ServiceLocator.getIt<ActionRegistry>().run(action, null);
    } on ActionFailure catch (failure) {
      if (context.mounted) showActionFailure(context, failure);
    }
  }());
  // "Not now" only where a server answers meanwhile; otherwise the offer stays.
  final settings = ref.watch(assistantSettingsProvider);
  final serverAnswers = setup.mode == ModelMode.both && settings.isConfigured;
  final useDevice = ref.watch(useOnDeviceModelProvider);
  final serverEditable = setup.usesServer && setup.server.userEditable;
  return ModelStatus(
    answeredBy: route,
    serverLabel: server,
    serverModel: settings.model,
    deviceLabel: device.model.label,
    state: state,
    sizeBytes: onDeviceDownloadBytes(device.model),
    askBeforeDownload: device.askBeforeDownload,
    offerDismissed:
        serverAnswers &&
        (ref.watch(onDeviceOfferDismissedProvider) || !useDevice),
    usesDevice: useDevice,
    onDownload: () => run(actions.downloadOnDeviceModel),
    onNotNow: serverAnswers ? () => run(actions.dismissOnDeviceOffer) : null,
    onCancel: () => run(actions.cancelOnDeviceModelDownload),
    onRetry: () => run(actions.downloadOnDeviceModel),
    onDelete: () async {
      final onlyModel = setup.mode == ModelMode.onDevice;
      if (await confirmOnDeviceDelete(
            context,
            device.model,
            onlyModel: onlyModel,
          ) &&
          context.mounted) {
        run(actions.deleteOnDeviceModel);
      }
    },
    onUseDevice: serverAnswers
        ? (value) => unawaited(() async {
            try {
              await ServiceLocator.getIt<ActionRegistry>().run(
                actions.setUseOnDeviceModel,
                value,
              );
            } on ActionFailure catch (failure) {
              if (context.mounted) showActionFailure(context, failure);
            }
          }())
        : null,
    // With no model to answer here, a server is the way forward.
    onOpenSettings: serverEditable ? openSettings : null,
  );
}
// @on-device:end
