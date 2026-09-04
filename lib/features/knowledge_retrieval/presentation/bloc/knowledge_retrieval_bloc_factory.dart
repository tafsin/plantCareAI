import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/presentation/bloc/knowledge_retrieval_bloc.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';

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
