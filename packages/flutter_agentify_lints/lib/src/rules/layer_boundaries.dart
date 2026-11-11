import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../app_paths.dart';

const _layers = {'domain', 'data', 'presentation'};

/// The Clean Architecture layer of a `lib`-relative path (`domain`, `data`
/// or `presentation`), or `null` for anything else.
String? layerOf(String? libRelative) {
  if (libRelative == null) return null;
  final first = libRelative.split('/').first;
  return _layers.contains(first) ? first : null;
}

/// `domain/` holds entities, repository interfaces and actions. It stays pure
/// Dart, so the same code runs in the app, in tests and in the action CLI.
class DomainLayerBoundaries extends AnalysisRule {
  static const LintCode code = LintCode(
    'domain_layer_boundaries',
    'domain/ must not import {0}.',
    correctionMessage:
        'Depend on a repository interface in domain/ and implement it in '
        'data/.',
  );

  DomainLayerBoundaries()
    : super(
        name: 'domain_layer_boundaries',
        description:
            'domain/ imports neither data/, presentation/ nor Flutter.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final path = context.definingUnit.file.path;
    if (layerOf(libRelativePath(path)) != 'domain') return;
    final visitor = _Visitor(this, _libRoot(path), forbidFlutter: true);
    registry.addImportDirective(this, visitor);
    registry.addExportDirective(this, visitor);
  }
}

/// `presentation/` reads and changes data through `domain/` (repository
/// interfaces and actions), never through `data/` directly.
class PresentationLayerBoundaries extends AnalysisRule {
  static const LintCode code = LintCode(
    'presentation_layer_boundaries',
    'presentation/ must not import {0}.',
    correctionMessage:
        'Read through a domain repository interface and change data through '
        'an action.',
  );

  PresentationLayerBoundaries()
    : super(
        name: 'presentation_layer_boundaries',
        description: 'presentation/ imports nothing from data/.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final path = context.definingUnit.file.path;
    if (layerOf(libRelativePath(path)) != 'presentation') return;
    final visitor = _Visitor(this, _libRoot(path), forbidFlutter: false);
    registry.addImportDirective(this, visitor);
    registry.addExportDirective(this, visitor);
  }
}

/// The part of [path] before its `lib`-relative part: the package root.
String _libRoot(String path) {
  final normalized = path.replaceAll(r'\', '/');
  return normalized.substring(
    0,
    normalized.length - libRelativePath(normalized)!.length,
  );
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.libRoot, {required this.forbidFlutter});

  final AnalysisRule rule;
  final String libRoot;

  /// Domain code stays pure Dart; presentation code is Flutter.
  final bool forbidFlutter;

  @override
  void visitImportDirective(ImportDirective node) => _report(node);

  @override
  void visitExportDirective(ExportDirective node) => _report(node);

  void _report(NamespaceDirective node) {
    final forbidden = _forbidden(node);
    if (forbidden != null) {
      rule.reportAtNode(node, arguments: [forbidden]);
    }
  }

  String? _forbidden(NamespaceDirective node) {
    final uri = node.uri.stringValue ?? '';
    if (forbidFlutter) {
      if (uri == 'dart:ui') return 'dart:ui';
      // flutter, flutter_riverpod, flutter_localizations…, but not this
      // framework's own flutter_agentify_*, which domain/ uses.
      if (uri.startsWith('package:flutter') &&
          !uri.startsWith('package:flutter_agentify')) {
        return 'Flutter';
      }
    }

    final imported = switch (node) {
      ImportDirective(:final libraryImport) => libraryImport?.importedLibrary,
      ExportDirective(:final libraryExport) => libraryExport?.exportedLibrary,
    };
    final importedPath = imported?.firstFragment.source.fullName;
    if (importedPath == null) return null;
    final relative = libRelativePath(importedPath);
    // Only this package's own layers count; other packages have their own.
    if (relative == null || _libRoot(importedPath) != libRoot) return null;
    return switch (layerOf(relative)) {
      'data' => 'data/',
      'presentation' when forbidFlutter => 'presentation/',
      _ => null,
    };
  }
}
