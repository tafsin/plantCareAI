import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:plantcare_data/src/local_plant_images/local_plant_image_store_io.dart';
import 'package:plantcare_data/src/local_plant_images/local_plant_image_store_web.dart';
import 'package:plantcare_data/src/local_plant_images/platform_local_plant_image_repository.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_domain/local_plant_images.dart';

void main() {
  late Directory root;
  late Uint8List jpeg;

  setUp(() {
    root = Directory.systemTemp.createTempSync('plantcare-local-images-');
    jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 20, height: 20)));
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  test(
    'native save is atomic and index contains relative safe metadata',
    () async {
      final store = NativeLocalPlantImageStore(rootProvider: () async => root);
      final image = _image(byteSize: jpeg.length);

      await store.save(userId: 'private-user', image: image, bytes: jpeg);

      final files = root.listSync(recursive: true).whereType<File>().toList();
      expect(files.where((file) => file.path.endsWith('.tmp')), isEmpty);
      expect(files.where((file) => file.path.endsWith('.jpg')), hasLength(1));
      final index = files.singleWhere(
        (file) => file.path.endsWith('index.json'),
      );
      final json = jsonDecode(index.readAsStringSync()) as Map<String, dynamic>;
      final entry = (json['entries'] as List).single as Map<String, dynamic>;
      expect(entry['relativePath'], '0123456789abcdef.jpg');
      expect(entry.toString(), isNot(contains(root.path)));
      expect(entry.toString(), isNot(contains('private-user')));
      expect(await store.storageUsedBytes('private-user'), jpeg.length);
    },
  );

  test('failed native write leaves no image or index', () async {
    final store = NativeLocalPlantImageStore(
      rootProvider: () async => root,
      bytesWriter: (_, _) async => throw const FileSystemException('failed'),
    );

    await expectLater(
      store.save(
        userId: 'user-a',
        image: _image(byteSize: jpeg.length),
        bytes: jpeg,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) => file.path.endsWith('.jpg') || file.path.endsWith('.tmp'),
          ),
      isEmpty,
    );
  });

  test('native read removes corrupt files and stale metadata', () async {
    final store = NativeLocalPlantImageStore(rootProvider: () async => root);
    final image = _image(byteSize: jpeg.length);
    await store.save(userId: 'user-a', image: image, bytes: jpeg);
    final imageFile = root
        .listSync(recursive: true)
        .whereType<File>()
        .singleWhere((file) => file.path.endsWith('.jpg'));
    await imageFile.writeAsBytes([1, 2, 3], flush: true);

    expect(await store.read(userId: 'user-a', imageId: image.id), isNull);
    expect(await store.list(userId: 'user-a'), isEmpty);
    expect(imageFile.existsSync(), isFalse);
  });

  test('native list removes missing files and delete one is safe', () async {
    final store = NativeLocalPlantImageStore(rootProvider: () async => root);
    final first = _image(byteSize: jpeg.length);
    final second = _image(
      id: 'fedcba9876543210',
      plantId: 'plant-2',
      byteSize: jpeg.length,
    );
    await store.save(userId: 'user-a', image: first, bytes: jpeg);
    await store.save(userId: 'user-a', image: second, bytes: jpeg);
    final secondFile = root
        .listSync(recursive: true)
        .whereType<File>()
        .singleWhere((file) => file.path.endsWith('${second.id}.jpg'));
    await secondFile.delete();

    expect(await store.list(userId: 'user-a'), [first]);
    await store.delete(userId: 'user-a', imageId: first.id);
    expect(await store.read(userId: 'user-a', imageId: first.id), isNull);
  });

  test('native replacement keeps only the newest associated image', () async {
    final store = NativeLocalPlantImageStore(rootProvider: () async => root);
    final first = _image(byteSize: jpeg.length);
    final replacement = _image(id: 'fedcba9876543210', byteSize: jpeg.length);
    await store.save(userId: 'user-a', image: first, bytes: jpeg);
    await store.save(userId: 'user-a', image: replacement, bytes: jpeg);

    expect(await store.list(userId: 'user-a'), [replacement]);
    expect(
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.jpg')),
      hasLength(1),
    );
  });

  test('native cleanup removes temp and unindexed image files', () async {
    final store = NativeLocalPlantImageStore(rootProvider: () async => root);
    await store.save(
      userId: 'user-a',
      image: _image(byteSize: jpeg.length),
      bytes: jpeg,
    );
    final directory = root
        .listSync(recursive: true)
        .whereType<Directory>()
        .singleWhere(
          (item) =>
              item.path.split(Platform.pathSeparator).last.startsWith('u_'),
        );
    final temporary = File(
      '${directory.path}${Platform.pathSeparator}orphan.tmp',
    );
    final orphan = File('${directory.path}${Platform.pathSeparator}orphan.jpg');
    await temporary.writeAsBytes(jpeg);
    await orphan.writeAsBytes(jpeg);

    await store.cleanup('user-a');

    expect(temporary.existsSync(), isFalse);
    expect(orphan.existsSync(), isFalse);
    expect(await store.list(userId: 'user-a'), hasLength(1));
  });

  test('native delete operations are account and plant scoped', () async {
    final store = NativeLocalPlantImageStore(rootProvider: () async => root);
    await store.save(
      userId: 'user-a',
      image: _image(byteSize: jpeg.length),
      bytes: jpeg,
    );
    await store.save(
      userId: 'user-b',
      image: _image(id: 'fedcba9876543210', byteSize: jpeg.length),
      bytes: jpeg,
    );

    await store.deletePlantImages(userId: 'user-a', plantId: 'plant-1');
    expect(await store.list(userId: 'user-a'), isEmpty);
    expect(await store.list(userId: 'user-b'), hasLength(1));
    await store.deleteAll('user-b');
    expect(await store.list(userId: 'user-b'), isEmpty);
  });

  test('session store clears signed-out user and isolates accounts', () async {
    final store = SessionLocalPlantImageStore();
    await store.save(
      userId: 'user-a',
      image: _image(byteSize: jpeg.length),
      bytes: jpeg,
    );
    expect(store.storageKind, LocalPlantImageStorageKind.sessionOnly);
    expect(await store.list(userId: 'user-b'), isEmpty);

    await store.onUserChanged('user-a', 'user-b');

    expect(await store.list(userId: 'user-a'), isEmpty);
  });

  test('session replacement and deletion remain account scoped', () async {
    final store = SessionLocalPlantImageStore();
    final first = _image(byteSize: jpeg.length);
    final replacement = _image(id: 'fedcba9876543210', byteSize: jpeg.length);
    await store.save(userId: 'user-a', image: first, bytes: jpeg);
    await store.save(userId: 'user-a', image: replacement, bytes: jpeg);
    await store.save(userId: 'user-b', image: first, bytes: jpeg);
    expect(await store.list(userId: 'user-a'), [replacement]);
    await store.delete(userId: 'user-a', imageId: replacement.id);
    expect(await store.list(userId: 'user-a'), isEmpty);
    expect(await store.list(userId: 'user-b'), [first]);
  });

  test('repository hides previous account and maps failed writes', () async {
    final session = _FakeSession(const AppUser(uid: 'user-a', email: null));
    final failingStore = NativeLocalPlantImageStore(
      rootProvider: () async => root,
      bytesWriter: (_, _) async => throw const FileSystemException('failed'),
    );
    final repository = PlatformLocalPlantImageRepository.withStore(
      session,
      failingStore,
    );

    await expectLater(
      repository.save(
        purpose: LocalPlantImagePurpose.plantIdentification,
        plantId: 'plant-1',
        bytes: jpeg,
        createdAt: DateTime.utc(2026, 9, 9),
      ),
      throwsA(
        isA<LocalPlantImageFailure>().having(
          (failure) => failure.type,
          'type',
          LocalPlantImageFailureType.writeFailed,
        ),
      ),
    );

    session.emit(null);
    await Future<void>.delayed(Duration.zero);
    expect(await repository.list(), isEmpty);
  });
}

LocalPlantImage _image({
  String id = '0123456789abcdef',
  String plantId = 'plant-1',
  int byteSize = 1,
}) => LocalPlantImage(
  id: id,
  purpose: LocalPlantImagePurpose.plantIdentification,
  plantId: plantId,
  createdAt: DateTime.utc(2026, 9, 9),
  byteSize: byteSize,
);

final class _FakeSession implements AuthenticationSession {
  _FakeSession(this._user);

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  void emit(AppUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  AppUser? get currentUser => _user;

  @override
  bool get isSignedIn => _user != null;
}
