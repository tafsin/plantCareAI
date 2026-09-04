import 'package:plantcare_ai/features/plant_observation/domain/entities/selected_plant_image.dart';

abstract interface class PlantImageProcessor {
  Future<SelectedPlantImage> process(PickedPlantImage image);
}
