import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/care_history.dart';
import 'package:plantcare_shared/errors.dart';

sealed class CareLogFormEvent extends Equatable {
  const CareLogFormEvent();
  @override
  List<Object?> get props => [];
}

final class CareLogFormSubmitted extends CareLogFormEvent {
  const CareLogFormSubmitted({
    required this.occurredAt,
    this.wateringMethod,
    this.fertilizerForm,
    this.amountMl,
    this.notes = '',
    this.productName = '',
    this.applicationNote = '',
  });
  final DateTime occurredAt;
  final WateringMethod? wateringMethod;
  final FertilizerForm? fertilizerForm;
  final double? amountMl;
  final String notes;
  final String productName;
  final String applicationNote;
  @override
  List<Object?> get props => [
    occurredAt,
    wateringMethod,
    fertilizerForm,
    amountMl,
    notes,
    productName,
    applicationNote,
  ];
}

enum CareLogFormStatus { ready, submitting, success, failure }

final class CareLogFormState extends Equatable {
  const CareLogFormState({
    required this.type,
    this.status = CareLogFormStatus.ready,
    this.draft,
    this.createdId,
    this.errorMessage,
  });
  final CareLogType type;
  final CareLogFormStatus status;
  final CareLog? draft;
  final String? createdId;
  final String? errorMessage;
  @override
  List<Object?> get props => [type, status, draft, createdId, errorMessage];
}

final class CareLogFormBloc extends Bloc<CareLogFormEvent, CareLogFormState> {
  CareLogFormBloc(this._repository, this._plantId, CareLogType type)
    : super(CareLogFormState(type: type)) {
    on<CareLogFormSubmitted>(_submit);
  }

  final CareLogRepository _repository;
  final String _plantId;
  bool _submitting = false;

  Future<void> _submit(
    CareLogFormSubmitted event,
    Emitter<CareLogFormState> emit,
  ) async {
    if (_submitting || state.status == CareLogFormStatus.submitting) return;
    CareLog? draft;
    try {
      draft = switch (state.type) {
        CareLogType.watering => WateringLog(
          id: '',
          occurredAt: event.occurredAt,
          wateringMethod:
              event.wateringMethod ??
              (throw const ValidationAppError('Select a watering method.')),
          amountMl: event.amountMl,
          notes: CareLogValidator.normalizedOptional(event.notes),
        ),
        CareLogType.fertilizing => FertilizingLog(
          id: '',
          occurredAt: event.occurredAt,
          fertilizerForm:
              event.fertilizerForm ??
              (throw const ValidationAppError('Select a fertilizer form.')),
          productName: CareLogValidator.normalizedOptional(event.productName),
          applicationNote: CareLogValidator.normalizedOptional(
            event.applicationNote,
          ),
          notes: CareLogValidator.normalizedOptional(event.notes),
        ),
      };
      CareLogValidator.validate(draft);
    } on AppError catch (error) {
      emit(
        CareLogFormState(
          type: state.type,
          status: CareLogFormStatus.failure,
          draft: draft,
          errorMessage: error.message,
        ),
      );
      return;
    }

    _submitting = true;
    emit(
      CareLogFormState(
        type: state.type,
        status: CareLogFormStatus.submitting,
        draft: draft,
      ),
    );
    try {
      final id = switch (draft) {
        WateringLog() => await _repository.addWatering(_plantId, draft),
        FertilizingLog() => await _repository.addFertilizing(_plantId, draft),
      };
      emit(
        CareLogFormState(
          type: state.type,
          status: CareLogFormStatus.success,
          draft: draft,
          createdId: id,
        ),
      );
    } catch (error) {
      emit(
        CareLogFormState(
          type: state.type,
          status: CareLogFormStatus.failure,
          draft: draft,
          errorMessage: error is AppError
              ? error.message
              : 'Couldn\'t save this care log. Try again.',
        ),
      );
    } finally {
      _submitting = false;
    }
  }
}
