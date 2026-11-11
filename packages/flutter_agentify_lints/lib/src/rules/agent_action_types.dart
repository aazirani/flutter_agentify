import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Whether [element] is `AgentAction` from flutter_agentify_core or extends
/// it.
bool isAgentAction(InterfaceElement? element) {
  if (element == null) return false;
  bool isBase(InterfaceType type) =>
      type.element.name == 'AgentAction' &&
      (type.element.library.uri.toString()).startsWith(
        'package:flutter_agentify_core/',
      );
  return isBase(element.thisType) || element.allSupertypes.any(isBase);
}
