import 'package:flutter_agentify_core/flutter_agentify_core.dart';

/// [text] as `set_assistant_provider` stores a server address: trimmed,
/// without trailing slashes.
String cleanBaseUrl(String text) =>
    text.trim().replaceFirst(RegExp(r'/+$'), '');

/// Which model server the assistant uses. The API key is kept apart, in a
/// `SecretStore`. The defaults are [ServerSetup]'s.
class AssistantSettings {
  const AssistantSettings({
    this.presetId = 'ollama',
    this.baseUrl = 'http://localhost:11434/v1',
    this.model = '',
    this.toolCalling,
    this.contextWindow,
  });

  /// The server values of the app's setup file, before anything is saved.
  factory AssistantSettings.fromServer(ServerSetup server) => AssistantSettings(
    presetId: server.presetId,
    baseUrl: server.baseUrl,
    model: server.model,
  );

  /// A preset id from `providerPresets`, such as `ollama`.
  final String presetId;
  final String baseUrl;
  final String model;

  /// Whether the model can call tools; null means the preset's default.
  final bool? toolCalling;

  /// The model's context window in tokens; null means the preset's default.
  final int? contextWindow;

  /// Whether a model can be reached: base URL and model are both set.
  bool get isConfigured => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  // Equal settings keep the running assistant: a theme or language change
  // re-reads them and must not restart the chat.
  @override
  bool operator ==(Object other) =>
      other is AssistantSettings &&
      other.presetId == presetId &&
      other.baseUrl == baseUrl &&
      other.model == model &&
      other.toolCalling == toolCalling &&
      other.contextWindow == contextWindow;

  @override
  int get hashCode =>
      Object.hash(presetId, baseUrl, model, toolCalling, contextWindow);
}

final _octet = RegExp(r'^(0|[1-9]\d{0,2})$');

/// Whether [host] (as `Uri.host` gives it, IPv6 without brackets) names
/// this computer or the local network, where plain `http://` is acceptable.
bool isLocalHost(String host) {
  final h = host.toLowerCase();
  if (h.isEmpty) return false;
  if (h.contains(':')) {
    if (h == '::1') return true;
    final first = int.tryParse(h.split(':').first, radix: 16);
    if (first == null) return false;
    // fc00::/7 (unique local) and fe80::/10 (link local).
    return first & 0xfe00 == 0xfc00 || first & 0xffc0 == 0xfe80;
  }
  final parts = h.split('.');
  if (parts.length == 4 && parts.every(_octet.hasMatch)) {
    final octets = [for (final p in parts) int.parse(p)];
    if (octets.any((o) => o > 255)) return false;
    final [a, b, ...] = octets;
    return a == 127 ||
        a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        (a == 169 && b == 254);
  }
  // A bare number is an address in disguise (http://134744072 is 8.8.8.8).
  if (!h.contains('.')) return int.tryParse(h) == null;
  return h == 'localhost' || h.endsWith('.local');
}
