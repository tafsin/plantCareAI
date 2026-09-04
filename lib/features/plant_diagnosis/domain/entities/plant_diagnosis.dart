import 'package:equatable/equatable.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';

enum DiagnosisStatus {
  healthyAppearance,
  insufficientEvidence,
  possibleIssuesFound,
}

enum DiagnosisLikelihood { mostLikely, plausibleAlternative, lessLikely }

enum DiagnosisEvidenceStrength { limited, moderate, strong }

enum DiagnosisActionPriority { now, soon, monitor }

final class DiagnosisIssue extends Equatable {
  const DiagnosisIssue({
    required this.name,
    required this.likelihood,
    required this.evidenceStrength,
    required this.supportingObservations,
    required this.reasoning,
    required this.evidenceChunkIds,
  });

  final String name;
  final DiagnosisLikelihood likelihood;
  final DiagnosisEvidenceStrength evidenceStrength;
  final List<String> supportingObservations;
  final String reasoning;
  final List<String> evidenceChunkIds;

  @override
  List<Object?> get props => [
    name,
    likelihood,
    evidenceStrength,
    supportingObservations,
    reasoning,
    evidenceChunkIds,
  ];
}

final class DiagnosisAction extends Equatable {
  const DiagnosisAction({
    required this.action,
    required this.priority,
    required this.reason,
    required this.evidenceChunkIds,
  });

  final String action;
  final DiagnosisActionPriority priority;
  final String reason;
  final List<String> evidenceChunkIds;

  @override
  List<Object?> get props => [action, priority, reason, evidenceChunkIds];
}

final class DiagnosisAvoidAction extends Equatable {
  const DiagnosisAvoidAction({
    required this.action,
    required this.reason,
    required this.evidenceChunkIds,
  });

  final String action;
  final String reason;
  final List<String> evidenceChunkIds;

  @override
  List<Object?> get props => [action, reason, evidenceChunkIds];
}

final class DiagnosisFollowUp extends Equatable {
  const DiagnosisFollowUp({
    required this.anotherPhotoHelpful,
    required this.professionalHelpRecommended,
    this.instruction,
    this.professionalHelpReason,
  });

  final bool anotherPhotoHelpful;
  final String? instruction;
  final bool professionalHelpRecommended;
  final String? professionalHelpReason;

  @override
  List<Object?> get props => [
    anotherPhotoHelpful,
    instruction,
    professionalHelpRecommended,
    professionalHelpReason,
  ];
}

final class PlantDiagnosis extends Equatable {
  const PlantDiagnosis({
    required this.schemaVersion,
    required this.status,
    required this.summary,
    required this.possibleIssues,
    required this.recommendedActions,
    required this.avoidActions,
    required this.uncertainties,
    required this.followUp,
    required this.canonicalPlantKey,
    required this.evidenceChunkIds,
    required this.sourceIds,
    required this.datasetVersion,
    required this.retrievalAlgorithmVersion,
    required this.modelName,
    this.id = '',
    this.createdAt,
  });

  static const currentSchemaVersion = 1;
  static const source = 'firebase_ai_client_grounded';

  final String id;
  final int schemaVersion;
  final DiagnosisStatus status;
  final String summary;
  final List<DiagnosisIssue> possibleIssues;
  final List<DiagnosisAction> recommendedActions;
  final List<DiagnosisAvoidAction> avoidActions;
  final List<String> uncertainties;
  final DiagnosisFollowUp followUp;
  final String canonicalPlantKey;
  final List<String> evidenceChunkIds;
  final List<String> sourceIds;
  final String datasetVersion;
  final String retrievalAlgorithmVersion;
  final String modelName;
  final DateTime? createdAt;

  PlantDiagnosis copyWith({String? id, DateTime? createdAt}) => PlantDiagnosis(
    id: id ?? this.id,
    schemaVersion: schemaVersion,
    status: status,
    summary: summary,
    possibleIssues: possibleIssues,
    recommendedActions: recommendedActions,
    avoidActions: avoidActions,
    uncertainties: uncertainties,
    followUp: followUp,
    canonicalPlantKey: canonicalPlantKey,
    evidenceChunkIds: evidenceChunkIds,
    sourceIds: sourceIds,
    datasetVersion: datasetVersion,
    retrievalAlgorithmVersion: retrievalAlgorithmVersion,
    modelName: modelName,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  List<Object?> get props => [
    id,
    schemaVersion,
    status,
    summary,
    possibleIssues,
    recommendedActions,
    avoidActions,
    uncertainties,
    followUp,
    canonicalPlantKey,
    evidenceChunkIds,
    sourceIds,
    datasetVersion,
    retrievalAlgorithmVersion,
    modelName,
    createdAt,
  ];
}

final class DiagnosisRequest extends Equatable {
  const DiagnosisRequest({
    required this.plant,
    required this.observation,
    required this.retrieval,
  });

  final Plant plant;
  final PlantObservation observation;
  final KnowledgeRetrievalResult retrieval;

  @override
  List<Object?> get props => [plant, observation, retrieval];
}
