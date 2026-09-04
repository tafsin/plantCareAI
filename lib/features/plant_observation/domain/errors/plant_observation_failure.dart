import 'package:plantcare_ai/core/errors/app_error.dart';

enum PlantObservationFailureType {
  noImage,
  unsupportedFormat,
  imageTooLarge,
  imageProcessing,
  aiUnavailable,
  appCheckRejected,
  permissionDenied,
  modelUnavailable,
  retiredModel,
  quotaExceeded,
  safetyRejected,
  network,
  malformedResponse,
  unauthenticated,
  plantNotFound,
  saveFailed,
  unknown,
}

final class PlantObservationFailure extends AppError {
  const PlantObservationFailure(this.type, super.message);

  final PlantObservationFailureType type;

  @override
  List<Object?> get props => [type, message];
}
