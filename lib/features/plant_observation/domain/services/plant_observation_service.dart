import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/selected_plant_image.dart';

abstract interface class PlantObservationService {
  String get modelName;
  Future<PlantObservation> observe({
    required SelectedPlantImage image,
    required PlantObservationContext context,
  });
}
