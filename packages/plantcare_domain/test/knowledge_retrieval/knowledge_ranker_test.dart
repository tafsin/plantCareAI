import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:test/test.dart';

void main() {
  const ranker = KnowledgeRanker();
  final plant = _plant();

  test('exact symptom phrase receives the strongest score', () {
    final matches = ranker.rank(
      canonicalPlantKey: 'tomato',
      plant: plant,
      observation: _observation(description: 'Lower leaf yellowing is clear.'),
      chunks: [
        _chunk(id: 'exact', keywords: ['lower_leaf_yellowing']),
        _chunk(id: 'token', keywords: ['yellow_leaf_margin']),
      ],
    );
    expect(matches.first.chunk.id, 'exact');
    expect(
      matches.first.matchedSignals,
      contains('matched symptom: lower leaf yellowing'),
    );
  });

  test('affected-part matching changes ranking', () {
    final matches = ranker.rank(
      canonicalPlantKey: 'tomato',
      plant: plant,
      observation: _observation(description: 'Brown lesions are present.'),
      chunks: [
        _chunk(id: 'stem', keywords: ['brown_lesions'], parts: ['stem']),
        _chunk(id: 'leaf', keywords: ['brown_lesions'], parts: ['leaf']),
      ],
    );
    expect(matches.first.chunk.id, 'leaf');
  });

  test('environment and growth stage contribute explicit signals', () {
    final match = ranker
        .rank(
          canonicalPlantKey: 'tomato',
          plant: plant,
          observation: _observation(description: 'Leaf yellowing is present.'),
          chunks: [
            _chunk(id: 'context', keywords: ['yellowing']),
          ],
        )
        .single;
    expect(match.matchedSignals, contains('applies outdoors'));
    expect(match.matchedSignals, contains('matches mature growth stage'));
  });

  test('tie-breaking is score, title, then document ID', () {
    final matches = ranker.rank(
      canonicalPlantKey: 'tomato',
      plant: plant,
      observation: _observation(description: 'Leaf yellowing is present.'),
      chunks: [
        _chunk(id: 'z', title: 'Beta', keywords: ['yellowing']),
        _chunk(id: 'b', title: 'Alpha', keywords: ['yellowing']),
        _chunk(id: 'a', title: 'Alpha', keywords: ['yellowing']),
      ],
    );
    expect(matches.map((item) => item.chunk.id), ['a', 'b', 'z']);
  });

  test('returns at most five results', () {
    final matches = ranker.rank(
      canonicalPlantKey: 'tomato',
      plant: plant,
      observation: _observation(description: 'Leaf yellowing is present.'),
      chunks: List.generate(
        7,
        (index) => _chunk(
          id: '$index',
          title: 'Title $index',
          keywords: ['yellowing'],
        ),
      ),
    );
    expect(matches, hasLength(5));
  });

  test('minimum threshold produces no strong match', () {
    final matches = ranker.rank(
      canonicalPlantKey: 'tomato',
      plant: plant,
      observation: _observation(description: 'A general change is visible.'),
      chunks: [
        _chunk(id: 'irrelevant', keywords: const [], parts: ['stem']),
      ],
    );
    expect(matches, isEmpty);
  });

  test('obvious substrings do not match and other plants are excluded', () {
    final matches = ranker.rank(
      canonicalPlantKey: 'tomato',
      plant: plant,
      observation: _observation(description: 'A spotted pattern is visible.'),
      chunks: [
        _chunk(id: 'substring', keywords: ['spot']),
        _chunk(id: 'wrong-plant', plantKey: 'pumpkin', keywords: ['spotted']),
      ],
    );
    expect(matches, isEmpty);
  });

  test('disease category is presented only as relevance, not diagnosis', () {
    final match = ranker
        .rank(
          canonicalPlantKey: 'tomato',
          plant: plant,
          observation: _observation(description: 'Brown lesions are visible.'),
          chunks: [
            _chunk(id: 'disease', keywords: ['brown_lesions']),
          ],
        )
        .single;
    expect(match.matchedSignals.join(' '), isNot(contains('diagnos')));
  });
}

Plant _plant() => const Plant(
  id: 'plant-1',
  commonName: 'Tomato',
  scientificName: 'Solanum lycopersicum',
  environment: PlantEnvironment.outdoor,
  growingMedium: GrowingMedium.ground,
  sunlight: Sunlight.full,
  growthStage: GrowthStage.mature,
);

PlantObservation _observation({required String description}) =>
    PlantObservation(
      schemaVersion: 1,
      plantVisible: true,
      imageQuality: const ImageQuality(usable: true, issues: []),
      possibleIdentification: const PossiblePlantIdentification(),
      affectedParts: const [AffectedPlantPart.leaf],
      observations: [
        VisibleObservation(
          type: VisualObservationType.other,
          description: description,
          confidence: 0.8,
        ),
      ],
      distribution: '',
      severity: ObservationSeverity.moderate,
      followUp: const ObservationFollowUp(anotherPhotoHelpful: false),
    );

KnowledgeChunk _chunk({
  required String id,
  String title = 'Reference',
  String plantKey = 'tomato',
  List<String> keywords = const ['yellowing'],
  List<String> parts = const ['leaf'],
}) => KnowledgeChunk(
  id: id,
  canonicalPlantKey: plantKey,
  category: 'fungal_disease',
  environment: const ['outdoor'],
  affectedParts: parts,
  growthStages: const ['mature'],
  symptomKeywords: keywords,
  title: title,
  content: 'Long enough test content for a ranked knowledge reference.',
  cautions: const [],
  sourceIds: const ['source'],
  datasetVersion: KnowledgeVersions.dataset,
);
