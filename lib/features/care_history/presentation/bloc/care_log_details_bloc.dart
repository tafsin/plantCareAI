import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';
import 'package:plantcare_ai/features/care_history/domain/repositories/care_log_repository.dart';

sealed class CareLogDetailsEvent extends Equatable {
  const CareLogDetailsEvent();
  @override
  List<Object?> get props => [];
}

final class CareLogDetailsRequested extends CareLogDetailsEvent {
  const CareLogDetailsRequested();
}

final class CareLogDeleteRequested extends CareLogDetailsEvent {
  const CareLogDeleteRequested();
}

enum CareLogDetailsStatus {
  initial,
  loading,
  loaded,
  deleting,
  deleted,
  notFound,
  failure,
}

final class CareLogDetailsState extends Equatable {
  const CareLogDetailsState({
    this.status = CareLogDetailsStatus.initial,
    this.log,
    this.errorMessage,
  });
  final CareLogDetailsStatus status;
  final CareLog? log;
  final String? errorMessage;
  @override
  List<Object?> get props => [status, log, errorMessage];
}

final class CareLogDetailsBloc
    extends Bloc<CareLogDetailsEvent, CareLogDetailsState> {
  CareLogDetailsBloc(this._repository, this._plantId, this._careLogId)
    : super(const CareLogDetailsState()) {
    on<CareLogDetailsRequested>(_load);
    on<CareLogDeleteRequested>(_delete);
  }

  final CareLogRepository _repository;
  final String _plantId;
  final String _careLogId;
  bool _deleting = false;

  Future<void> _load(
    CareLogDetailsRequested event,
    Emitter<CareLogDetailsState> emit,
  ) async {
    emit(const CareLogDetailsState(status: CareLogDetailsStatus.loading));
    try {
      final log = await _repository.getById(_plantId, _careLogId);
      emit(
        log == null
            ? const CareLogDetailsState(status: CareLogDetailsStatus.notFound)
            : CareLogDetailsState(
                status: CareLogDetailsStatus.loaded,
                log: log,
              ),
      );
    } catch (error) {
      emit(
        CareLogDetailsState(
          status: CareLogDetailsStatus.failure,
          errorMessage: error is AppError
              ? error.message
              : 'Couldn\'t load this care log.',
        ),
      );
    }
  }

  Future<void> _delete(
    CareLogDeleteRequested event,
    Emitter<CareLogDetailsState> emit,
  ) async {
    final log = state.log;
    if (_deleting || log == null) return;
    _deleting = true;
    emit(CareLogDetailsState(status: CareLogDetailsStatus.deleting, log: log));
    try {
      await _repository.delete(_plantId, _careLogId);
      emit(CareLogDetailsState(status: CareLogDetailsStatus.deleted, log: log));
    } catch (error) {
      emit(
        CareLogDetailsState(
          status: CareLogDetailsStatus.failure,
          log: log,
          errorMessage: error is AppError
              ? error.message
              : 'Couldn\'t delete this care log. Try again.',
        ),
      );
    } finally {
      _deleting = false;
    }
  }
}
