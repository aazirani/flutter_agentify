import 'dart:convert';

/// The `data` payloads of a server-sent event stream, one per event. Stops at
/// a `[DONE]` payload.
Stream<String> sseData(Stream<List<int>> bytes) async* {
  final data = <String>[];
  await for (final line in const LineSplitter().bind(
    utf8.decoder.bind(bytes),
  )) {
    if (line.isEmpty) {
      if (data.isEmpty) continue;
      final payload = data.join('\n');
      data.clear();
      if (payload == '[DONE]') return;
      yield payload;
    } else if (line.startsWith('data:')) {
      final value = line.substring(5);
      data.add(value.startsWith(' ') ? value.substring(1) : value);
    }
    // Comments (`:`) and other fields (event, id, retry) are not needed.
  }
  if (data.isNotEmpty && data.join('\n') != '[DONE]') yield data.join('\n');
}
