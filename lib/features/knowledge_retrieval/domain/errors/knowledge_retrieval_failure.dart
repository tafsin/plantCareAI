import 'package:plantcare_ai/core/errors/app_error.dart';

enum KnowledgeRetrievalFailureType {
  unauthenticated,
  permissionDenied,
  network,
  unknown,
}

final class KnowledgeRetrievalFailure extends AppError {
  const KnowledgeRetrievalFailure(this.type, super.message);

  final KnowledgeRetrievalFailureType type;

  @override
  List<Object?> get props => [type, message];
}
