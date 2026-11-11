import 'dart:convert';
import 'dart:io';

import 'package:flutter_agentify/domain/entities/app_theme_mode.dart';
import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

// Setup removes these with `--model server`.
const _onDeviceLabels = <String>{
  // @on-device:begin
  'action_download_on_device_model',
  'action_cancel_on_device_model_download',
  'action_delete_on_device_model',
  'action_dismiss_on_device_offer',
  'action_set_use_on_device_model',
  // @on-device:end
};

Map<String, Object?> _read(String code) =>
    jsonDecode(File('assets/lang/$code.json').readAsStringSync())
        as Map<String, Object?>;

void main() {
  final defaultCode = kSupportedLanguages.first.locale;

  group('Translations', () {
    test('every language code is listed once', () {
      final codes = [for (final l in kSupportedLanguages) l.locale];
      expect(codes.toSet(), hasLength(codes.length), reason: '$codes');
    });

    test('every JSON file in assets/lang/ is a supported language', () {
      final files = Directory('assets/lang')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.endsWith('.json'))
          .toSet();
      expect(files, {for (final l in kSupportedLanguages) '${l.locale}.json'});
    });

    for (final language in kSupportedLanguages) {
      final code = language.locale;

      test('$code.json has the same keys as $defaultCode.json', () {
        final keys = _read(code).keys.toSet();
        final defaultKeys = _read(defaultCode).keys.toSet();
        expect(
          keys.difference(defaultKeys),
          isEmpty,
          reason: 'Keys in $code.json but not in $defaultCode.json',
        );
        expect(
          defaultKeys.difference(keys),
          isEmpty,
          reason: 'Keys in $defaultCode.json but not in $code.json',
        );
      });

      test('$code.json has no empty values', () {
        for (final entry in _read(code).entries) {
          final value = entry.value;
          expect(value, isA<String>(), reason: 'Key "${entry.key}"');
          expect(value, isNot(''), reason: 'Key "${entry.key}" is empty');
        }
      });
    }

    test('every receipt the actions write has a translation', () {
      for (final language in kSupportedLanguages) {
        final strings = _read(language.locale);
        for (final key in [
          for (final mode in AppThemeMode.values) 'theme_${mode.name}',
          'language',
          'assistant_saved',
          'api_key_saved',
          'api_key_removed',
          'use_device',
          'use_server',
          'remembered',
          'forgot_memory',
          // @example:begin
          'created_item',
          'updated_item',
          'renamed_item',
          'changed_item_description',
          'cleared_item_description',
          'deleted_item',
          'deleted_items',
          'deleted_items_partial',
          // @example:end
        ]) {
          expect(
            strings['receipt_$key'],
            isNotNull,
            reason: '${language.locale}: receipt_$key',
          );
        }
      }
    });

    test('every action has a label in every language', () {
      final names = [
        for (final action in ActionsHarness().registry.all) action.name,
      ];
      for (final language in kSupportedLanguages) {
        final strings = _read(language.locale);
        for (final name in names) {
          expect(
            strings['action_$name'],
            isNotNull,
            reason: '${language.locale}: action_$name',
          );
        }
      }
    });

    test('specific English translations are correct', () {
      final enJson = _read('en');
      expect(enJson['home'], 'Home');
      expect(enJson['settings'], 'Settings');
      expect(enJson['theme'], 'Theme');
      expect(enJson['language'], 'Language');
      expect(enJson['retry'], 'Retry');
      expect(enJson['save'], 'Save');
      // @example:begin
      expect(enJson['cancel'], 'Cancel');
      expect(enJson['delete'], 'Delete');
      expect(enJson['edit'], 'Edit');
      expect(enJson['add_item'], 'Add Item');
      // @example:end
    });

    test('the default language has the expected key count', () {
      // Setup drops the on-device labels with `--model server`, so they
      // are left out of the count.
      final keyCount = _read(defaultCode).keys
          .where((key) => !_onDeviceLabels.contains(key))
          .length;
      // @example:begin
      expect(keyCount, 185);
      // @example:end
      // @empty: expect(keyCount, 156);
    });
  });
}
