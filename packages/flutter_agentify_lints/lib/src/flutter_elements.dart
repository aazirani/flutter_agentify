import 'package:analyzer/dart/element/element.dart';

/// Whether [element] is declared in Flutter (`package:flutter/…` or
/// `dart:ui`).
bool isFromFlutter(Element? element) {
  final uri = element?.library?.uri.toString() ?? '';
  return uri.startsWith('package:flutter/') || uri == 'dart:ui';
}

/// Whether [element] is named [name] and declared in Flutter.
bool isFlutterElement(Element? element, String name) =>
    element?.name == name && isFromFlutter(element);
