import '../entities/selected_plant_image.dart';

abstract interface class PlantImageProcessor {
  Future<SelectedPlantImage> process(PickedPlantImage image);
}
