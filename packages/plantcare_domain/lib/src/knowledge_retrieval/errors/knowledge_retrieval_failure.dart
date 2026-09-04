import 'package:plantcare_shared/errors.dart';

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
