import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plant_observation.dart';

const sampleKnowledgeChunk = KnowledgeChunk(
  id: 'tomato__fungal_disease__yellow_leaf',
  canonicalPlantKey: 'tomato',
  category: 'fungal_disease',
  environment: ['outdoor'],
  affectedParts: ['leaf'],
  growthStages: ['mature'],
  symptomKeywords: ['yellowing'],
  title: 'Yellow leaf reference',
  content:
      'Yellowing on tomato leaves can have several overlapping causes. '
      'Compare the visible pattern, affected plant parts, growing conditions, '
      'and symptom progression before deciding what might be responsible.',
  cautions: ['A photograph alone cannot confirm a diagnosis.'],
  sourceIds: ['extension_source'],
  datasetVersion: KnowledgeVersions.dataset,
);

const sampleKnowledgeSource = KnowledgeSource(
  id: 'extension_source',
  title: 'Tomato problems',
  publisher: 'University Extension',
  url: 'https://example.edu/tomato',
  datasetVersion: KnowledgeVersions.dataset,
);

const sampleObservation = PlantObservation(
  schemaVersion: 1,
  plantVisible: true,
  imageQuality: ImageQuality(usable: true, issues: []),
  possibleIdentification: PossiblePlantIdentification(
    commonName: 'Tomato',
    scientificName: 'Solanum lycopersicum',
    confidence: 0.82,
  ),
  affectedParts: [AffectedPlantPart.leaf],
  observations: [
    VisibleObservation(
      type: VisualObservationType.yellowing,
      description: 'Yellow areas are visible between several leaf veins.',
      confidence: 0.88,
    ),
  ],
  distribution: 'Mostly visible on older lower leaves.',
  severity: ObservationSeverity.moderate,
  followUp: ObservationFollowUp(
    anotherPhotoHelpful: true,
    instruction: 'Take a clear photo of the underside of an affected leaf.',
  ),
);
