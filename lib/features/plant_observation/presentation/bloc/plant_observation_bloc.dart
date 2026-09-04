import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/selected_plant_image.dart';
import 'package:plantcare_ai/features/plant_observation/domain/repositories/plant_observation_repository.dart';
import 'package:plantcare_ai/features/plant_observation/domain/services/plant_image_picker.dart';
import 'package:plantcare_ai/features/plant_observation/domain/services/plant_image_processor.dart';
import 'package:plantcare_ai/features/plant_observation/domain/services/plant_observation_service.dart';

sealed class PlantObservationEvent extends Equatable {
  const PlantObservationEvent();
  @override
  List<Object?> get props => [];
}

final class PlantObservationImageRequested extends PlantObservationEvent {
  const PlantObservationImageRequested(this.source);
  final PlantImageSource source;
  @override
  List<Object?> get props => [source];
}

final class PlantObservationImageRemoved extends PlantObservationEvent {
  const PlantObservationImageRemoved();
}

final class PlantObservationConsentChanged extends PlantObservationEvent {
  const PlantObservationConsentChanged(this.consented);
  final bool consented;
  @override
  List<Object?> get props => [consented];
}

final class PlantObservationAnalysisRequested extends PlantObservationEvent {
  const PlantObservationAnalysisRequested({
    required this.plantId,
    required this.context,
  });
  final String plantId;
  final PlantObservationContext context;
  @override
  List<Object?> get props => [plantId, context];
}

final class PlantObservationSaveRetried extends PlantObservationEvent {
  const PlantObservationSaveRetried(this.plantId);
  final String plantId;
  @override
  List<Object?> get props => [plantId];
}

enum PlantObservationStatus {
  initial,
  processingImage,
  imageSelected,
  analyzing,
  saving,
  success,
  failure,
  saveFailure,
}

final class PlantObservationState extends Equatable {
  const PlantObservationState({
    this.status = PlantObservationStatus.initial,
    this.image,
    this.consented = false,
    this.result,
    this.savedObservationId,
    this.errorMessage,
  });

  final PlantObservationStatus status;
  final SelectedPlantImage? image;
  final bool consented;
  final PlantObservation? result;
  final String? savedObservationId;
  final String? errorMessage;

  bool get canAnalyze =>
      image != null &&
      consented &&
      status != PlantObservationStatus.processingImage &&
      status != PlantObservationStatus.analyzing &&
      status != PlantObservationStatus.saving;

  bool get busy =>
      status == PlantObservationStatus.processingImage ||
      status == PlantObservationStatus.analyzing ||
      status == PlantObservationStatus.saving;

  @override
  List<Object?> get props => [
    status,
    image,
    consented,
    result,
    savedObservationId,
    errorMessage,
  ];
}

final class PlantObservationBloc
    extends Bloc<PlantObservationEvent, PlantObservationState> {
  PlantObservationBloc(
    this._picker,
    this._processor,
    this._service,
    this._repository,
  ) : super(const PlantObservationState()) {
    on<PlantObservationImageRequested>(_onImageRequested);
    on<PlantObservationImageRemoved>((event, emit) {
      if (!state.busy) emit(const PlantObservationState());
    });
    on<PlantObservationConsentChanged>((event, emit) {
      if (!state.busy && state.image != null) {
        emit(
          PlantObservationState(
            status: PlantObservationStatus.imageSelected,
            image: state.image,
            consented: event.consented,
          ),
        );
      }
    });
    on<PlantObservationAnalysisRequested>(_onAnalysisRequested);
    on<PlantObservationSaveRetried>(_onSaveRetried);
  }

  final PlantImagePicker _picker;
  final PlantImageProcessor _processor;
  final PlantObservationService _service;
  final PlantObservationRepository _repository;

  bool get supportsCamera => _picker.supportsCamera;

  Future<void> _onImageRequested(
    PlantObservationImageRequested event,
    Emitter<PlantObservationState> emit,
  ) async {
    if (state.busy) return;
    try {
      final picked = await _picker.pick(event.source);
      if (picked == null) {
        emit(const PlantObservationState());
        return;
      }
      emit(
        const PlantObservationState(
          status: PlantObservationStatus.processingImage,
        ),
      );
      final image = await _processor.process(picked);
      if (isClosed) return;
      emit(
        PlantObservationState(
          status: PlantObservationStatus.imageSelected,
          image: image,
        ),
      );
    } on AppError catch (error) {
      if (!isClosed) {
        emit(
          PlantObservationState(
            status: PlantObservationStatus.failure,
            errorMessage: error.message,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          const PlantObservationState(
            status: PlantObservationStatus.failure,
            errorMessage: 'Couldn\'t select that image. Try another photo.',
          ),
        );
      }
    }
  }

  Future<void> _onAnalysisRequested(
    PlantObservationAnalysisRequested event,
    Emitter<PlantObservationState> emit,
  ) async {
    if (state.busy) return;
    final image = state.image;
    if (image == null) {
      emit(
        const PlantObservationState(
          status: PlantObservationStatus.failure,
          errorMessage: 'Select one plant image first.',
        ),
      );
      return;
    }
    if (!state.consented) {
      emit(
        PlantObservationState(
          status: PlantObservationStatus.failure,
          image: image,
          errorMessage: 'Confirm the privacy disclosure before analyzing.',
        ),
      );
      return;
    }
    emit(
      PlantObservationState(
        status: PlantObservationStatus.analyzing,
        image: image,
        consented: true,
      ),
    );
    try {
      final result = await _service.observe(
        image: image,
        context: event.context,
      );
      if (isClosed) return;
      emit(
        PlantObservationState(
          status: PlantObservationStatus.saving,
          consented: true,
          result: result,
        ),
      );
      await _save(event.plantId, result, emit);
    } on AppError catch (error) {
      if (!isClosed) {
        emit(
          PlantObservationState(
            status: PlantObservationStatus.failure,
            image: image,
            consented: true,
            errorMessage: error.message,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          PlantObservationState(
            status: PlantObservationStatus.failure,
            image: image,
            consented: true,
            errorMessage: 'The photo could not be analyzed. Please try again.',
          ),
        );
      }
    }
  }

  Future<void> _onSaveRetried(
    PlantObservationSaveRetried event,
    Emitter<PlantObservationState> emit,
  ) async {
    if (state.busy || state.result == null) return;
    emit(
      PlantObservationState(
        status: PlantObservationStatus.saving,
        result: state.result,
        consented: state.consented,
      ),
    );
    await _save(event.plantId, state.result!, emit);
  }

  Future<void> _save(
    String plantId,
    PlantObservation result,
    Emitter<PlantObservationState> emit,
  ) async {
    try {
      final id = await _repository.saveObservation(plantId, result);
      if (!isClosed) {
        emit(
          PlantObservationState(
            status: PlantObservationStatus.success,
            result: result.copyWith(id: id, modelName: _service.modelName),
            savedObservationId: id,
          ),
        );
      }
    } on AppError catch (error) {
      if (!isClosed) {
        emit(
          PlantObservationState(
            status: PlantObservationStatus.saveFailure,
            result: result,
            errorMessage: error.message,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          PlantObservationState(
            status: PlantObservationStatus.saveFailure,
            result: result,
            errorMessage: 'The observation was created but could not be saved.',
          ),
        );
      }
    }
  }
}
