import 'package:plantcare_shared/errors.dart';

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
