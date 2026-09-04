import 'dart:async';

import 'package:plantcare_ai/features/plant_diagnosis/domain/entities/plant_diagnosis.dart';
import 'package:plantcare_ai/features/plant_diagnosis/domain/repositories/plant_diagnosis_repository.dart';
import 'package:plantcare_ai/features/plant_diagnosis/domain/services/plant_diagnosis_service.dart';

final class FakePlantDiagnosisService implements PlantDiagnosisService {
  PlantDiagnosis? response;
  Object? error;
  Completer<PlantDiagnosis>? completer;
  int calls = 0;
  DiagnosisRequest? request;

  @override
  String get modelName => 'gemini-3.5-flash-lite';

  @override
  Future<PlantDiagnosis> generate(DiagnosisRequest value) {
    calls++;
    request = value;
    if (error case final Object value) return Future.error(value);
    return completer?.future ?? Future.value(response!);
  }
}

final class FakePlantDiagnosisRepository implements PlantDiagnosisRepository {
  Object? saveError;
  int saveCalls = 0;
  PlantDiagnosis? saved;
  final diagnoses = StreamController<List<PlantDiagnosis>>.broadcast();
  final details = StreamController<PlantDiagnosis?>.broadcast();

  @override
  Future<String> saveDiagnosis(
    String plantId,
    String observationId,
    PlantDiagnosis diagnosis,
  ) async {
    saveCalls++;
    saved = diagnosis;
    if (saveError case final Object value) throw value;
    return 'diagnosis-1';
  }

  @override
  Stream<List<PlantDiagnosis>> watchDiagnoses(
    String plantId,
    String observationId,
  ) => diagnoses.stream;

  @override
  Stream<PlantDiagnosis?> watchDiagnosis(
    String plantId,
    String observationId,
    String diagnosisId,
  ) => details.stream;

  Future<void> close() async {
    await diagnoses.close();
    await details.close();
  }
}

const sampleDiagnosis = PlantDiagnosis(
  schemaVersion: 1,
  status: DiagnosisStatus.possibleIssuesFound,
  summary: 'The visible pattern may be consistent with a supported issue.',
  possibleIssues: [
    DiagnosisIssue(
      name: 'Leaf issue',
      likelihood: DiagnosisLikelihood.mostLikely,
      evidenceStrength: DiagnosisEvidenceStrength.moderate,
      supportingObservations: ['Yellow areas are visible on older leaves.'],
      reasoning: 'The pattern may overlap with the supplied reference.',
      evidenceChunkIds: ['tomato__fungal_disease__yellow_leaf'],
    ),
  ],
  recommendedActions: [
    DiagnosisAction(
      action: 'Monitor how the visible pattern changes.',
      priority: DiagnosisActionPriority.monitor,
      reason: 'Progression may help distinguish overlapping causes.',
      evidenceChunkIds: ['tomato__fungal_disease__yellow_leaf'],
    ),
  ],
  avoidActions: [
    DiagnosisAvoidAction(
      action: 'Do not assume one visible symptom confirms a cause.',
      reason: 'The supplied source describes overlapping causes.',
      evidenceChunkIds: ['tomato__fungal_disease__yellow_leaf'],
    ),
  ],
  uncertainties: ['The underside of the leaf was not visible.'],
  followUp: DiagnosisFollowUp(
    anotherPhotoHelpful: true,
    instruction: 'Photograph the underside of an affected leaf.',
    professionalHelpRecommended: false,
  ),
  canonicalPlantKey: 'tomato',
  evidenceChunkIds: ['tomato__fungal_disease__yellow_leaf'],
  sourceIds: ['extension_source'],
  datasetVersion: '2026-09-03-v1',
  retrievalAlgorithmVersion: 'metadata-v1',
  modelName: 'gemini-3.5-flash-lite',
);
