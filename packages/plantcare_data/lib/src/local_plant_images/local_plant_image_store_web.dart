import 'dart:typed_data';

import 'package:plantcare_domain/local_plant_images.dart';

import 'local_plant_image_store.dart';

LocalPlantImageStore createLocalPlantImageStore() =>
    SessionLocalPlantImageStore();

final class SessionLocalPlantImageStore implements LocalPlantImageStore {
  final Map<String, Map<String, _SessionImage>> _imagesByUser = {};

  @override
  LocalPlantImageStorageKind get storageKind =>
      LocalPlantImageStorageKind.sessionOnly;

  @override
  Future<void> onUserChanged(
    String? previousUserId,
    String? currentUserId,
  ) async {
    if (previousUserId != null && previousUserId != currentUserId) {
      _imagesByUser.remove(previousUserId);
    }
  }

  @override
  Future<LocalPlantImage> save({
    required String userId,
    required LocalPlantImage image,
    required Uint8List bytes,
  }) async {
    validateLocalPlantImage(image);
    final values = _imagesByUser.putIfAbsent(userId, () => {});
    values.removeWhere(
      (_, value) =>
          value.image.purpose == image.purpose &&
          value.image.plantId == image.plantId &&
          value.image.observationId == image.observationId,
    );
    values[image.id] = _SessionImage(image, Uint8List.fromList(bytes));
    return image;
  }

  @override
  Future<Uint8List?> read({
    required String userId,
    required String imageId,
  }) async {
    final bytes = _imagesByUser[userId]?[imageId]?.bytes;
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Future<List<LocalPlantImage>> list({
    required String userId,
    String? plantId,
    String? observationId,
    LocalPlantImagePurpose? purpose,
  }) async {
    final images =
        _imagesByUser[userId]?.values
            .map((value) => value.image)
            .where(
              (image) =>
                  (plantId == null || image.plantId == plantId) &&
                  (observationId == null ||
                      image.observationId == observationId) &&
                  (purpose == null || image.purpose == purpose),
            )
            .toList(growable: false) ??
        <LocalPlantImage>[];
    return images..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<int> storageUsedBytes(String userId) async =>
      _imagesByUser[userId]?.values.fold<int>(
        0,
        (total, value) => total + value.image.byteSize,
      ) ??
      0;

  @override
  Future<void> delete({required String userId, required String imageId}) async {
    _imagesByUser[userId]?.remove(imageId);
  }

  @override
  Future<void> deletePlantImages({
    required String userId,
    required String plantId,
  }) async {
    _imagesByUser[userId]?.removeWhere(
      (_, value) => value.image.plantId == plantId,
    );
  }

  @override
  Future<void> deleteAll(String userId) async {
    _imagesByUser.remove(userId);
  }

  @override
  Future<void> cleanup(String userId) async {}
}

final class _SessionImage {
  const _SessionImage(this.image, this.bytes);

  final LocalPlantImage image;
  final Uint8List bytes;
}
