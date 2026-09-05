import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/plant_identification.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_features/src/plant_identification/plant_identification_bloc.dart';

@lazySingleton
final class PlantIdentificationBlocFactory {
  const PlantIdentificationBlocFactory(
    this._picker,
    this._processor,
    this._service,
    this._repository,
  );
  final PlantImagePicker _picker;
  final PlantImageProcessor _processor;
  final PlantIdentificationService _service;
  final PlantRepository _repository;
  PlantIdentificationBloc create() =>
      PlantIdentificationBloc(_picker, _processor, _service, _repository);
}
