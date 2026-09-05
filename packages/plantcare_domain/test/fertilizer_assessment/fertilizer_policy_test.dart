import 'package:plantcare_domain/fertilizer_assessment.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:test/test.dart';

void main() {
  final engine = DeterministicFertilizerEngine();
  final now = DateTime.utc(2026, 9, 3);

  FertilizerGuidance assess({
    String? plant = 'tomato',
    PlantEnvironment environment = PlantEnvironment.outdoor,
    GrowthStage stage = GrowthStage.fruiting,
    GrowthActivity activity = GrowthActivity.activeGrowth,
    DateTime? last,
  }) => engine.calculate(
    FertilizerAssessmentInput(
      canonicalPlantKey: plant,
      environment: environment,
      growthStage: stage,
      growthActivity: activity,
      assessmentTime: now,
      lastFertilizedAt: last,
    ),
  );

  test('returns unsupported plant without evidence or a category', () {
    final result = assess(plant: null);
    expect(result.outcome, FertilizerOutcome.unsupportedPlant);
    expect(result.evidenceChunkIds, isEmpty);
    expect(result.fertilizerCategory, isNull);
  });

  test('active fruiting tomato may consider only its audited category', () {
    final result = assess();
    expect(result.outcome, FertilizerOutcome.considerFertilizing);
    expect(result.fertilizerCategory, FertilizerCategory.vegetableOrTomato);
    expect(result.datasetVersion, '2026-09-03-v2');
    expect(
      result.evidenceChunkIds,
      everyElement(startsWith('tomato__nutrient_guidance__')),
    );
  });

  test('stress, dormancy, and unknown activity are conservative', () {
    expect(
      assess(activity: GrowthActivity.stressedOrUnhealthy).outcome,
      FertilizerOutcome.avoidWhileStressed,
    );
    expect(
      assess(activity: GrowthActivity.slowOrDormant).outcome,
      FertilizerOutcome.wait,
    );
    expect(
      assess(activity: GrowthActivity.unknown).outcome,
      FertilizerOutcome.moreInformationNeeded,
    );
  });

  test(
    'unsupported environment and growth stage have insufficient evidence',
    () {
      expect(
        assess(environment: PlantEnvironment.indoor).outcome,
        FertilizerOutcome.insufficientEvidence,
      );
      expect(
        assess(stage: GrowthStage.seedling).outcome,
        FertilizerOutcome.insufficientEvidence,
      );
    },
  );

  test('recent repot waits indoors but is insufficient for outdoor crops', () {
    expect(
      assess(activity: GrowthActivity.recentlyRepotted).outcome,
      FertilizerOutcome.insufficientEvidence,
    );
    expect(
      assess(
        plant: 'peace_lily',
        environment: PlantEnvironment.indoor,
        stage: GrowthStage.mature,
        activity: GrowthActivity.recentlyRepotted,
      ).outcome,
      FertilizerOutcome.wait,
    );
  });

  test('missing interval history never means pothos needs fertilizer', () {
    final result = assess(
      plant: 'pothos',
      environment: PlantEnvironment.indoor,
      stage: GrowthStage.mature,
    );
    expect(result.outcome, FertilizerOutcome.moreInformationNeeded);
    expect(result.fertilizerCategory, isNull);
  });

  test('latest pothos fertilizer log controls the interval decision', () {
    final recent = assess(
      plant: 'pothos',
      environment: PlantEnvironment.indoor,
      stage: GrowthStage.mature,
      last: now.subtract(const Duration(days: 30)),
    );
    expect(recent.outcome, FertilizerOutcome.wait);
    expect(recent.suggestedReviewAt, now.add(const Duration(days: 30)));

    final old = assess(
      plant: 'pothos',
      environment: PlantEnvironment.indoor,
      stage: GrowthStage.mature,
      last: now.subtract(const Duration(days: 61)),
    );
    expect(old.outcome, FertilizerOutcome.considerFertilizing);
    expect(old.fertilizerCategory, FertilizerCategory.balancedHouseplant);
  });

  test(
    'every saved outcome includes non-dosage and non-treatment cautions',
    () {
      final result = assess();
      expect(result.cautions.join(' '), contains('not a dosage'));
      expect(result.cautions.join(' '), contains('not a treatment'));
      expect(result.cautions.join(' '), contains('product label'));
      expect(result.toString().toLowerCase(), isNot(contains('brand')));
      expect(
        result.toString().toLowerCase(),
        isNot(matches(RegExp(r'\b\d+\s*(ml|g|oz)\b'))),
      );
    },
  );

  test('same complete input produces the same result', () {
    final first = assess(
      plant: 'snake_plant',
      environment: PlantEnvironment.indoor,
      stage: GrowthStage.mature,
    );
    final second = assess(
      plant: 'snake_plant',
      environment: PlantEnvironment.indoor,
      stage: GrowthStage.mature,
    );
    expect(first, second);
  });
}
