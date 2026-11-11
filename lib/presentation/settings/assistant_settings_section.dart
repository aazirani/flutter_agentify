import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify/domain/repositories/secret_store.dart';
import 'package:flutter_agentify/presentation/action_failure_message.dart';
import 'package:flutter_agentify/presentation/providers/assistant_settings_provider.dart';
import 'package:flutter_agentify/utils/locale/app_localization.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the person chooses the assistant's model: a preset, the server
/// address, the model, the key, and what the model can do.
class AssistantSettingsSection extends ConsumerStatefulWidget {
  const AssistantSettingsSection({super.key, this.isWeb = kIsWeb});

  /// On web no key is entered or stored: use a proxy or a local server.
  final bool isWeb;

  @override
  ConsumerState<AssistantSettingsSection> createState() =>
      _AssistantSettingsSectionState();
}

class _AssistantSettingsSectionState
    extends ConsumerState<AssistantSettingsSection> {
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _key = TextEditingController();
  final _contextWindow = TextEditingController();
  late String _presetId;
  late bool _toolCalling;
  var _keyEdited = false;
  var _keyVisible = false;
  var _keyStored = false;
  var _saving = false;

  /// Translation keys of the errors shown under the address and the
  /// context window, or null.
  String? _baseUrlError;
  String? _windowError;

  ProviderPreset get _preset => providerPresets.firstWhere(
    (p) => p.id == _presetId,
    orElse: () => providerPresets.last,
  );

  bool get _showKey => !widget.isWeb && _preset.keyUse != KeyUse.none;

  /// Web stores no key, so presets that cannot work without one are left out.
  List<ProviderPreset> get _presets => [
    for (final preset in providerPresets)
      if (!widget.isWeb || preset.keyUse != KeyUse.required) preset,
  ];

  String _t(String key) => AppLocalizations.of(context)?.translate(key) ?? key;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(assistantSettingsProvider);
    _presetId = _presets.any((p) => p.id == saved.presetId)
        ? saved.presetId
        : 'custom';
    _baseUrl.text = saved.baseUrl;
    _model.text = saved.model;
    _toolCalling = saved.toolCalling ?? _preset.defaults.toolCalling;
    _contextWindow.text =
        '${saved.contextWindow ?? _preset.defaults.contextWindow}';
    _model.addListener(() => setState(() {}));
    _baseUrl.addListener(() => setState(() => _baseUrlError = null));
    _contextWindow.addListener(() => setState(() => _windowError = null));
    if (!widget.isWeb) _refreshKeyStored();
  }

  Future<void> _refreshKeyStored() async {
    final presetId = _presetId;
    final stored =
        await ServiceLocator.getIt<SecretStore>().getApiKey(presetId) != null;
    // The person may have chosen another preset while this was read.
    if (mounted && presetId == _presetId) {
      setState(() => _keyStored = stored);
    }
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _key.dispose();
    _contextWindow.dispose();
    super.dispose();
  }

  void _choosePreset(String? id) {
    if (id == null) return;
    // Back on the saved preset, its saved values return.
    final saved = ref.read(assistantSettingsProvider);
    final back = id == saved.presetId;
    setState(() {
      _presetId = id;
      final defaults = _preset.defaults;
      _baseUrl.text = back ? saved.baseUrl : _preset.baseUrl;
      _model.text = back ? saved.model : defaults.model;
      _toolCalling = back
          ? saved.toolCalling ?? defaults.toolCalling
          : defaults.toolCalling;
      _contextWindow.text =
          '${back ? saved.contextWindow ?? defaults.contextWindow : defaults.contextWindow}';
      // A key typed for the previous preset must not be saved for this one.
      _key.clear();
      _keyEdited = false;
      _keyStored = false;
    });
    if (!widget.isWeb) _refreshKeyStored();
  }

  /// Whether the form differs from what is stored.
  bool _changed(AssistantSettings saved) {
    final defaults = _preset.defaults;
    return _keyEdited ||
        _presetId != saved.presetId ||
        cleanBaseUrl(_baseUrl.text) != saved.baseUrl ||
        _model.text.trim() != saved.model ||
        _toolCalling != (saved.toolCalling ?? defaults.toolCalling) ||
        _contextWindow.text.trim() !=
            '${saved.contextWindow ?? defaults.contextWindow}';
  }

  Future<void> _save() async {
    final registry = ServiceLocator.getIt<ActionRegistry>();
    final actions = ServiceLocator.getIt<AppActions>();
    final defaults = _preset.defaults;
    final windowText = _contextWindow.text.trim();
    final window = int.tryParse(windowText);
    if (windowText.isNotEmpty && window == null) {
      setState(() => _windowError = 'assistant_context_window_invalid');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final saved = _t('assistant_settings_saved');
    setState(() => _saving = true);
    try {
      final stored = await registry.run(
        actions.setAssistantProvider,
        AssistantSettings(
          presetId: _presetId,
          baseUrl: _baseUrl.text,
          model: _model.text,
          // Only differences from the preset are stored.
          toolCalling: _toolCalling == defaults.toolCalling
              ? null
              : _toolCalling,
          contextWindow: window == null || window == defaults.contextWindow
              ? null
              : window,
        ),
      );
      if (mounted) {
        _baseUrl.text = stored.baseUrl;
        _model.text = stored.model;
      }
      if (_showKey && _keyEdited) {
        await registry.run(actions.setApiKey, (
          presetId: _presetId,
          key: _key.text,
        ));
        _key.clear();
        _keyEdited = false;
        await _refreshKeyStored();
      }
      messenger.showSnackBar(SnackBar(content: Text(saved)));
    } on ActionFailure catch (failure) {
      if (!mounted) return;
      // The action names the field it refused; say why under that field.
      switch (failure.details?['path']) {
        case r'$.base_url':
          final address = Uri.tryParse(_baseUrl.text.trim());
          // A valid http address is refused only when it is not local.
          final needsHttps =
              address != null &&
              address.isScheme('http') &&
              address.host.isNotEmpty;
          setState(
            () => _baseUrlError = needsHttps
                ? 'assistant_base_url_needs_https'
                : 'assistant_base_url_invalid',
          );
        case r'$.context_window':
          setState(() => _windowError = 'assistant_context_window_too_small');
        default:
          showActionFailure(context, failure);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stored = ref.watch(assistantSettingsProvider);
    final baseUrlError = _baseUrlError;
    final windowError = _windowError;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t('assistant_server_section'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('assistant_preset'),
            initialValue: _presetId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _t('assistant_preset'),
              helperText: widget.isWeb
                  ? _t('assistant_web_presets_hint')
                  : null,
              helperMaxLines: 3,
            ),
            items: [
              for (final preset in _presets)
                DropdownMenuItem(value: preset.id, child: Text(preset.label)),
            ],
            onChanged: _choosePreset,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrl,
            keyboardType: TextInputType.url,
            // Addresses, model names and keys read left to right in every
            // language.
            textDirection: TextDirection.ltr,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: _t('assistant_base_url'),
              hintText: _t('assistant_base_url_hint'),
              hintTextDirection: TextDirection.ltr,
              errorText: baseUrlError == null ? null : _t(baseUrlError),
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: _t('assistant_model'),
              helperText: _t('assistant_model_hint'),
              helperMaxLines: 2,
            ),
          ),
          if (_showKey) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              obscureText: !_keyVisible,
              textDirection: TextDirection.ltr,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() => _keyEdited = true),
              decoration: InputDecoration(
                labelText: _t('assistant_api_key'),
                helperText: _keyStored ? _t('assistant_key_saved') : null,
                helperMaxLines: 2,
                suffixIcon: IconButton(
                  tooltip: _t(
                    _keyVisible ? 'assistant_hide_key' : 'assistant_show_key',
                  ),
                  icon: Icon(
                    _keyVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _keyVisible = !_keyVisible),
                ),
              ),
            ),
          ],
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(_t('assistant_advanced')),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_t('assistant_tool_calling')),
                value: _toolCalling,
                onChanged: (value) => setState(() => _toolCalling = value),
              ),
              TextField(
                controller: _contextWindow,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t('assistant_context_window'),
                  errorText: windowError == null ? null : _t(windowError),
                  errorMaxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed:
                  _saving ||
                      !_changed(stored) ||
                      _model.text.trim().isEmpty ||
                      _baseUrl.text.trim().isEmpty
                  ? null
                  : _save,
              child: Text(_t('save')),
            ),
          ),
        ],
      ),
    );
  }
}
