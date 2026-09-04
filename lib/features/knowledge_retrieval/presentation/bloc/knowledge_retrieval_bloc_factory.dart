import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/repositories/knowledge_repository.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/knowledge_ranker.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/plant_name_resolver.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/presentation/bloc/knowledge_retrieval_bloc.dart';

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
