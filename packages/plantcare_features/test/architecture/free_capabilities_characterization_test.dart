import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI, knowledge, guidance, history, care logs, and reminders have no premium gate', () {
    const unrestrictedFeatureRoots = [
      'lib/src/plant_observation',
      'lib/src/plant_diagnosis',
      'lib/src/knowledge_retrieval',
      'lib/src/soil_check',
      'lib/src/fertilizer_assessment',
      'lib/src/care_history',
      'lib/src/reminders',
    ];
    final violations = <String>[];

    for (final root in unrestrictedFeatureRoots) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        if (source.contains('premium_subscriptions') ||
            source.contains('PremiumAccess') ||
            source.contains('PlantCapabilityPolicy')) {
          violations.add(entity.path);
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'These existing capabilities must remain independent of Premium entitlement.',
    );
  });
}
