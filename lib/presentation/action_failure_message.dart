import 'package:flutter/material.dart';
import 'package:flutter_agentify/utils/locale/app_localization.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';

/// Shows [failure] as a short, localized message.
void showActionFailure(BuildContext context, ActionFailure failure) {
  final key = switch (failure.code) {
    'not_found' => 'error_not_found',
    'invalid_input' => 'error_invalid_input',
    // @on-device:begin
    'unsupported' => 'on_device_unsupported',
    // @on-device:end
    _ => 'error_generic',
  };
  final text = AppLocalizations.of(context)?.translate(key) ?? key;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
