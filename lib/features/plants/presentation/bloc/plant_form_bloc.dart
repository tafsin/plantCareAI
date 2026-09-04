import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';
import 'package:plantcare_ai/features/plants/domain/repositories/plant_repository.dart';
import 'package:plantcare_ai/features/plants/domain/validation/plant_validator.dart';
import 'package:plantcare_shared/errors.dart';

sealed class PlantFormEvent extends Equatable {
  const PlantFormEvent();
  @override
  List<Object?> get props => [];
}

final class PlantFormSubmitted extends PlantFormEvent {
  const PlantFormSubmitted({required this.draft, this.plantId});
  final PlantDraft draft;
  final String? plantId;
  @override
  List<Object?> get props => [draft, plantId];
}

enum PlantFormStatus { initial, submitting, created, updated, failure }

final class PlantFormState extends Equatable {
  const PlantFormState({
    this.status = PlantFormStatus.initial,
    this.plantId,
    this.errorMessage,
  });

  final PlantFormStatus status;
  final String? plantId;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, plantId, errorMessage];
}

final class PlantFormBloc extends Bloc<PlantFormEvent, PlantFormState> {
  PlantFormBloc(this._repository) : super(const PlantFormState()) {
    on<PlantFormSubmitted>(_onSubmitted);
  }

  final PlantRepository _repository;
  var _submissionInProgress = false;

  Future<void> _onSubmitted(
    PlantFormSubmitted event,
    Emitter<PlantFormState> emit,
  ) async {
    if (_submissionInProgress) return;
    final draft = event.draft.normalized();
    final validationError = PlantValidator.draft(draft);
    if (validationError != null) {
      emit(
        PlantFormState(
          status: PlantFormStatus.failure,
          plantId: event.plantId,
          errorMessage: validationError,
        ),
      );
      return;
    }

    _submissionInProgress = true;
    emit(
      PlantFormState(
        status: PlantFormStatus.submitting,
        plantId: event.plantId,
      ),
    );
    try {
      if (event.plantId case final String plantId) {
        await _repository.updatePlant(plantId, draft);
        emit(PlantFormState(status: PlantFormStatus.updated, plantId: plantId));
      } else {
        final plantId = await _repository.addPlant(draft);
        emit(PlantFormState(status: PlantFormStatus.created, plantId: plantId));
      }
    } on AppError catch (error) {
      emit(
        PlantFormState(
          status: PlantFormStatus.failure,
          plantId: event.plantId,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        PlantFormState(
          status: PlantFormStatus.failure,
          plantId: event.plantId,
          errorMessage: 'Couldn\'t save this plant. Please try again.',
        ),
      );
    } finally {
      _submissionInProgress = false;
    }
  }
}
