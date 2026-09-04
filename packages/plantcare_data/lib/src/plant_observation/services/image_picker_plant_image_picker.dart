import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/plant_observation.dart';

@LazySingleton(as: PlantImagePicker)
final class ImagePickerPlantImagePicker implements PlantImagePicker {
  ImagePickerPlantImagePicker() : _picker = ImagePicker();

  final ImagePicker _picker;

  @override
  bool get supportsCamera => !kIsWeb;

  @override
  Future<PickedPlantImage?> pick(PlantImageSource source) async {
    if (source == PlantImageSource.camera && !supportsCamera) return null;
    final file = await _picker.pickImage(
      source: source == PlantImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return PickedPlantImage(
      bytes: await file.readAsBytes(),
      filename: file.name,
    );
  }
}
