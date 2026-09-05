import '../entities/plant_observation.dart';
import '../entities/selected_plant_image.dart';

abstract interface class PlantObservationService {
  String get modelName;
  Future<PlantObservation> observe({
    required SelectedPlantImage image,
    required PlantObservationContext context,
  });
}
