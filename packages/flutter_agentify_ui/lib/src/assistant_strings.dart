import 'package:flutter_agentify_core/flutter_agentify_core.dart';

/// Every piece of text the chat shows. Pass translated values to fit the
/// app's languages; the defaults are English.
class AssistantStrings {
  const AssistantStrings({
    this.inputHint = 'Ask the assistant',
    this.send = 'Send',
    this.stop = 'Stop',
    this.approve = 'Approve',
    this.alwaysAllow = 'Always allow',
    this.reject = 'Reject',
    this.needsApprovalTitle = 'Approve this action?',
    this.answerOnlyNotice =
        'This model cannot use the app\'s actions. It answers from what is on '
        'screen.',
    this.toolRunning = 'Running',
    this.toolFailed = 'Failed',
    this.toolDeclined = 'Declined',
    this.toolStopped = 'Stopped',
    this.receiptUnverified =
        'Not confirmed: the app could not read this '
        'change back.',
    this.details = 'Details',
    this.thinking = 'The assistant is working',
    this.limitMaxSteps = 'Stopped: this reply took too many steps.',
    this.limitTokenBudget = 'Stopped: this reply used up its token budget.',
    this.limitRepeatedCall = 'Stopped: the assistant kept repeating an action.',
    this.limitOutput = 'Stopped: the reply reached the model\'s output limit.',
    this.cancelled = 'Stopped.',
    this.stopping = 'Stopping…',
    this.continueRun = 'Continue',
    this.errorConnection =
        'Can\'t reach the model server. Check that it is running and that '
        'its address in Settings is right.',
    this.errorTimeout = 'The model server stopped responding. Try again.',
    this.errorAuth =
        'The model server refused the API key. Check the key in '
        'Settings.',
    this.errorNotFound =
        'The model or the server address was not found. '
        'Check both in Settings.',
    this.errorRateLimit =
        'The model server is busy or the usage limit was reached. Wait a '
        'moment, then try again.',
    this.errorServer = 'The model server had a problem. Try again.',
    this.errorRequest =
        'The model server refused the request. Check the model settings.',
    this.errorBadReply =
        'The model server sent a reply the app could not read. Check the '
        'server address in Settings.',
    this.errorOther = 'Something went wrong. Try again.',
    this.openSettings = 'Open settings',
    this.retry = 'Retry',
    this.newChat = 'New chat',
    this.title = 'Assistant',
    this.close = 'Close',
    this.jumpToLatest = 'Jump to the newest message',
    this.conversations = 'Conversations',
    this.conversationsEmpty = 'No conversations yet.',
    this.conversationUntitled = 'New conversation',
    this.emptyTitle = 'How can I help?',
    this.emptyBody =
        'Ask about what is on screen, or ask me to do something in the app.',
    this.inspectorOpen = 'Open the inspector',
    this.inspectorTitle = 'Inspector',
    this.inspectorSystem = 'System text',
    this.inspectorTools = 'Active tools',
    this.inspectorCalls = 'Last tool calls',
    this.inspectorEmpty = 'Nothing to show yet. Send a message first.',
    this.onDevice = 'On this device',
    this.onDeviceMenu = 'Model on this device',
    this.onDeviceOfferTitle = 'Run the assistant on this device',
    this.onDeviceOfferBody =
        'Download {model} ({size}) so the assistant works offline and your '
        'messages stay on this device. Wi-Fi is recommended.',
    this.model = 'the assistant\'s model',
    this.onDeviceDownload = 'Download',
    this.onDeviceNotNow = 'Not now',
    this.onDeviceDownloading = 'Downloading… {received} of {total}',
    this.onDeviceCancel = 'Cancel',
    this.onDeviceLoading = 'Getting ready…',
    this.onDeviceUnsupported =
        'This device cannot run the on-device assistant.',
    this.onDeviceNoMemory = 'Not enough memory on this device.',
    this.onDeviceDownloadFailed =
        'The download failed. Check the connection and free space, then retry.',
    this.onDeviceMemoryFailed = 'The model did not fit in memory last time.',
    this.onDeviceLoadFailed = 'The model on this device could not start.',
    this.onDeviceDelete = 'Delete model',
    this.onDeviceNowAnswering = 'Now answered on this device',
    this.onDeviceLeaveBody =
        'This conversation was answered on this device. Continue with '
        '{server}? The whole conversation will be sent to it.',
    this.onDeviceLeaveContinue = 'Continue with {server}',
    this.onDeviceLeaveNew = 'Start a new chat',
    this.modelServer = 'the model server',
    this.useDevice = 'Answer on this device',
    this.useServer = 'Answer with {server}',
    this.notReadyTitle = 'Not ready yet',
    this.notReadyBody = 'The assistant needs a model before it can answer.',
    this.errorDevice = 'The model on this device had a problem. Try again.',
    this.actionLabels,
    this.receiptLabels,
  });

  /// The header when the model inside the app answers.
  final String onDevice;

  /// The tooltip of the chat's model menu (Download, the switch between
  /// device and server, Delete model).
  final String onDeviceMenu;
  final String onDeviceOfferTitle;

  /// `{model}` becomes the model's name, `{size}` the download size, such
  /// as 2.6 GB.
  final String onDeviceOfferBody;

  /// Stands for `{model}` when the model has no name.
  final String model;
  final String onDeviceDownload;
  final String onDeviceNotNow;

  /// `{received}` and `{total}` become sizes such as 958 MB and 2.6 GB;
  /// `{percent}` becomes 0 to 100.
  final String onDeviceDownloading;
  final String onDeviceCancel;
  final String onDeviceLoading;
  final String onDeviceUnsupported;
  final String onDeviceNoMemory;
  final String onDeviceDownloadFailed;
  final String onDeviceMemoryFailed;
  final String onDeviceLoadFailed;
  final String onDeviceDelete;

  /// The line in a conversation where the model inside the app took over.
  final String onDeviceNowAnswering;

  /// `{server}` becomes the server's name.
  final String onDeviceLeaveBody;
  final String onDeviceLeaveContinue;
  final String onDeviceLeaveNew;

  /// Stands for `{server}` when the server has no name.
  final String modelServer;

  /// The chat menu's entries that choose the in-app model or the server;
  /// `{server}` becomes the server's name.
  final String useDevice;
  final String useServer;

  /// The empty chat while no model can answer yet.
  final String notReadyTitle;
  final String notReadyBody;

  /// Every error while the model inside the app answers.
  final String errorDevice;

  final String inputHint;
  final String send;
  final String stop;
  final String approve;
  final String alwaysAllow;
  final String reject;
  final String needsApprovalTitle;
  final String answerOnlyNotice;
  final String toolRunning;
  final String toolFailed;

  /// A tool the person rejected.
  final String toolDeclined;

  /// A tool cut off by Stop.
  final String toolStopped;

  /// The tooltip of a receipt the action could not read back.
  final String receiptUnverified;

  /// Opens the arguments of an approval that has a summary.
  final String details;

  /// What a screen reader says for the thinking indicator.
  final String thinking;
  final String limitMaxSteps;
  final String limitTokenBudget;
  final String limitRepeatedCall;
  final String limitOutput;
  final String cancelled;

  /// The disabled stop button while a started write finishes.
  final String stopping;

  /// The button on a limit notice; it is also the message it sends.
  final String continueRun;

  /// Error messages, one per [LlmErrorKind], each with a next step.
  final String errorConnection;
  final String errorTimeout;
  final String errorAuth;
  final String errorNotFound;
  final String errorRateLimit;
  final String errorServer;
  final String errorRequest;
  final String errorBadReply;
  final String errorOther;
  final String openSettings;
  final String retry;
  final String newChat;

  /// The chat's heading.
  final String title;
  final String close;
  final String jumpToLatest;
  final String conversations;
  final String conversationsEmpty;

  /// A conversation with no messages yet.
  final String conversationUntitled;
  final String emptyTitle;
  final String emptyBody;

  /// Debug inspector texts (debug builds only).
  final String inspectorOpen;
  final String inspectorTitle;
  final String inspectorSystem;
  final String inspectorTools;
  final String inspectorCalls;
  final String inspectorEmpty;

  /// Translated names of actions, such as "Delete item" for `delete_item`;
  /// null for an action falls back to [actionLabel]'s readable form.
  final String? Function(String action)? actionLabels;

  /// Translated receipts, such as "مورد «نان» ساخته شد" for
  /// `created_item`; null for a receipt shows its English summary.
  final String? Function(Receipt receipt)? receiptLabels;

  /// What a receipt chip says for [receipt].
  String receiptLabel(Receipt receipt) =>
      receiptLabels?.call(receipt) ?? receipt.summary;

  /// What tool rows and approval cards call [action].
  String actionLabel(String action) {
    if (actionLabels?.call(action) case final label?) return label;
    final words = action.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    return words.isEmpty ? action : words[0].toUpperCase() + words.substring(1);
  }

  /// The message for an error of [kind].
  String error(LlmErrorKind kind) => switch (kind) {
    LlmErrorKind.connection => errorConnection,
    LlmErrorKind.timeout => errorTimeout,
    LlmErrorKind.auth => errorAuth,
    LlmErrorKind.notFound => errorNotFound,
    LlmErrorKind.rateLimit => errorRateLimit,
    LlmErrorKind.server => errorServer,
    LlmErrorKind.request => errorRequest,
    LlmErrorKind.badReply => errorBadReply,
    LlmErrorKind.other => errorOther,
  };
}
