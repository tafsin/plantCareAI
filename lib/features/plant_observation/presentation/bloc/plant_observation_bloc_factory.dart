import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/observation_details_bloc.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/observation_history_bloc.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/plant_observation_bloc.dart';
import 'package:plantcare_domain/plant_observation.dart';

@lazySingleton
final class PlantObservationBlocFactory {
  const PlantObservationBlocFactory(
    this._picker,
    this._processor,
    this._service,
    this._repository,
  );

  final PlantImagePicker _picker;
  final PlantImageProcessor _processor;
  final PlantObservationService _service;
  final PlantObservationRepository _repository;

  PlantObservationBloc createObservationBloc() =>
      PlantObservationBloc(_picker, _processor, _service, _repository);

  ObservationHistoryBloc createHistoryBloc() =>
      ObservationHistoryBloc(_repository);

  ObservationDetailsBloc createDetailsBloc() =>
      ObservationDetailsBloc(_repository);
}
