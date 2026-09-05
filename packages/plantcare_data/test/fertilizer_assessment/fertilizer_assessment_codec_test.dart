import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_data/src/fertilizer_assessment/models/fertilizer_assessment_codec.dart';
import 'package:plantcare_domain/fertilizer_assessment.dart';
import 'package:plantcare_domain/plants.dart';

void main() {
  test('encodes the versioned assessment schema without unrelated fields', () {
    final assessment = FertilizerAssessment(
      id: 'assessment-1',
      growthActivity: GrowthActivity.activeGrowth,
      growthStageSnapshot: GrowthStage.flowering,
      environmentSnapshot: PlantEnvironment.outdoor,
      guidance: FertilizerGuidance(
        canonicalPlantKey: 'tomato',
        outcome: FertilizerOutcome.considerFertilizing,
        fertilizerCategory: FertilizerCategory.vegetableOrTomato,
        title: 'Review fertilizer care',
        explanation: 'Use source-backed guidance.',
        cautions: const ['Follow the product label.'],
        evidenceChunkIds: const ['tomato-fertilizer-1'],
        lastFertilizedAt: DateTime.utc(2026, 8, 1),
        suggestedReviewAt: DateTime.utc(2026, 9, 10),
      ),
    );

    final data = FertilizerAssessmentCodec.toFirestore(assessment);

    expect(data['schemaVersion'], 1);
    expect(data['policyVersion'], 'deterministic-fertilizer-v1');
    expect(data['datasetVersion'], '2026-09-03-v2');
    expect(data['canonicalPlantKey'], 'tomato');
    expect(data['createdAt'], isA<FieldValue>());
    expect(data, isNot(contains('plantId')));
  });
}
