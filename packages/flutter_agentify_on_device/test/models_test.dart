import 'package:flutter_agentify_on_device/flutter_agentify_on_device.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Gemma 4 E2B downloads from a pinned revision, not main', () {
    expect(
      gemma4E2b.url,
      startsWith(
        'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/',
      ),
    );
    expect(gemma4E2b.url, isNot(contains('/main/')));
    expect(gemma4E2b.webUrl, isNot(contains('/main/')));
  });

  test('Gemma 4 E2B is about 2.6 GB with an 8192-token window', () {
    expect(gemma4E2b.sizeBytes, inInclusiveRange(2.4e9, 2.8e9));
    expect(gemma4E2b.config.contextWindow, 8192);
    expect(gemma4E2b.config.maxOutputTokens, 1024);
  });

  test('Gemma 4 E2B lets a 6 GB phone in and keeps a 3 GB phone out', () {
    // What the phones reported on 2026-11-11: an iPhone 13 Pro Max (6 GB)
    // ran it 10/10; the system ended the app on a Redmi A5 (3 GB) on GPU.
    const iPhone13ProMax = 5915017216;
    const redmiA5 = 2923429888;
    expect(iPhone13ProMax, greaterThanOrEqualTo(gemma4E2b.minRamBytes));
    expect(redmiA5, lessThan(gemma4E2b.minRamBytes));
  });

  test('Gemma 4 E2B matches the engine catalog entry', () {
    final native = LiteRtLmModels.gemma4E2bIt.generic.file;
    final web = LiteRtLmModels.gemma4E2bIt.web.file;
    expect(gemma4E2b.url, native.url);
    expect(gemma4E2b.sizeBytes, native.sizeBytes);
    expect(gemma4E2b.webUrl, web.url);
    expect(gemma4E2b.webSizeBytes, web.sizeBytes);
  });
}
