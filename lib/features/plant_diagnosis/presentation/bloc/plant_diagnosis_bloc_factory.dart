import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/repositories/knowledge_repository.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/knowledge_ranker.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/plant_name_resolver.dart';
import 'package:plantcare_ai/features/plant_diagnosis/domain/repositories/plant_diagnosis_repository.dart';
import 'package:plantcare_ai/features/plant_diagnosis/domain/services/plant_diagnosis_service.dart';
import 'package:plantcare_ai/features/plant_diagnosis/presentation/bloc/diagnosis_details_bloc.dart';
import 'package:plantcare_ai/features/plant_diagnosis/presentation/bloc/diagnosis_history_bloc.dart';
import 'package:plantcare_ai/features/plant_diagnosis/presentation/bloc/plant_diagnosis_bloc.dart';

@lazySingleton
final class PlantDiagnosisBlocFactory {
  const PlantDiagnosisBlocFactory(
    this._knowledgeRepository,
    this._diagnosisRepository,
    this._service,
  );
  final KnowledgeRepository _knowledgeRepository;
  final PlantDiagnosisRepository _diagnosisRepository;
  final PlantDiagnosisService _service;

  PlantDiagnosisBloc createDiagnosisBloc() => PlantDiagnosisBloc(
    _knowledgeRepository,
    _diagnosisRepository,
    _service,
    const PlantNameResolver(),
    const KnowledgeRanker(),
  );

  DiagnosisHistoryBloc createHistoryBloc() =>
      DiagnosisHistoryBloc(_diagnosisRepository);

  DiagnosisDetailsBloc createDetailsBloc() =>
      DiagnosisDetailsBloc(_diagnosisRepository, _knowledgeRepository);
}
