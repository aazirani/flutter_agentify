import 'dart:convert';

import 'package:flutter_agentify_core/src/llm/sse.dart';
import 'package:test/test.dart';

Future<List<String>> _decode(List<String> chunks) =>
    sseData(Stream.fromIterable(chunks.map(utf8.encode))).toList();

void main() {
  test('data lines split across chunks are joined', () async {
    expect(await _decode(['data: {"a"', ':1}\n', '\ndata: 2\n\n']), [
      '{"a":1}',
      '2',
    ]);
  });

  test('multi-line data is joined with newlines', () async {
    expect(await _decode(['data: one\ndata: two\n\n']), ['one\ntwo']);
  });

  test('comment lines and other fields are ignored', () async {
    expect(
      await _decode([': keep-alive\n\nevent: message\nid: 1\ndata: x\n\n']),
      ['x'],
    );
  });

  test('[DONE] ends the stream', () async {
    expect(await _decode(['data: a\n\ndata: [DONE]\n\ndata: b\n\n']), ['a']);
  });

  test('CRLF line endings work', () async {
    expect(await _decode(['data: a\r\n\r\ndata: b\r\n', '\r\n']), ['a', 'b']);
  });

  test('a last event without a blank line is still emitted', () async {
    expect(await _decode(['data: a\n\ndata: b']), ['a', 'b']);
  });

  test('a multi-byte character split across chunks survives', () async {
    final bytes = utf8.encode('data: é\n\n');
    final stream = Stream.fromIterable([bytes.sublist(0, 7), bytes.sublist(7)]);
    expect(await sseData(stream).toList(), ['é']);
  });
}
