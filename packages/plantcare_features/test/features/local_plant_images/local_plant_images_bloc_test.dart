import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/local_plant_images.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_features/local_plant_images.dart';

import '../../helpers/fake_local_plant_image_repository.dart';

void main() {
  late FakeLocalPlantImageRepository repository;
  late _Picker picker;
  late LocalPlantImagesBloc bloc;

  setUp(() {
    repository = FakeLocalPlantImageRepository();
    picker = _Picker();
    bloc = LocalPlantImagesBloc(repository, picker, const _Processor());
  });

  tearDown(() => bloc.close());

  test('loads the empty state', () async {
    bloc.add(const LocalPlantImagesRequested());

    expect(
      await bloc.stream.firstWhere(
        (state) => state.status == LocalPlantImagesStatus.empty,
      ),
      isA<LocalPlantImagesState>().having(
        (state) => state.storageUsedBytes,
        'storage used',
        0,
      ),
    );
  });

  test('reports repository load failures', () async {
    repository.listError = StateError('unavailable');
    bloc.add(const LocalPlantImagesRequested());

    final failed = await bloc.stream.firstWhere(
      (state) => state.status == LocalPlantImagesStatus.failure,
    );
    expect(failed.errorMessage, 'Local plant images could not be loaded.');
  });

  test('loads missing image safely and deletes only local data', () async {
    final image = await repository.save(
      purpose: LocalPlantImagePurpose.healthCheck,
      plantId: 'plant-1',
      observationId: 'observation-1',
      bytes: Uint8List.fromList([1, 2, 3]),
      createdAt: DateTime.utc(2026, 9, 9),
    );
    repository.bytesById[image.id] = null;
    bloc.add(const LocalPlantImagesRequested());
    final loaded = await bloc.stream.firstWhere(
      (state) => state.status == LocalPlantImagesStatus.loaded,
    );
    expect(loaded.items.single.isMissing, isTrue);
    bloc.add(LocalPlantImageDeleteRequested(image.id));
    final empty = await bloc.stream.firstWhere(
      (state) => state.status == LocalPlantImagesStatus.empty,
    );
    expect(empty.items, isEmpty);
    expect(repository.deleteCalls, 1);
  });

  test(
    'replacement preserves association and zeros temporary buffers',
    () async {
      final old = await repository.save(
        purpose: LocalPlantImagePurpose.plantIdentification,
        plantId: 'plant-1',
        bytes: Uint8List.fromList([4, 5, 6]),
        createdAt: DateTime.utc(2026, 9, 9),
      );
      bloc.add(const LocalPlantImagesRequested());
      await bloc.stream.firstWhere(
        (state) => state.status == LocalPlantImagesStatus.loaded,
      );
      bloc.add(
        LocalPlantImageReplaceRequested(old.id, PlantImageSource.gallery),
      );
      await bloc.stream.firstWhere(
        (state) => state.actionMessage == 'Local image replaced.',
      );
      expect(repository.images, hasLength(1));
      expect(repository.images.single.plantId, 'plant-1');
      expect(picker.bytes, everyElement(0));
    },
  );

  test('delete all is account-scoped through the local repository', () async {
    await repository.save(
      purpose: LocalPlantImagePurpose.plantIdentification,
      plantId: 'plant-1',
      bytes: Uint8List.fromList([1, 2, 3]),
      createdAt: DateTime.utc(2026, 9, 9),
    );
    bloc.add(const LocalPlantImagesRequested());
    await bloc.stream.firstWhere(
      (state) => state.status == LocalPlantImagesStatus.loaded,
    );
    bloc.add(const LocalPlantImagesDeleteAllRequested());
    await bloc.stream.firstWhere(
      (state) => state.status == LocalPlantImagesStatus.empty,
    );
    expect(repository.deleteAllCalls, 1);
  });

  testWidgets('shows temporary web wording and confirms delete all', (
    tester,
  ) async {
    repository.kind = LocalPlantImageStorageKind.sessionOnly;
    final image = await repository.save(
      purpose: LocalPlantImagePurpose.plantIdentification,
      plantId: 'plant-1',
      bytes: Uint8List.fromList([1, 2, 3]),
      createdAt: DateTime.utc(2026, 9, 9),
    );
    repository.bytesById[image.id] = null;
    final widgetBloc = LocalPlantImagesBloc(
      repository,
      picker,
      const _Processor(),
    )..add(const LocalPlantImagesRequested());
    addTearDown(widgetBloc.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: widgetBloc,
            child: const LocalPlantImagesPanel(
              showStorageSummary: true,
              showDeleteAll: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('browser session'), findsOneWidget);
    expect(find.textContaining('Storage used:'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('delete-all-local-images')),
      findsOneWidget,
    );
    expect(repository.deleteAllCalls, 0);
  });

  testWidgets('renders the initial loading state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: const LocalPlantImagesPanel(),
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders empty and failure states', (tester) async {
    final emptyBloc = LocalPlantImagesBloc(
      repository,
      picker,
      const _Processor(),
    )..add(const LocalPlantImagesRequested());
    addTearDown(emptyBloc.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: emptyBloc,
            child: const LocalPlantImagesPanel(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('No local plant images are stored for this view.'),
      findsOneWidget,
    );

    repository.listError = StateError('unavailable');
    final failureBloc = LocalPlantImagesBloc(
      repository,
      picker,
      const _Processor(),
    )..add(const LocalPlantImagesRequested());
    addTearDown(failureBloc.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: failureBloc,
            child: const LocalPlantImagesPanel(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Local plant images could not be loaded.'),
      findsOneWidget,
    );
  });
}

final class _Picker implements PlantImagePicker {
  final Uint8List bytes = Uint8List.fromList([7, 8, 9]);

  @override
  bool get supportsCamera => false;

  @override
  Future<PickedPlantImage?> pick(PlantImageSource source) async =>
      PickedPlantImage(bytes: bytes, filename: 'private.png');
}

final class _Processor implements PlantImageProcessor {
  const _Processor();

  @override
  Future<SelectedPlantImage> process(PickedPlantImage image) async =>
      SelectedPlantImage(
        bytes: Uint8List.fromList(image.bytes),
        mimeType: 'image/jpeg',
        filename: 'processed.jpg',
      );
}
