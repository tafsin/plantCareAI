import '../entities/selected_plant_image.dart';

abstract interface class PlantImagePicker {
  bool get supportsCamera;
  Future<PickedPlantImage?> pick(PlantImageSource source);
}
