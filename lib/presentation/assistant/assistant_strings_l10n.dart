import 'package:flutter/widgets.dart';
import 'package:flutter_agentify/utils/locale/app_localization.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';

/// The chat's texts in the app's current language. Action names come from
/// `action_<name>` keys; an action without one shows a readable form of its
/// name.
AssistantStrings assistantStringsOf(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  const fallback = AssistantStrings();
  String t(String key, String english) => l10n?.translate(key) ?? english;
  return AssistantStrings(
    inputHint: t('assistant_input_hint', fallback.inputHint),
    send: t('assistant_send', fallback.send),
    stop: t('assistant_stop', fallback.stop),
    approve: t('assistant_approve', fallback.approve),
    alwaysAllow: t('assistant_always_allow', fallback.alwaysAllow),
    reject: t('assistant_reject', fallback.reject),
    needsApprovalTitle: t(
      'assistant_needs_approval',
      fallback.needsApprovalTitle,
    ),
    answerOnlyNotice: t('assistant_answer_only', fallback.answerOnlyNotice),
    toolRunning: t('assistant_tool_running', fallback.toolRunning),
    toolFailed: t('assistant_tool_failed', fallback.toolFailed),
    toolDeclined: t('assistant_tool_declined', fallback.toolDeclined),
    toolStopped: t('assistant_tool_stopped', fallback.toolStopped),
    receiptUnverified: t(
      'assistant_receipt_unverified',
      fallback.receiptUnverified,
    ),
    details: t('assistant_details', fallback.details),
    thinking: t('assistant_thinking', fallback.thinking),
    limitMaxSteps: t('assistant_limit_max_steps', fallback.limitMaxSteps),
    limitTokenBudget: t(
      'assistant_limit_token_budget',
      fallback.limitTokenBudget,
    ),
    limitRepeatedCall: t(
      'assistant_limit_repeated_call',
      fallback.limitRepeatedCall,
    ),
    limitOutput: t('assistant_limit_output', fallback.limitOutput),
    cancelled: t('assistant_cancelled', fallback.cancelled),
    stopping: t('assistant_stopping', fallback.stopping),
    continueRun: t('assistant_continue', fallback.continueRun),
    errorConnection: t('assistant_error_connection', fallback.errorConnection),
    errorTimeout: t('assistant_error_timeout', fallback.errorTimeout),
    errorAuth: t('assistant_error_auth', fallback.errorAuth),
    errorNotFound: t('assistant_error_not_found', fallback.errorNotFound),
    errorRateLimit: t('assistant_error_rate_limit', fallback.errorRateLimit),
    errorServer: t('assistant_error_server', fallback.errorServer),
    errorRequest: t('assistant_error_request', fallback.errorRequest),
    errorBadReply: t('assistant_error_bad_reply', fallback.errorBadReply),
    errorOther: t('assistant_error_other', fallback.errorOther),
    openSettings: t('assistant_setup_action', fallback.openSettings),
    retry: t('assistant_retry', fallback.retry),
    newChat: t('assistant_new_chat', fallback.newChat),
    title: t('assistant_open', fallback.title),
    close: t('assistant_close', fallback.close),
    jumpToLatest: t('assistant_jump_to_latest', fallback.jumpToLatest),
    conversations: t('assistant_conversations', fallback.conversations),
    conversationsEmpty: t(
      'assistant_conversations_empty',
      fallback.conversationsEmpty,
    ),
    conversationUntitled: t(
      'assistant_conversation_untitled',
      fallback.conversationUntitled,
    ),
    emptyTitle: t('assistant_empty_title', fallback.emptyTitle),
    emptyBody: t('assistant_empty_body', fallback.emptyBody),
    inspectorOpen: t('assistant_inspector_open', fallback.inspectorOpen),
    inspectorTitle: t('assistant_inspector_title', fallback.inspectorTitle),
    inspectorSystem: t('assistant_inspector_system', fallback.inspectorSystem),
    inspectorTools: t('assistant_inspector_tools', fallback.inspectorTools),
    inspectorCalls: t('assistant_inspector_calls', fallback.inspectorCalls),
    inspectorEmpty: t('assistant_inspector_empty', fallback.inspectorEmpty),
    onDevice: t('assistant_on_device', fallback.onDevice),
    onDeviceMenu: t('on_device_menu', fallback.onDeviceMenu),
    onDeviceOfferTitle: t('on_device_offer_title', fallback.onDeviceOfferTitle),
    onDeviceOfferBody: t('on_device_offer_body', fallback.onDeviceOfferBody),
    onDeviceDownload: t('on_device_download', fallback.onDeviceDownload),
    onDeviceNotNow: t('on_device_not_now', fallback.onDeviceNotNow),
    onDeviceDownloading: t(
      'on_device_downloading',
      fallback.onDeviceDownloading,
    ),
    onDeviceCancel: t('on_device_cancel', fallback.onDeviceCancel),
    onDeviceLoading: t('on_device_loading', fallback.onDeviceLoading),
    onDeviceUnsupported: t(
      'on_device_unsupported',
      fallback.onDeviceUnsupported,
    ),
    onDeviceNoMemory: t('on_device_no_memory', fallback.onDeviceNoMemory),
    onDeviceDownloadFailed: t(
      'on_device_download_failed',
      fallback.onDeviceDownloadFailed,
    ),
    onDeviceMemoryFailed: t(
      'on_device_memory_failed',
      fallback.onDeviceMemoryFailed,
    ),
    onDeviceLoadFailed: t('on_device_load_failed', fallback.onDeviceLoadFailed),
    onDeviceDelete: t('on_device_delete', fallback.onDeviceDelete),
    onDeviceNowAnswering: t(
      'on_device_now_answering',
      fallback.onDeviceNowAnswering,
    ),
    onDeviceLeaveBody: t('on_device_leave_body', fallback.onDeviceLeaveBody),
    onDeviceLeaveContinue: t(
      'on_device_leave_continue',
      fallback.onDeviceLeaveContinue,
    ),
    onDeviceLeaveNew: t('on_device_leave_new', fallback.onDeviceLeaveNew),
    modelServer: t('assistant_model_server', fallback.modelServer),
    model: t('on_device_model_fallback', fallback.model),
    useDevice: t('on_device_use_device', fallback.useDevice),
    useServer: t('on_device_use_server', fallback.useServer),
    notReadyTitle: t('assistant_not_ready_title', fallback.notReadyTitle),
    notReadyBody: t('assistant_not_ready_body', fallback.notReadyBody),
    errorDevice: t('assistant_error_device', fallback.errorDevice),
    actionLabels: (action) => l10n?.translate('action_$action'),
    receiptLabels: (receipt) {
      final key = receipt.key;
      final text = key == null ? null : l10n?.translate('receipt_$key');
      if (text == null) return null;
      var label = text;
      for (final MapEntry(:key, :value) in receipt.args.entries) {
        label = label.replaceAll('{$key}', value);
      }
      return label;
    },
  );
}
