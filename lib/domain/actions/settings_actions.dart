import 'dart:async';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';

import '../entities/app_theme_mode.dart';
import '../entities/assistant_settings.dart';
import '../entities/language/supported_languages.dart';
import '../repositories/secret_store.dart';
import '../repositories/settings_repository.dart';

/// `set_theme_mode`: light, dark or the system's choice.
class SetThemeMode extends AgentAction<AppThemeMode, AppThemeMode> {
  SetThemeMode(this.settings);

  final SettingsRepository settings;

  @override
  String get name => 'set_theme_mode';

  @override
  String get description =>
      'Switches the app between light and dark, or follows the system.';

  @override
  late final ObjectSchema<AppThemeMode> input = S.object(
    fields: {
      'mode': S.string(
        description: 'system, light or dark.',
        oneOf: [for (final mode in AppThemeMode.values) mode.name],
      ),
    },
    build: (v) => AppThemeMode.values.byName(v['mode'] as String),
  );

  @override
  List<String> get resources => const ['settings'];

  @override
  List<String> get searchHints => const [
    'theme',
    'dark',
    'light',
    'appearance',
  ];

  @override
  Future<AppThemeMode> run(AppThemeMode input, ActionContext context) async {
    await settings.setThemeMode(input);
    context.receipt(
      resource: 'settings',
      ids: const ['theme_mode'],
      summary: 'Theme set to ${input.name}',
      key: 'theme_${input.name}',
      verified: settings.getThemeMode() == input,
    );
    return input;
  }

  @override
  Object? encode(AppThemeMode output) => output.name;
}

/// `set_language`: the app's language.
class SetLanguage extends AgentAction<String, String> {
  SetLanguage(this.settings);

  final SettingsRepository settings;

  @override
  String get name => 'set_language';

  @override
  String get description => 'Changes the language of the app.';

  @override
  late final ObjectSchema<String> input = S.object(
    fields: {
      'locale': S.string(
        description: 'A language code the app supports.',
        oneOf: [for (final language in kSupportedLanguages) language.locale],
      ),
    },
    build: (v) => v['locale'] as String,
  );

  @override
  List<String> get resources => const ['settings'];

  @override
  List<String> get searchHints => const ['language', 'locale', 'translate'];

  @override
  Future<String> run(String input, ActionContext context) async {
    final language = kSupportedLanguages
        .where((l) => l.locale == input)
        .firstOrNull;
    if (language == null) {
      throw ActionFailure(
        'invalid_input',
        'The app has no language "$input".',
        details: {'path': r'$.locale'},
      );
    }
    await settings.setLocale(input);
    context.receipt(
      resource: 'settings',
      ids: const ['locale'],
      summary: 'Language set to ${language.englishName}',
      key: 'language',
      // Each language in its own name, as the language picker shows it.
      args: {'language': language.language},
      verified: settings.getLocale() == input,
    );
    return input;
  }

  @override
  Object? encode(String output) => output;
}

/// `set_assistant_provider`: which model the assistant uses. UI only.
class SetAssistantProvider
    extends AgentAction<AssistantSettings, AssistantSettings> {
  SetAssistantProvider(this.settings);

  final SettingsRepository settings;

  @override
  String get name => 'set_assistant_provider';

  @override
  String get description =>
      'Saves which model server and model the assistant uses.';

  @override
  late final ObjectSchema<AssistantSettings> input = S.object(
    fields: {
      'preset': S.string(
        description: 'The kind of server, such as ollama or openai.',
        oneOf: [for (final preset in providerPresets) preset.id],
      ),
      'base_url': S.string(description: 'The server address.'),
      'model': S.string(description: 'The model name.'),
      'tool_calling': S
          .boolean(description: 'Whether the model can call tools.')
          .optional(),
      'context_window': S
          .integer(
            description: 'The model context window in tokens.',
            min: 1024,
          )
          .optional(),
    },
    build: (v) => AssistantSettings(
      presetId: v['preset'] as String,
      baseUrl: v['base_url'] as String,
      model: v['model'] as String,
      toolCalling: v['tool_calling'] as bool?,
      contextWindow: v['context_window'] as int?,
    ),
  );

  @override
  bool get agentTool => false;

  @override
  List<String> get resources => const ['settings'];

  @override
  Future<AssistantSettings> run(
    AssistantSettings input,
    ActionContext context,
  ) async {
    final preset = _preset(input.presetId);
    final window = input.contextWindow;
    if (window != null && window < 1024) {
      throw const ActionFailure(
        'invalid_input',
        'The context window must be at least 1024 tokens.',
        details: {'path': r'$.context_window'},
      );
    }
    // Typed calls from the settings screen skip the schema, so the cleanup
    // happens here.
    final cleaned = AssistantSettings(
      presetId: input.presetId,
      baseUrl: cleanBaseUrl(input.baseUrl),
      model: input.model.trim(),
      toolCalling: input.toolCalling,
      contextWindow: window,
    );
    final address = Uri.tryParse(cleaned.baseUrl);
    final host = address?.host ?? '';
    if (address == null ||
        !(address.isScheme('http') || address.isScheme('https')) ||
        host.isEmpty) {
      throw const ActionFailure(
        'invalid_input',
        'The server address must start with http:// or https:// and name a '
            'host.',
        details: {'path': r'$.base_url'},
      );
    }
    // A key sent over plain http to the internet can be read on the way.
    if (address.isScheme('http') &&
        preset.keyUse != KeyUse.none &&
        !isLocalHost(host)) {
      throw const ActionFailure(
        'invalid_input',
        'Use https:// for a server outside your own network. http:// is only '
            'for local servers.',
        details: {'path': r'$.base_url'},
      );
    }
    await settings.setAssistantSettings(cleaned);
    final saved = settings.getAssistantSettings();
    context.receipt(
      resource: 'settings',
      ids: const ['assistant'],
      summary: 'Assistant model settings saved',
      key: 'assistant_saved',
      verified:
          saved.model == cleaned.model && saved.baseUrl == cleaned.baseUrl,
    );
    return saved;
  }

  @override
  Object? encode(AssistantSettings output) => {
    'preset': output.presetId,
    'base_url': output.baseUrl,
    'model': output.model,
    'tool_calling': ?output.toolCalling,
    'context_window': ?output.contextWindow,
  };
}

/// The preset with [id], or `invalid_input`.
ProviderPreset _preset(String id) =>
    providerPresets.where((p) => p.id == id).firstOrNull ??
    (throw ActionFailure(
      'invalid_input',
      'There is no preset "$id".',
      details: const {'path': r'$.preset'},
    ));

/// `set_api_key`: stores or removes the API key of one preset. UI only; the
/// key never appears in output or receipts.
class SetApiKey extends AgentAction<({String presetId, String key}), bool> {
  SetApiKey(this.secrets);

  final SecretStore secrets;

  @override
  String get name => 'set_api_key';

  @override
  String get description =>
      'Stores the API key for one kind of model server, or removes it.';

  @override
  late final ObjectSchema<({String presetId, String key})> input = S.object(
    fields: {
      'preset': S.string(
        description: 'The kind of server the key is for, such as openai.',
        oneOf: [for (final preset in providerPresets) preset.id],
      ),
      'key': S.string(description: 'The API key; an empty string removes it.'),
    },
    build: (v) => (presetId: v['preset'] as String, key: v['key'] as String),
  );

  @override
  bool get agentTool => false;

  @override
  List<String> get resources => const ['settings'];

  @override
  Future<bool> run(
    ({String presetId, String key}) input,
    ActionContext context,
  ) async {
    final presetId = _preset(input.presetId).id;
    final key = input.key.trim();
    await secrets.setApiKey(presetId, key.isEmpty ? null : key);
    final stored = await secrets.getApiKey(presetId);
    final saved = key.isNotEmpty;
    context.receipt(
      resource: 'settings',
      ids: const ['api_key'],
      summary: saved ? 'API key saved' : 'API key removed',
      key: saved ? 'api_key_saved' : 'api_key_removed',
      verified: saved ? stored == key : stored == null,
    );
    return saved;
  }

  @override
  Object? encode(bool output) => {'saved': output};
}

/// `reset_approvals`: forgets every "Always allow", so the assistant asks
/// again before each action that needs approval. UI only.
class ResetApprovals extends AgentAction<Null, bool> {
  ResetApprovals(this.approvals);

  final ApprovalPrefs approvals;

  @override
  String get name => 'reset_approvals';

  @override
  String get description =>
      'Forgets every always-allow, so the assistant asks again before each '
      'action that needs approval.';

  @override
  late final ObjectSchema<Null> input = S.object(
    fields: const {},
    build: (_) => null,
  );

  @override
  bool get agentTool => false;

  @override
  List<String> get resources => const ['approvals'];

  @override
  Future<bool> run(Null input, ActionContext context) async {
    await approvals.clear();
    return true;
  }

  @override
  Object? encode(bool output) => {'reset': output};
}
// @on-device:begin

/// The in-app model, or null when the app has none.
typedef OnDeviceModelLookup = OnDeviceModelController? Function();

OnDeviceModelController _model(OnDeviceModelLookup lookup) =>
    lookup() ??
    (throw const ActionFailure(
      'unavailable',
      'This app has no model that runs on the device.',
    ));

/// The input of the on-device actions: nothing.
final _none = S.object(fields: const {}, build: (_) => null);

/// `download_on_device_model`: downloads the in-app model (or again after a
/// failure) and loads it once it is in. Returns at once; the chat shows the
/// progress.
class DownloadOnDeviceModel extends AgentAction<Null, String> {
  DownloadOnDeviceModel(this.model);

  final OnDeviceModelLookup model;

  @override
  String get name => 'download_on_device_model';

  @override
  String get description =>
      'Downloads the model that runs on this device, then loads it.';

  @override
  ObjectSchema<Null> get input => _none;

  @override
  bool get agentTool => false;

  @override
  List<String> get resources => const ['on_device_model'];

  @override
  Future<String> run(Null input, ActionContext context) async {
    final controller = _model(model);
    await controller.started;
    if (controller.state is ModelUnsupported) {
      throw const ActionFailure(
        'unsupported',
        'This device cannot run the model.',
      );
    }
    final Future<void> download = controller.state is ModelFailed
        ? controller.retry()
        : controller.download();
    unawaited(download.then((_) => controller.ensureLoaded()));
    return 'started';
  }

  @override
  Object? encode(String output) => {'download': output};
}

/// `cancel_on_device_model_download`: stops the download; nothing stays.
class CancelOnDeviceModelDownload extends AgentAction<Null, bool> {
  CancelOnDeviceModelDownload(this.model);

  final OnDeviceModelLookup model;

  @override
  String get name => 'cancel_on_device_model_download';

  @override
  String get description => 'Stops downloading the model for this device.';

  @override
  ObjectSchema<Null> get input => _none;

  @override
  bool get agentTool => false;

  @override
  List<String> get resources => const ['on_device_model'];

  @override
  Future<bool> run(Null input, ActionContext context) async {
    await _model(model).cancelDownload();
    return true;
  }

  @override
  Object? encode(bool output) => {'cancelled': output};
}

/// `delete_on_device_model`: frees the model's memory and disk space.
class DeleteOnDeviceModel extends AgentAction<Null, bool> {
  DeleteOnDeviceModel(this.model);

  final OnDeviceModelLookup model;

  @override
  String get name => 'delete_on_device_model';

  @override
  String get description =>
      'Deletes the model that runs on this device to free space.';

  @override
  ObjectSchema<Null> get input => _none;

  @override
  bool get agentTool => false;

  @override
  List<String> get resources => const ['on_device_model'];

  @override
  Future<bool> run(Null input, ActionContext context) async {
    await _model(model).delete();
    return true;
  }

  @override
  Object? encode(bool output) => {'deleted': output};
}

/// `dismiss_on_device_offer`: remembers "Not now" for the download offer.
class DismissOnDeviceOffer extends AgentAction<Null, bool> {
  DismissOnDeviceOffer(this.settings);

  final SettingsRepository settings;

  @override
  String get name => 'dismiss_on_device_offer';

  @override
  String get description =>
      'Hides the offer to download the model for this device.';

  @override
  ObjectSchema<Null> get input => _none;

  @override
  bool get agentTool => false;

  @override
  List<String> get resources => const ['settings'];

  @override
  Future<bool> run(Null input, ActionContext context) async {
    await settings.setOnDeviceOfferDismissed(true);
    return true;
  }

  @override
  Object? encode(bool output) => {'dismissed': output};
}

/// `set_use_on_device_model`: whether the model on this device answers once
/// it is ready, or the model server does. Only in `ModelMode.both`.
class SetUseOnDeviceModel extends AgentAction<bool, bool> {
  SetUseOnDeviceModel(this.settings, this.model);

  final SettingsRepository settings;
  final OnDeviceModelLookup model;

  @override
  String get name => 'set_use_on_device_model';

  @override
  String get description =>
      'Chooses whether the assistant answers with the model on this device '
      'or with the model server.';

  @override
  late final ObjectSchema<bool> input = S.object(
    fields: {
      'use': S.boolean(
        description:
            'true: the model on this device answers once it is ready. '
            'false: the model server answers.',
      ),
    },
    build: (v) => v['use'] as bool,
  );

  @override
  List<String> get resources => const ['settings'];

  @override
  List<String> get searchHints => const [
    'on device',
    'offline',
    'local model',
    'model server',
  ];

  @override
  Future<bool> run(bool input, ActionContext context) async {
    await settings.setUseOnDeviceModel(input);
    // Turned on: load a downloaded model now, not when the chat next opens.
    if (input) unawaited(model()?.ensureLoaded());
    context.receipt(
      resource: 'settings',
      ids: const ['use_on_device_model'],
      summary: input
          ? 'The model on this device answers'
          : 'The model server answers',
      key: input ? 'use_device' : 'use_server',
      verified: settings.getUseOnDeviceModel() == input,
    );
    return input;
  }

  @override
  Object? encode(bool output) => {'use': output};
}
// @on-device:end
