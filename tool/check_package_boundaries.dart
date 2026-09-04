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
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final lines = entity.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trimLeft();
      if (!line.startsWith('import ')) continue;
      for (final forbidden in forbiddenImports) {
        if (line.contains(forbidden)) {
          violations.add('${entity.path}:${index + 1}: $forbidden');
        }
      }
    }
  }
}
