import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:test/test.dart';

void main() {
  test('cutText leaves short text alone', () {
    expect(cutText('abc', 5), 'abc');
  });

  test('cutText cuts and adds the suffix', () {
    expect(cutText('abcdef', 2, suffix: '…'), 'ab…');
  });

  test('cutText never splits a surrogate pair', () {
    expect(cutText('ab😀cd', 3), 'ab');
  });

  test('cutText counts a negative max as 0', () {
    expect(cutText('abc', -4, suffix: 'x'), 'x');
  });
}
