import 'dart:typed_data';

import '../entities/local_plant_image.dart';

abstract interface class LocalPlantImageRepository {
  LocalPlantImageStorageKind get storageKind;

  Future<LocalPlantImage> save({
    required LocalPlantImagePurpose purpose,
    required String plantId,
    required Uint8List bytes,
    required DateTime createdAt,
    String? observationId,
  });

  Future<Uint8List?> read(String imageId);

  Future<List<LocalPlantImage>> list({
    String? plantId,
    String? observationId,
    LocalPlantImagePurpose? purpose,
  });

  Future<int> storageUsedBytes();

  Future<void> delete(String imageId);

  Future<void> deletePlantImages(String plantId);

  Future<void> deleteAll();

  Future<void> deleteAllForUser(String userId);

  Future<void> cleanup();
}
