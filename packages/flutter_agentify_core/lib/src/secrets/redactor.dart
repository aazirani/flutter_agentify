import 'secret_patterns.dart';

/// Replaces anything shaped like a key before text reaches a model or a log.
class Redactor {
  const Redactor();

  String redact(String text) {
    var result = text;
    for (final pattern in secretPatterns) {
      result = result.replaceAll(pattern, '[redacted]');
    }
    return result;
  }
}
