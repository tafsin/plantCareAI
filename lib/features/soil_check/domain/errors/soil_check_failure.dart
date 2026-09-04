import 'package:plantcare_ai/core/errors/app_error.dart';

enum SoilCheckFailureType {
  unauthenticated,
  plantNotFound,
  insufficientEvidence,
  malformedEvidence,
  saveFailed,
  notFound,
  network,
  unknown,
}

final class SoilCheckFailure extends AppError {
  const SoilCheckFailure(this.type, super.message);

  final SoilCheckFailureType type;

  @override
  List<Object?> get props => [type, message];
}
