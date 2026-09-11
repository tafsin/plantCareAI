import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:plantcare_domain/local_plant_images.dart';

import 'local_plant_image_store.dart';

typedef LocalImageRootProvider = Future<Directory> Function();
typedef LocalImageBytesWriter = Future<void> Function(
  File file,
  Uint8List bytes,
);

LocalPlantImageStore createLocalPlantImageStore() =>
    NativeLocalPlantImageStore();

final class NativeLocalPlantImageStore implements LocalPlantImageStore {
  NativeLocalPlantImageStore({
    LocalImageRootProvider? rootProvider,
    LocalImageBytesWriter? bytesWriter,
  }) : _rootProvider = rootProvider ?? getApplicationSupportDirectory,
       _bytesWriter = bytesWriter ?? _writeBytes;

  final LocalImageRootProvider _rootProvider;
  final LocalImageBytesWriter _bytesWriter;

  @override
  LocalPlantImageStorageKind get storageKind =>
      LocalPlantImageStorageKind.persistent;

  @override
  Future<void> onUserChanged(
    String? previousUserId,
    String? currentUserId,
  ) async {}

  @override
  Future<LocalPlantImage> save({
    required String userId,
    required LocalPlantImage image,
    required Uint8List bytes,
  }) async {
    validateLocalPlantImage(image);
    final directory = await _userDirectory(userId)
      ..createSync(recursive: true);
    final relativePath = '${image.id}.jpg';
    final temporary = File(_join(directory.path, '${image.id}.tmp'));
    final finalFile = File(_join(directory.path, relativePath));
    try {
      await _bytesWriter(temporary, bytes);
      await temporary.rename(finalFile.path);
      final entries = await _readIndex(directory);
      final replaced = entries
          .where(
            (entry) =>
                entry.image.purpose == image.purpose &&
                entry.image.plantId == image.plantId &&
                entry.image.observationId == image.observationId,
          )
          .toList(growable: false);
      entries.removeWhere(
        (entry) => replaced.any((old) => old.image.id == entry.image.id),
      );
      entries.add(_IndexedImage(image, relativePath));
      await _writeIndex(directory, entries);
      for (final entry in replaced) {
        await _deleteIfExists(File(_join(directory.path, entry.relativePath)));
      }
      return image;
    } catch (_) {
      await _deleteIfExists(temporary);
      await _deleteIfExists(finalFile);
      rethrow;
    }
  }

  @override
  Future<Uint8List?> read({
    required String userId,
    required String imageId,
  }) async {
    final directory = await _userDirectory(userId);
    final entries = await _readIndex(directory);
    final matches = entries.where((entry) => entry.image.id == imageId);
    if (matches.isEmpty) return null;
    final entry = matches.single;
    final file = File(_join(directory.path, entry.relativePath));
    try {
      final bytes = await file.readAsBytes();
      if (img.decodeImage(bytes) == null) throw const FormatException();
      return bytes;
    } catch (_) {
      entries.removeWhere((value) => value.image.id == imageId);
      await _deleteIfExists(file);
      await _writeIndex(directory, entries);
      return null;
    }
  }

  @override
  Future<List<LocalPlantImage>> list({
    required String userId,
    String? plantId,
    String? observationId,
    LocalPlantImagePurpose? purpose,
  }) async {
    final directory = await _userDirectory(userId);
    final entries = await _readIndex(directory);
    final valid = <LocalPlantImage>[];
    var changed = false;
    for (final entry in entries) {
      final exists = await File(_join(directory.path, entry.relativePath))
          .exists();
      if (!exists) {
        changed = true;
        continue;
      }
      if ((plantId == null || entry.image.plantId == plantId) &&
          (observationId == null ||
              entry.image.observationId == observationId) &&
          (purpose == null || entry.image.purpose == purpose)) {
        valid.add(entry.image);
      }
    }
    if (changed) {
      await _writeIndex(
        directory,
        entries
            .where(
              (entry) =>
                  File(_join(directory.path, entry.relativePath)).existsSync(),
            )
            .toList(growable: false),
      );
    }
    valid.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return valid;
  }

  @override
  Future<int> storageUsedBytes(String userId) async =>
      (await list(userId: userId))
          .fold<int>(0, (total, image) => total + image.byteSize);

  @override
  Future<void> delete({required String userId, required String imageId}) async {
    final directory = await _userDirectory(userId);
    final entries = await _readIndex(directory);
    final removed = entries
        .where((entry) => entry.image.id == imageId)
        .toList();
    entries.removeWhere((entry) => entry.image.id == imageId);
    for (final entry in removed) {
      await _deleteIfExists(File(_join(directory.path, entry.relativePath)));
    }
    if (removed.isNotEmpty) await _writeIndex(directory, entries);
  }

  @override
  Future<void> deletePlantImages({
    required String userId,
    required String plantId,
  }) async {
    final directory = await _userDirectory(userId);
    final entries = await _readIndex(directory);
    final removed = entries
        .where((entry) => entry.image.plantId == plantId)
        .toList();
    entries.removeWhere((entry) => entry.image.plantId == plantId);
    for (final entry in removed) {
      await _deleteIfExists(File(_join(directory.path, entry.relativePath)));
    }
    if (removed.isNotEmpty) await _writeIndex(directory, entries);
  }

  @override
  Future<void> deleteAll(String userId) async {
    final directory = await _userDirectory(userId);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  @override
  Future<void> cleanup(String userId) async {
    final directory = await _userDirectory(userId);
    if (!await directory.exists()) return;
    final entries = await _readIndex(directory);
    final retained = <_IndexedImage>[];
    final indexedPaths = <String>{};
    for (final entry in entries) {
      final file = File(_join(directory.path, entry.relativePath));
      try {
        final bytes = await file.readAsBytes();
        if (img.decodeImage(bytes) == null) throw const FormatException();
        retained.add(entry);
        indexedPaths.add(entry.relativePath);
      } catch (_) {
        await _deleteIfExists(file);
      }
    }
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name.endsWith('.tmp') ||
          name.endsWith('.jpg') && !indexedPaths.contains(name)) {
        await _deleteIfExists(entity);
      }
    }
    await _writeIndex(directory, retained);
  }

  Future<Directory> _userDirectory(String userId) async {
    final root = await _rootProvider();
    return Directory(
      _join(_join(root.path, 'plantcare_local_images_v1'), _namespace(userId)),
    );
  }

  Future<List<_IndexedImage>> _readIndex(Directory directory) async {
    final file = File(_join(directory.path, 'index.json'));
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic> || decoded['entries'] is! List) {
        throw const FormatException();
      }
      return (decoded['entries']! as List)
          .map((value) => _IndexedImage.fromJson(value as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await _deleteIfExists(file);
      return [];
    }
  }

  Future<void> _writeIndex(
    Directory directory,
    List<_IndexedImage> entries,
  ) async {
    await directory.create(recursive: true);
    final temporary = File(_join(directory.path, 'index.tmp'));
    final target = File(_join(directory.path, 'index.json'));
    final content = jsonEncode({
      'version': 1,
      'entries': entries.map((entry) => entry.toJson()).toList(),
    });
    await temporary.writeAsString(content, flush: true);
    await temporary.rename(target.path);
  }

  static Future<void> _writeBytes(File file, Uint8List bytes) =>
      file.writeAsBytes(bytes, flush: true);
}

final class _IndexedImage {
  const _IndexedImage(this.image, this.relativePath);

  factory _IndexedImage.fromJson(Map<String, dynamic> json) {
    final relativePath = json['relativePath'] as String;
    if (relativePath.contains('/') ||
        relativePath.contains('\\') ||
        !relativePath.endsWith('.jpg')) {
      throw const FormatException('Invalid local image path.');
    }
    final image = LocalPlantImage(
      id: json['id'] as String,
      purpose: LocalPlantImagePurposeValue.parse(json['purpose'] as String),
      plantId: json['plantId'] as String,
      observationId: json['observationId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      byteSize: json['byteSize'] as int,
    );
    validateLocalPlantImage(image);
    return _IndexedImage(image, relativePath);
  }

  final LocalPlantImage image;
  final String relativePath;

  Map<String, Object> toJson() => {
    'id': image.id,
    'purpose': image.purpose.value,
    'plantId': image.plantId,
    'observationId': ?image.observationId,
    'createdAt': image.createdAt.toUtc().toIso8601String(),
    'byteSize': image.byteSize,
    'relativePath': relativePath,
  };
}

String _namespace(String userId) {
  if (userId.isEmpty) throw const FormatException('Missing account.');
  var first = BigInt.parse('cbf29ce484222325', radix: 16);
  var second = BigInt.parse('84222325cbf29ce4', radix: 16);
  final mask = BigInt.parse('ffffffffffffffff', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  for (final value in utf8.encode(userId)) {
    first = ((first ^ BigInt.from(value)) * prime) & mask;
    second = ((second ^ BigInt.from(value)) * prime) & mask;
  }
  return 'u_${first.toRadixString(16).padLeft(16, '0')}${second.toRadixString(16).padLeft(16, '0')}';
}

String _join(String first, String second) =>
    '$first${Platform.pathSeparator}$second';

Future<void> _deleteIfExists(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
