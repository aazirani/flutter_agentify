import 'package:flutter_agentify_core/flutter_agentify_core.dart';

/// Gemma 4 E2B (Apache-2.0, no Hugging Face token), from the engine's catalog
/// entry `LiteRtLmModels.gemma4E2bIt.generic` and `.web` at revision
/// b3ca0d2f; a test keeps the two in step.
const gemma4E2b = OnDeviceModelSpec(
  id: 'gemma-4-e2b-it',
  label: 'Gemma 4 E2B',
  url:
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/'
      'resolve/b3ca0d2f076785a8f4b2219ddbd2bdb99954eae1/gemma-4-E2B-it.litertlm',
  webUrl:
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/'
      'resolve/b3ca0d2f076785a8f4b2219ddbd2bdb99954eae1/'
      'gemma-4-E2B-it-web.litertlm',
  sizeBytes: 2588147712,
  webSizeBytes: 2008432640,
  // Phones sold with 6 GB report less (an iPhone 13 Pro Max reports 5.5 GiB
  // and peaked at 2.4 GB); a 3 GB Redmi A5 ran out of memory on GPU.
  minRamBytes: 5 * 1024 * 1024 * 1024,
  config: ModelConfig(
    model: 'gemma-4-e2b',
    contextWindow: 8192,
    maxOutputTokens: 1024,
  ),
);
