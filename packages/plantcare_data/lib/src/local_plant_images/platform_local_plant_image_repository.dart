import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_domain/local_plant_images.dart';

import 'local_plant_image_store.dart';
import 'local_plant_image_store_factory.dart';

final class PlatformLocalPlantImageRepository
    implements LocalPlantImageRepository {
  PlatformLocalPlantImageRepository(AuthenticationSession session)
    : this.withStore(session, createLocalPlantImageStore());

  PlatformLocalPlantImageRepository.withStore(this._session, this._store)
    : _activeUserId = _session.currentUser?.uid {
    _authSubscription = _session.authStateChanges.listen((user) {
      final previous = _activeUserId;
      _activeUserId = user?.uid;
      unawaited(_store.onUserChanged(previous, _activeUserId));
    });
  }

  final AuthenticationSession _session;
  final LocalPlantImageStore _store;
  late final StreamSubscription<AppUser?> _authSubscription;
  String? _activeUserId;

  @override
  LocalPlantImageStorageKind get storageKind => _store.storageKind;

  @override
  Future<LocalPlantImage> save({
    required LocalPlantImagePurpose purpose,
    required String plantId,
    required Uint8List bytes,
    required DateTime createdAt,
    String? observationId,
  }) async {
    final userId = _requiredUserId();
    final image = LocalPlantImage(
      id: _opaqueId(),
      purpose: purpose,
      plantId: plantId,
      observationId: observationId,
      createdAt: createdAt.toUtc(),
      byteSize: bytes.length,
    );
    try {
      validateLocalPlantImage(image);
      return await _store.save(userId: userId, image: image, bytes: bytes);
    } on FormatException catch (error) {
      throw LocalPlantImageFailure(
        LocalPlantImageFailureType.invalidInput,
        error.message,
      );
    } on LocalPlantImageFailure {
      rethrow;
    } catch (_) {
      throw const LocalPlantImageFailure(
        LocalPlantImageFailureType.writeFailed,
        'The plant image could not be saved on this device.',
      );
    }
  }

  @override
  Future<Uint8List?> read(String imageId) async {
    final userId = _activeUserId;
    if (userId == null || !_validId(imageId)) return null;
    try {
      return await _store.read(userId: userId, imageId: imageId);
    } catch (_) {
      throw const LocalPlantImageFailure(
        LocalPlantImageFailureType.readFailed,
        'The local plant image is unavailable.',
      );
    }
  }

  @override
  Future<List<LocalPlantImage>> list({
    String? plantId,
    String? observationId,
    LocalPlantImagePurpose? purpose,
  }) async {
    final userId = _activeUserId;
    if (userId == null) return const [];
    return _store.list(
      userId: userId,
      plantId: plantId,
      observationId: observationId,
      purpose: purpose,
    );
  }

  @override
  Future<int> storageUsedBytes() async {
    final userId = _activeUserId;
    return userId == null ? 0 : _store.storageUsedBytes(userId);
  }

  @override
  Future<void> delete(String imageId) async {
    final userId = _requiredUserId();
    if (!_validId(imageId)) return;
    try {
      await _store.delete(userId: userId, imageId: imageId);
    } catch (_) {
      throw const LocalPlantImageFailure(
        LocalPlantImageFailureType.deleteFailed,
        'The local plant image could not be deleted.',
      );
    }
  }

  @override
  Future<void> deletePlantImages(String plantId) async {
    final userId = _requiredUserId();
    if (!_validAssociationId(plantId)) return;
    try {
      await _store.deletePlantImages(userId: userId, plantId: plantId);
    } catch (_) {
      throw const LocalPlantImageFailure(
        LocalPlantImageFailureType.deleteFailed,
        'The plant\'s local images could not be deleted.',
      );
    }
  }

  @override
  Future<void> deleteAll() => deleteAllForUser(_requiredUserId());

  @override
  Future<void> deleteAllForUser(String userId) async {
    if (userId.trim().isEmpty) return;
    try {
      await _store.deleteAll(userId);
    } catch (_) {
      throw const LocalPlantImageFailure(
        LocalPlantImageFailureType.deleteFailed,
        'Local plant images could not be deleted.',
      );
    }
  }

  @override
  Future<void> cleanup() async {
    final userId = _activeUserId;
    if (userId == null) return;
    try {
      await _store.cleanup(userId);
    } catch (_) {
      throw const LocalPlantImageFailure(
        LocalPlantImageFailureType.cleanupFailed,
        'Local plant image cleanup could not be completed.',
      );
    }
  }

  String _requiredUserId() {
    final userId = _session.currentUser?.uid ?? _activeUserId;
    if (userId == null) {
      throw const LocalPlantImageFailure(
        LocalPlantImageFailureType.unauthenticated,
        'Sign in to manage local plant images.',
      );
    }
    return userId;
  }

  static String _opaqueId() {
    final random = Random.secure();
    final values = List<int>.generate(24, (_) => random.nextInt(256));
    return values
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static bool _validId(String value) =>
      value.length >= 16 && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value);

  static bool _validAssociationId(String value) =>
      value.trim() == value && value.isNotEmpty && !value.contains('/');

  Future<void> dispose() => _authSubscription.cancel();
}
