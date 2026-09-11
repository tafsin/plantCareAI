import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/local_plant_images.dart';
import 'package:plantcare_domain/plant_observation.dart';

import 'local_plant_images_bloc.dart';

@lazySingleton
final class LocalPlantImagesBlocFactory {
  const LocalPlantImagesBlocFactory(
    this._repository,
    this._picker,
    this._processor,
  );

  final LocalPlantImageRepository _repository;
  final PlantImagePicker _picker;
  final PlantImageProcessor _processor;

  LocalPlantImagesBloc create({
    String? plantId,
    String? observationId,
    LocalPlantImagePurpose? purpose,
  }) => LocalPlantImagesBloc(
    _repository,
    _picker,
    _processor,
    plantId: plantId,
    observationId: observationId,
    purpose: purpose,
  );
}
