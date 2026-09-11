import 'dart:typed_data';

import 'package:plantcare_domain/local_plant_images.dart';

abstract interface class LocalPlantImageStore {
  LocalPlantImageStorageKind get storageKind;

  Future<void> onUserChanged(String? previousUserId, String? currentUserId);

  Future<LocalPlantImage> save({
    required String userId,
    required LocalPlantImage image,
    required Uint8List bytes,
  });

  Future<Uint8List?> read({required String userId, required String imageId});

  Future<List<LocalPlantImage>> list({
    required String userId,
    String? plantId,
    String? observationId,
    LocalPlantImagePurpose? purpose,
  });

  Future<int> storageUsedBytes(String userId);

  Future<void> delete({required String userId, required String imageId});

  Future<void> deletePlantImages({
    required String userId,
    required String plantId,
  });

  Future<void> deleteAll(String userId);

  Future<void> cleanup(String userId);
}
