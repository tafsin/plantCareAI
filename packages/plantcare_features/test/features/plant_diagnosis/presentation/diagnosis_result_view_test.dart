import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_features/src/plant_diagnosis/presentation/widgets/diagnosis_result_view.dart';

import '../../../helpers/fake_knowledge_repository.dart';
import '../../../helpers/fake_plant_diagnosis_dependencies.dart';

void main() {
  testWidgets('distinguishes observation, sources, inference, and safety', (
    tester,
  ) async {
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
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DiagnosisResultView(
              diagnosis: sampleDiagnosis,
              retrieval: retrieval,
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('AI-assisted, not guaranteed'), findsOneWidget);
    expect(find.text('What the image observation showed'), findsOneWidget);
    expect(find.text('What Gemini cautiously inferred'), findsOneWidget);
    expect(find.text('What the sources state'), findsOneWidget);
    expect(find.text('Recommended low-risk actions'), findsOneWidget);
    expect(find.text('Actions to avoid'), findsOneWidget);
    expect(find.textContaining('Dataset 2026-09-03-v1'), findsOneWidget);
  });
}
