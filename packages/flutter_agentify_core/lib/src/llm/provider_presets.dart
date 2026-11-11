import 'package:http/http.dart' as http;

import 'anthropic_provider.dart';
import 'llm_provider.dart';
import 'llm_types.dart';
import 'openai_compatible_provider.dart';

/// Whether a preset's server takes an API key.
enum KeyUse {
  /// Never sends a key, such as a model on this computer.
  none,

  /// Sends a key when one is saved, such as your own proxy.
  optional,

  /// Cannot answer without a key.
  required,
}

/// A starting point for the assistant's settings screen: where a kind of
/// model server lives and what its models can usually do.
class ProviderPreset {
  const ProviderPreset({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.keyUse,
    required this.defaults,
  });

  final String id;
  final String label;
  final String baseUrl;

  /// Whether the server takes an API key.
  final KeyUse keyUse;

  /// Model name (empty: the person fills it in) and capabilities.
  final ModelConfig defaults;
}

/// The presets the settings screen offers.
const List<ProviderPreset> providerPresets = [
  ProviderPreset(
    id: 'ollama',
    label: 'Ollama',
    baseUrl: 'http://localhost:11434/v1',
    keyUse: KeyUse.none,
    defaults: ModelConfig(model: ''),
  ),
  ProviderPreset(
    id: 'lm_studio',
    label: 'LM Studio',
    baseUrl: 'http://localhost:1234/v1',
    keyUse: KeyUse.none,
    defaults: ModelConfig(model: ''),
  ),
  ProviderPreset(
    id: 'openai',
    label: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    keyUse: KeyUse.required,
    defaults: ModelConfig(
      model: '',
      contextWindow: 128000,
      // Reasoning models spend output tokens before the visible reply.
      maxOutputTokens: 8192,
    ),
  ),
  ProviderPreset(
    id: 'openrouter',
    label: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    keyUse: KeyUse.required,
    defaults: ModelConfig(
      model: '',
      contextWindow: 128000,
      maxOutputTokens: 8192,
    ),
  ),
  ProviderPreset(
    id: 'gemini',
    label: 'Gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    keyUse: KeyUse.required,
    defaults: ModelConfig(
      model: '',
      contextWindow: 128000,
      maxOutputTokens: 8192,
    ),
  ),
  ProviderPreset(
    id: 'anthropic',
    label: 'Anthropic (Claude)',
    baseUrl: 'https://api.anthropic.com',
    keyUse: KeyUse.required,
    // Claude thinks before it answers, and thinking counts toward the
    // output limit, so it gets more room than the default.
    defaults: ModelConfig(
      model: 'claude-sonnet-5-5',
      contextWindow: 200000,
      maxOutputTokens: 16000,
    ),
  ),
  ProviderPreset(
    id: 'custom',
    label: 'Custom (OpenAI-compatible)',
    baseUrl: '',
    keyUse: KeyUse.optional,
    defaults: ModelConfig(model: ''),
  ),
];

/// The provider for a preset: [AnthropicProvider] for `anthropic`, an
/// [OpenAiCompatibleProvider] for every other id.
LlmProvider buildProvider({
  required String presetId,
  required String baseUrl,
  String? apiKey,
  http.Client? client,
}) => presetId == 'anthropic'
    ? AnthropicProvider(
        apiKey: apiKey ?? '',
        baseUrl: baseUrl.isEmpty ? 'https://api.anthropic.com' : baseUrl,
        client: client,
      )
    : OpenAiCompatibleProvider(
        baseUrl: baseUrl,
        apiKey: apiKey,
        // OpenAI's own API rejects max_tokens on its reasoning models.
        maxTokensField: presetId == 'openai'
            ? 'max_completion_tokens'
            : 'max_tokens',
        client: client,
      );
