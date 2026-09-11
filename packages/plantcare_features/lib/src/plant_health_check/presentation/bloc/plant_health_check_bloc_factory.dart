import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/local_plant_images.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_features/src/plant_health_check/presentation/bloc/plant_health_assessment_bloc.dart';
import 'package:plantcare_features/src/plant_health_check/presentation/bloc/plant_health_check_bloc.dart';
import 'package:plantcare_features/src/plant_health_check/presentation/bloc/plant_health_history_bloc.dart';

@lazySingleton
final class PlantHealthCheckBlocFactory {
  const PlantHealthCheckBlocFactory(
    this._picker,
    this._processor,
    this._observationService,
    this._observationRepository,
    this._knowledgeRepository,
    this._diagnosisRepository,
    this._diagnosisService,
    this._localImageRepository,
  );

  final PlantImagePicker _picker;
  final PlantImageProcessor _processor;
  final PlantObservationService _observationService;
  final PlantObservationRepository _observationRepository;
  final KnowledgeRepository _knowledgeRepository;
  final PlantDiagnosisRepository _diagnosisRepository;
  final PlantDiagnosisService _diagnosisService;
  final LocalPlantImageRepository _localImageRepository;

  PlantHealthCheckBloc createCheckBloc() => PlantHealthCheckBloc(
    _picker,
    _processor,
    _observationService,
    _observationRepository,
    _knowledgeRepository,
    _diagnosisRepository,
    _diagnosisService,
    const PlantNameResolver(),
    const KnowledgeRanker(),
    _localImageRepository,
  );

  PlantHealthHistoryBloc createHistoryBloc() =>
      PlantHealthHistoryBloc(_observationRepository, _diagnosisRepository);

  PlantHealthAssessmentBloc createAssessmentBloc() => PlantHealthAssessmentBloc(
    _observationRepository,
    _diagnosisRepository,
    _knowledgeRepository,
  );
}
