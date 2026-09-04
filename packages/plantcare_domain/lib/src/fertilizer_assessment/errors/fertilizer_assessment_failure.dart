import 'package:plantcare_shared/errors.dart';

enum FertilizerAssessmentFailureType {
  unauthenticated,
  plantNotFound,
  insufficientEvidence,
  malformedEvidence,
  saveFailed,
  notFound,
  network,
  unknown,
}

final class FertilizerAssessmentFailure extends AppError {
  const FertilizerAssessmentFailure(this.type, super.message);

  final FertilizerAssessmentFailureType type;

  @override
  List<Object?> get props => [type, message];
}
