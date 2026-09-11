import 'dart:typed_data';

import 'package:plantcare_domain/local_plant_images.dart';

final class FakeLocalPlantImageRepository implements LocalPlantImageRepository {
  var cleanupCalls = 0;
  @override
  LocalPlantImageStorageKind get storageKind =>
      LocalPlantImageStorageKind.persistent;

  @override
  Future<void> cleanup() async {
    cleanupCalls++;
  }

  @override
  Future<void> delete(String imageId) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> deleteAllForUser(String userId) async {}

  @override
  Future<void> deletePlantImages(String plantId) async {}

  @override
  Future<List<LocalPlantImage>> list({
    String? plantId,
    String? observationId,
    LocalPlantImagePurpose? purpose,
  }) async => const [];

  @override
  Future<Uint8List?> read(String imageId) async => null;

  @override
  Future<LocalPlantImage> save({
    required LocalPlantImagePurpose purpose,
    required String plantId,
    required Uint8List bytes,
    required DateTime createdAt,
    String? observationId,
  }) async => LocalPlantImage(
    id: 'local-image-opaque',
    purpose: purpose,
    plantId: plantId,
    observationId: observationId,
    createdAt: createdAt,
    byteSize: bytes.length,
  );

  @override
  Future<int> storageUsedBytes() async => 0;
}
