import 'package:plantcare_shared/errors.dart';

enum LocalPlantImageFailureType {
  unauthenticated,
  invalidInput,
  writeFailed,
  readFailed,
  deleteFailed,
  cleanupFailed,
}

final class LocalPlantImageFailure extends AppError {
  const LocalPlantImageFailure(this.type, super.message);

  final LocalPlantImageFailureType type;

  @override
  List<Object?> get props => [type, message];
}
