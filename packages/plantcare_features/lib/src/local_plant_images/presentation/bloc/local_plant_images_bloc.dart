import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/local_plant_images.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_shared/errors.dart';

sealed class LocalPlantImagesEvent extends Equatable {
  const LocalPlantImagesEvent();

  @override
  List<Object?> get props => [];
}

final class LocalPlantImagesRequested extends LocalPlantImagesEvent {
  const LocalPlantImagesRequested();
}

final class LocalPlantImageDeleteRequested extends LocalPlantImagesEvent {
  const LocalPlantImageDeleteRequested(this.imageId);

  final String imageId;

  @override
  List<Object?> get props => [imageId];
}

final class LocalPlantImagesDeleteAllRequested extends LocalPlantImagesEvent {
  const LocalPlantImagesDeleteAllRequested();
}

final class LocalPlantImageReplaceRequested extends LocalPlantImagesEvent {
  const LocalPlantImageReplaceRequested(this.imageId, this.source);

  final String imageId;
  final PlantImageSource source;

  @override
  List<Object?> get props => [imageId, source];
}

enum LocalPlantImagesStatus { initial, loading, empty, loaded, failure }

final class LocalPlantImageItem extends Equatable {
  const LocalPlantImageItem({required this.image, this.bytes});

  final LocalPlantImage image;
  final Uint8List? bytes;

  bool get isMissing => bytes == null;

  @override
  List<Object?> get props => [image, bytes?.length];
}

final class LocalPlantImagesState extends Equatable {
  const LocalPlantImagesState({
    this.status = LocalPlantImagesStatus.initial,
    this.items = const [],
    this.storageUsedBytes = 0,
    this.storageKind = LocalPlantImageStorageKind.persistent,
    this.busyImageIds = const {},
    this.errorMessage,
    this.actionMessage,
    this.actionRevision = 0,
  });

  final LocalPlantImagesStatus status;
  final List<LocalPlantImageItem> items;
  final int storageUsedBytes;
  final LocalPlantImageStorageKind storageKind;
  final Set<String> busyImageIds;
  final String? errorMessage;
  final String? actionMessage;
  final int actionRevision;

  bool get isSessionOnly =>
      storageKind == LocalPlantImageStorageKind.sessionOnly;

  LocalPlantImagesState copyWith({
    LocalPlantImagesStatus? status,
    List<LocalPlantImageItem>? items,
    int? storageUsedBytes,
    LocalPlantImageStorageKind? storageKind,
    Set<String>? busyImageIds,
    String? errorMessage,
    bool clearError = false,
    String? actionMessage,
    bool clearAction = false,
    int? actionRevision,
  }) => LocalPlantImagesState(
    status: status ?? this.status,
    items: items ?? this.items,
    storageUsedBytes: storageUsedBytes ?? this.storageUsedBytes,
    storageKind: storageKind ?? this.storageKind,
    busyImageIds: busyImageIds ?? this.busyImageIds,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    actionMessage: clearAction ? null : actionMessage ?? this.actionMessage,
    actionRevision: actionRevision ?? this.actionRevision,
  );

  @override
  List<Object?> get props => [
    status,
    items,
    storageUsedBytes,
    storageKind,
    busyImageIds,
    errorMessage,
    actionMessage,
    actionRevision,
  ];
}

final class LocalPlantImagesBloc
    extends Bloc<LocalPlantImagesEvent, LocalPlantImagesState> {
  LocalPlantImagesBloc(
    this._repository,
    this._picker,
    this._processor, {
    this.plantId,
    this.observationId,
    this.purpose,
  }) : super(LocalPlantImagesState(storageKind: _repository.storageKind)) {
    on<LocalPlantImagesRequested>(_load);
    on<LocalPlantImageDeleteRequested>(_delete);
    on<LocalPlantImagesDeleteAllRequested>(_deleteAll);
    on<LocalPlantImageReplaceRequested>(_replace);
  }

  final LocalPlantImageRepository _repository;
  final PlantImagePicker _picker;
  final PlantImageProcessor _processor;
  final String? plantId;
  final String? observationId;
  final LocalPlantImagePurpose? purpose;

  bool get supportsCamera => _picker.supportsCamera;

  Future<void> _load(
    LocalPlantImagesRequested event,
    Emitter<LocalPlantImagesState> emit,
  ) async {
    emit(
      state.copyWith(
        status: LocalPlantImagesStatus.loading,
        clearError: true,
        clearAction: true,
      ),
    );
    try {
      final images = await _repository.list(
        plantId: plantId,
        observationId: observationId,
        purpose: purpose,
      );
      final items = await Future.wait(
        images.map((image) async {
          try {
            return LocalPlantImageItem(
              image: image,
              bytes: await _repository.read(image.id),
            );
          } catch (_) {
            return LocalPlantImageItem(image: image);
          }
        }),
      );
      final storageUsed = await _repository.storageUsedBytes();
      emit(
        state.copyWith(
          status: items.isEmpty
              ? LocalPlantImagesStatus.empty
              : LocalPlantImagesStatus.loaded,
          items: List.unmodifiable(items),
          storageUsedBytes: storageUsed,
          clearError: true,
        ),
      );
    } on AppError catch (error) {
      emit(
        state.copyWith(
          status: LocalPlantImagesStatus.failure,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: LocalPlantImagesStatus.failure,
          errorMessage: 'Local plant images could not be loaded.',
        ),
      );
    }
  }

  Future<void> _delete(
    LocalPlantImageDeleteRequested event,
    Emitter<LocalPlantImagesState> emit,
  ) async {
    if (state.busyImageIds.contains(event.imageId)) return;
    emit(
      state.copyWith(
        busyImageIds: {...state.busyImageIds, event.imageId},
        clearAction: true,
      ),
    );
    try {
      await _repository.delete(event.imageId);
      await _refreshAfterAction(emit, 'Local image deleted.');
    } on AppError catch (error) {
      _emitActionFailure(emit, event.imageId, error.message);
    } catch (_) {
      _emitActionFailure(
        emit,
        event.imageId,
        'The local image could not be deleted.',
      );
    }
  }

  Future<void> _deleteAll(
    LocalPlantImagesDeleteAllRequested event,
    Emitter<LocalPlantImagesState> emit,
  ) async {
    if (state.busyImageIds.isNotEmpty) return;
    emit(
      state.copyWith(
        busyImageIds: state.items.map((item) => item.image.id).toSet(),
        clearAction: true,
      ),
    );
    try {
      await _repository.deleteAll();
      emit(
        state.copyWith(
          status: LocalPlantImagesStatus.empty,
          items: const [],
          storageUsedBytes: 0,
          busyImageIds: const {},
          actionMessage: 'All local plant images deleted.',
          actionRevision: state.actionRevision + 1,
        ),
      );
    } on AppError catch (error) {
      _emitActionFailure(emit, null, error.message);
    } catch (_) {
      _emitActionFailure(
        emit,
        null,
        'Local plant images could not be deleted.',
      );
    }
  }

  Future<void> _replace(
    LocalPlantImageReplaceRequested event,
    Emitter<LocalPlantImagesState> emit,
  ) async {
    if (state.busyImageIds.contains(event.imageId)) return;
    final current = state.items
        .where((item) => item.image.id == event.imageId)
        .firstOrNull;
    if (current == null) return;
    emit(
      state.copyWith(
        busyImageIds: {...state.busyImageIds, event.imageId},
        clearAction: true,
      ),
    );
    PickedPlantImage? picked;
    SelectedPlantImage? processed;
    try {
      picked = await _picker.pick(event.source);
      if (picked == null) {
        emit(
          state.copyWith(
            busyImageIds: {...state.busyImageIds}..remove(event.imageId),
          ),
        );
        return;
      }
      processed = await _processor.process(picked);
      await _repository.save(
        purpose: current.image.purpose,
        plantId: current.image.plantId,
        observationId: current.image.observationId,
        bytes: processed.bytes,
        createdAt: DateTime.now().toUtc(),
      );
      await _refreshAfterAction(emit, 'Local image replaced.');
    } on AppError catch (error) {
      _emitActionFailure(emit, event.imageId, error.message);
    } catch (_) {
      _emitActionFailure(
        emit,
        event.imageId,
        'The local image could not be replaced.',
      );
    } finally {
      picked?.bytes.fillRange(0, picked.bytes.length, 0);
      processed?.bytes.fillRange(0, processed.bytes.length, 0);
    }
  }

  Future<void> _refreshAfterAction(
    Emitter<LocalPlantImagesState> emit,
    String message,
  ) async {
    final images = await _repository.list(
      plantId: plantId,
      observationId: observationId,
      purpose: purpose,
    );
    final items = await Future.wait(
      images.map(
        (image) async => LocalPlantImageItem(
          image: image,
          bytes: await _repository.read(image.id),
        ),
      ),
    );
    emit(
      state.copyWith(
        status: items.isEmpty
            ? LocalPlantImagesStatus.empty
            : LocalPlantImagesStatus.loaded,
        items: List.unmodifiable(items),
        storageUsedBytes: await _repository.storageUsedBytes(),
        busyImageIds: const {},
        actionMessage: message,
        actionRevision: state.actionRevision + 1,
      ),
    );
  }

  void _emitActionFailure(
    Emitter<LocalPlantImagesState> emit,
    String? imageId,
    String message,
  ) {
    final busy = {...state.busyImageIds};
    if (imageId == null) {
      busy.clear();
    } else {
      busy.remove(imageId);
    }
    emit(
      state.copyWith(
        busyImageIds: busy,
        actionMessage: message,
        actionRevision: state.actionRevision + 1,
      ),
    );
  }
}
