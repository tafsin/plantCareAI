import 'dart:typed_data';

import 'package:plantcare_domain/local_plant_images.dart';

final class FakeLocalPlantImageRepository implements LocalPlantImageRepository {
  LocalPlantImageStorageKind kind = LocalPlantImageStorageKind.persistent;
  final Map<String, Uint8List?> bytesById = {};
  final List<LocalPlantImage> images = [];
  Object? saveError;
  Object? readError;
  Object? listError;
  Object? deleteError;
  Object? cleanupError;
  var saveCalls = 0;
  var readCalls = 0;
  var deleteCalls = 0;
  var deletePlantCalls = 0;
  var deleteAllCalls = 0;
  var cleanupCalls = 0;

  @override
  LocalPlantImageStorageKind get storageKind => kind;

  @override
  Future<LocalPlantImage> save({
    required LocalPlantImagePurpose purpose,
    required String plantId,
    required Uint8List bytes,
    required DateTime createdAt,
    String? observationId,
  }) async {
    saveCalls++;
    if (saveError case final Object error) throw error;
    images.removeWhere(
      (image) =>
          image.purpose == purpose &&
          image.plantId == plantId &&
          image.observationId == observationId,
    );
    final image = LocalPlantImage(
      id: 'local-image-$saveCalls-opaque',
      purpose: purpose,
      plantId: plantId,
      observationId: observationId,
      createdAt: createdAt,
      byteSize: bytes.length,
    );
    images.add(image);
    bytesById[image.id] = Uint8List.fromList(bytes);
    return image;
  }

  @override
  Future<Uint8List?> read(String imageId) async {
    readCalls++;
    if (readError case final Object error) throw error;
    final bytes = bytesById[imageId];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Future<List<LocalPlantImage>> list({
    String? plantId,
    String? observationId,
    LocalPlantImagePurpose? purpose,
  }) async {
    if (listError case final Object error) throw error;
    return images
        .where(
          (image) =>
              (plantId == null || image.plantId == plantId) &&
              (observationId == null || image.observationId == observationId) &&
              (purpose == null || image.purpose == purpose),
        )
        .toList(growable: false);
  }

  @override
  Future<int> storageUsedBytes() async =>
      images.fold<int>(0, (total, image) => total + image.byteSize);

  @override
  Future<void> delete(String imageId) async {
    deleteCalls++;
    if (deleteError case final Object error) throw error;
    images.removeWhere((image) => image.id == imageId);
    bytesById.remove(imageId);
  }

  @override
  Future<void> deletePlantImages(String plantId) async {
    deletePlantCalls++;
    if (deleteError case final Object error) throw error;
    final ids = images
        .where((image) => image.plantId == plantId)
        .map((image) => image.id)
        .toList();
    images.removeWhere((image) => image.plantId == plantId);
    for (final id in ids) {
      bytesById.remove(id);
    }
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCalls++;
    if (deleteError case final Object error) throw error;
    images.clear();
    bytesById.clear();
  }

  @override
  Future<void> deleteAllForUser(String userId) => deleteAll();

  @override
  Future<void> cleanup() async {
    cleanupCalls++;
    if (cleanupError case final Object error) throw error;
  }
}
