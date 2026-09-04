import 'package:plantcare_ai/core/errors/app_error.dart';

enum CareLogFailureType {
  unauthenticated,
  permissionDenied,
  network,
  malformedData,
  missingParent,
  notFound,
  unknown,
}

final class CareLogFailure extends AppError {
  const CareLogFailure(this.type, super.message);

  final CareLogFailureType type;

  @override
  List<Object?> get props => [type, message];
}
