import 'dart:io';

const _commonForbiddenImports = <String>[
  'dart:ui',
  'package:flutter/',
  'package:flutter_bloc/',
  'package:go_router/',
  'package:get_it/',
  'package:injectable/',
  'package:firebase_',
  'package:cloud_firestore/',
  'package:image_picker/',
  'package:image/',
  'package:flutter_local_notifications/',
  'package:flutter_timezone/',
  'package:shared_preferences/',
  'package:plantcare_data/',
  'package:plantcare_features/',
  'package:plantcare_ai/',
];

const _dataForbiddenImports = <String>[
  'package:plantcare_ai/',
  'package:plantcare_features/',
  'package:flutter_bloc/',
  'package:go_router/',
  '/app/',
  '/features/',
  '/presentation/',
  '/pages/',
  '/widgets/',
  '/bloc/',
];

const _presentationForbiddenImports = <String>[
  'package:plantcare_data/',
  'package:plantcare_app/',
  'package:plantcare_ai/',
  'package:firebase_',
  'package:cloud_firestore/',
  'package:image_picker/',
  'package:flutter_local_notifications/',
  'package:flutter_timezone/',
  'package:shared_preferences/',
];

void main() {
  final violations = <String>[];
  _checkPackage(
    Directory('packages/plantcare_domain/lib'),
    _commonForbiddenImports,
    violations,
  );
  _checkPackage(Directory('packages/plantcare_shared/lib'), [
    ..._commonForbiddenImports,
    'package:plantcare_domain/',
  ], violations);
  _checkPackage(
    Directory('packages/plantcare_data/lib'),
    _dataForbiddenImports,
    violations,
  );
  _checkPackage(
    Directory('packages/plantcare_features/lib'),
    _presentationForbiddenImports,
    violations,
  );
  _checkWorkspaceImports(Directory.current, violations);

  if (violations.isNotEmpty) {
    stderr.writeln('Package boundary violations:');
    for (final violation in violations) {
      stderr.writeln('  $violation');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Package boundaries are valid.');
}

void _checkPackage(
  Directory directory,
  List<String> forbiddenImports,
  List<String> violations,
) {
  if (!directory.existsSync()) return;
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    _checkFile(entity, forbiddenImports, violations);
  }
}

void _checkWorkspaceImports(Directory workspace, List<String> violations) {
  for (final entity in workspace.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final normalizedPath = entity.path.replaceAll('\\', '/');
    if (normalizedPath.contains('/build/') ||
        normalizedPath.contains('/.dart_tool/')) {
      continue;
    }
    final ownPackage = RegExp(r'/(?:apps|packages)/([^/]+)/')
        .firstMatch(normalizedPath)
        ?.group(1);
    final lines = entity.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trimLeft();
      if (!line.startsWith('import ')) continue;
      if (line.contains('package:plantcare_ai/')) {
        violations.add('${entity.path}:${index + 1}: obsolete package import');
      }
      if (line.contains('/test/') || line.contains("../test/")) {
        violations.add(
          '${entity.path}:${index + 1}: cross-package test import',
        );
      }
      final imported = RegExp(r'''package:(plantcare_[^/]+)/src/''')
          .firstMatch(line)
          ?.group(1);
      if (imported != null && imported != ownPackage) {
        violations.add(
          '${entity.path}:${index + 1}: external package src import',
        );
      }
    }
    if (RegExp(r'\bCubit\s*<|extends\s+Cubit\b')
        .hasMatch(entity.readAsStringSync())) {
      violations.add('${entity.path}: Cubit usage');
    }
  }
}

void _checkFile(
  File file,
  List<String> forbiddenImports,
  List<String> violations,
) {
  final lines = file.readAsLinesSync();
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index].trimLeft();
    if (!line.startsWith('import ')) continue;
    for (final forbidden in forbiddenImports) {
      if (line.contains(forbidden)) {
        violations.add('${file.path}:${index + 1}: $forbidden');
      }
    }
  }
}
