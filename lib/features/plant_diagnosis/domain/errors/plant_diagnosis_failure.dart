import 'package:plantcare_ai/core/errors/app_error.dart';

enum PlantDiagnosisFailureType {
  unauthenticated,
  appCheckRejected,
  permissionDenied,
  unsupportedPlant,
  plantConflict,
  insufficientEvidence,
  malformedSources,
  modelUnavailable,
  retiredModel,
  quotaExceeded,
  safetyRejected,
  network,
  malformedResponse,
  unknownEvidenceReference,
  saveFailed,
  notFound,
  unknown,
}

final class PlantDiagnosisFailure extends AppError {
  const PlantDiagnosisFailure(this.type, super.message);

  final PlantDiagnosisFailureType type;

  @override
  List<Object?> get props => [type, message];
}
