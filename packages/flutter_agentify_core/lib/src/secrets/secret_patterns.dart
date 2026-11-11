// shortcut: duplicated in flutter_agentify_lints (the plugin must not depend on this package); change both together.

/// Shapes of well-known API keys and private keys.
final List<RegExp> secretPatterns = List.unmodifiable([
  RegExp(r'(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}'),
  RegExp(r'AIza[0-9A-Za-z_-]{35}'),
  RegExp(r'gh[pousr]_[A-Za-z0-9]{36,}'),
  RegExp(r'github_pat_[A-Za-z0-9_]{22,}'),
  RegExp(r'xox[abprs]-[A-Za-z0-9-]{10,}'),
  RegExp(r'(?<![A-Z0-9])AKIA[0-9A-Z]{16}'),
  RegExp(r'(?<![A-Za-z0-9])[sr]k_(?:live|test)_[A-Za-z0-9]{20,}'),
  RegExp(r'(?<![A-Za-z0-9])gsk_[A-Za-z0-9]{20,}'),
  RegExp(r'(?<![A-Za-z0-9])hf_[A-Za-z0-9]{30,}'),
  RegExp(r'(?<![A-Za-z0-9])xai-[A-Za-z0-9]{40,}'),
  RegExp(
    r'(?<![A-Za-z0-9_-])eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}',
  ),
  RegExp(r'[Bb]earer\s+(?=[A-Za-z0-9._~+/=-]*\d)[A-Za-z0-9._~+/=-]{20,}'),
  RegExp(
    r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|$)',
  ),
]);

/// Whether [text] contains something shaped like an API key or private key.
bool looksLikeSecret(String text) =>
    secretPatterns.any((p) => p.hasMatch(text));
