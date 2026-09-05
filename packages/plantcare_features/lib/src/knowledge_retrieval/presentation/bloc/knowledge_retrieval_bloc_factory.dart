import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_features/src/knowledge_retrieval/presentation/bloc/knowledge_retrieval_bloc.dart';

@lazySingleton
final class KnowledgeRetrievalBlocFactory {
  const KnowledgeRetrievalBlocFactory(this._repository);

  final KnowledgeRepository _repository;

  KnowledgeRetrievalBloc create() => KnowledgeRetrievalBloc(
    _repository,
    const PlantNameResolver(),
    const KnowledgeRanker(),
  );
}
