import 'package:plantcare_ai/core/errors/app_error.dart';

enum PlantFailureType {
  unauthenticated,
  notFound,
  permissionDenied,
  network,
  unknown,
}

final class PlantFailure extends AppError {
  const PlantFailure(this.type, super.message);

  final PlantFailureType type;

  @override
  List<Object?> get props => [type, message];
}
