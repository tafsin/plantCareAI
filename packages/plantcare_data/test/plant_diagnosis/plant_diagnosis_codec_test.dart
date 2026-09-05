import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_data/src/plant_diagnosis/models/plant_diagnosis_codec.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';

import '../helpers/diagnosis_fixtures.dart';

void main() {
  const retrieval = KnowledgeRetrievalResult(
    canonicalPlantKey: 'tomato',
    datasetVersion: KnowledgeVersions.dataset,
    algorithmVersion: KnowledgeVersions.algorithm,
    rankedMatches: [
      RankedKnowledgeMatch(
        chunk: sampleKnowledgeChunk,
        score: 20,
        matchedSignals: ['matched symptom'],
        sources: [sampleKnowledgeSource],
      ),
    ],
    warnings: [],
  );

  test('decodes valid, healthy, and insufficient structured responses', () {
    final issue = PlantDiagnosisCodec.fromAiJson(
      _validJson(),
      retrieval: retrieval,
      modelName: 'gemini-3.5-flash-lite',
    );
    expect(issue.status, DiagnosisStatus.possibleIssuesFound);
    expect(issue.evidenceChunkIds, [sampleKnowledgeChunk.id]);
    expect(issue.sourceIds, [sampleKnowledgeSource.id]);

    for (final status in ['healthy_appearance', 'insufficient_evidence']) {
      final json = _validJson()
        ..['status'] = status
        ..['possibleIssues'] = <Object>[];
      final decoded = PlantDiagnosisCodec.fromAiJson(
        json,
        retrieval: retrieval,
        modelName: 'gemini-3.5-flash-lite',
      );
      expect(decoded.possibleIssues, isEmpty);
    }
  });

  test('rejects unknown fields, enums, evidence ids, markup, and excess', () {
    final cases = <Map<String, dynamic>>[
      _validJson()..['unexpected'] = true,
      _validJson()..['status'] = 'confirmed',
      _validJson()
        ..['possibleIssues'] = [
          ...(_validJson()['possibleIssues']! as List),
          ...List.filled(3, (_validJson()['possibleIssues']! as List).first),
        ],
      _validJson()..['summary'] = '<b>This may match.</b>',
      _validJson()
        ..['recommendedActions'] = [
          {
            ...((_validJson()['recommendedActions']! as List).first as Map),
            'evidenceChunkIds': ['unknown'],
          },
        ],
    ];
    for (final json in cases) {
      expect(
        () => PlantDiagnosisCodec.fromAiJson(
          json,
          retrieval: retrieval,
          modelName: 'gemini-3.5-flash-lite',
        ),
        throwsFormatException,
      );
    }
  });
}

Map<String, dynamic> _validJson() => {
  'schemaVersion': 1,
  'status': 'possible_issues_found',
  'summary': 'The visible pattern may be consistent with a supported issue.',
  'possibleIssues': [
    {
      'name': 'Leaf issue',
      'likelihood': 'most_likely',
      'evidenceStrength': 'moderate',
      'supportingObservations': ['Yellow areas are visible.'],
      'reasoning': 'The pattern may overlap with the supplied reference.',
      'evidenceChunkIds': [sampleKnowledgeChunk.id],
    },
  ],
  'recommendedActions': [
    {
      'action': 'Monitor visible changes.',
      'priority': 'monitor',
      'reason': 'Progression can add useful evidence.',
      'evidenceChunkIds': [sampleKnowledgeChunk.id],
    },
  ],
  'avoidActions': [
    {
      'action': 'Do not assume the cause.',
      'reason': 'Several causes can overlap.',
      'evidenceChunkIds': [sampleKnowledgeChunk.id],
    },
  ],
  'uncertainties': ['The underside was not visible.'],
  'followUp': {
    'anotherPhotoHelpful': true,
    'instruction': 'Photograph the underside of the leaf.',
    'professionalHelpRecommended': false,
    'professionalHelpReason': null,
  },
};
