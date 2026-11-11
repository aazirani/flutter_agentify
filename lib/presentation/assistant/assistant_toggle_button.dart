import 'package:flutter/material.dart';
import 'package:flutter_agentify/ai/assistant_providers.dart';
import 'package:flutter_agentify/presentation/assistant/assistant_shell.dart';
import 'package:flutter_agentify/utils/locale/app_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the assistant: the side panel on wide screens, a sheet otherwise.
class AssistantToggleButton extends ConsumerWidget {
  const AssistantToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(assistantControllerProvider);
    final panelShown =
        ref.watch(assistantPanelOpenProvider) &&
        MediaQuery.sizeOf(context).width >= assistantPanelBreakpoint;
    String t(String key) => AppLocalizations.of(context)?.translate(key) ?? key;
    // A badge while an approval waits and the chat is out of sight.
    return ListenableBuilder(
      listenable: controller ?? const AlwaysStoppedAnimation(0),
      builder: (context, _) {
        final waits = !panelShown && controller?.pendingApproval != null;
        return IconButton(
          icon: Badge(
            isLabelVisible: waits,
            child: const Icon(Icons.auto_awesome_outlined),
          ),
          tooltip: t(
            waits ? 'assistant_open_approval_waiting' : 'assistant_open',
          ),
          onPressed: () => toggleAssistant(context, ref),
        );
      },
    );
  }
}

/// Opens or closes the side panel on wide screens; opens a sheet otherwise.
void toggleAssistant(BuildContext context, WidgetRef ref) {
  if (MediaQuery.sizeOf(context).width >= assistantPanelBreakpoint) {
    ref.read(assistantPanelOpenProvider.notifier).toggle();
  } else {
    // @on-device:begin
    ref.read(assistantPanelOpenProvider.notifier).prepareModel();
    // @on-device:end
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _AssistantSheet(),
    );
  }
}

/// Hands the chat to the side panel once the window grows wide enough for
/// it (a resized desktop window, a rotated tablet), so it never shows twice.
class _AssistantSheet extends ConsumerWidget {
  const _AssistantSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (MediaQuery.sizeOf(context).width >= assistantPanelBreakpoint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // isCurrent is false once popped, so a second build pops nothing.
        // With a route on top (Conversations), it waits for the next rebuild.
        if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
          return;
        }
        if (!ref.read(assistantPanelOpenProvider)) {
          ref.read(assistantPanelOpenProvider.notifier).toggle();
        }
        Navigator.of(context).pop();
      });
    }
    return const FractionallySizedBox(
      heightFactor: 1,
      child: AssistantPanel(inSheet: true),
    );
  }
}
