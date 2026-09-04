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
  'package:firebase_',
  'package:cloud_firestore/',
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
  _checkPresentation(Directory('lib/features'), violations);

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

void _checkPresentation(Directory features, List<String> violations) {
  for (final entity in features.listSync(recursive: true)) {
    if (entity is! File ||
        !entity.path.endsWith('.dart') ||
        !entity.path.contains('/presentation/')) {
      continue;
    }
    _checkFile(entity, _presentationForbiddenImports, violations);
  }
}

void _checkPackage(
  Directory directory,
  List<String> forbiddenImports,
  List<String> violations,
) {
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    _checkFile(entity, forbiddenImports, violations);
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
