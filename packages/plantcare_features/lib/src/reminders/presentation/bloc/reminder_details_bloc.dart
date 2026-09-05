import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/reminders.dart';

sealed class ReminderDetailsEvent extends Equatable {
  const ReminderDetailsEvent();
  @override
  List<Object?> get props => [];
}

final class ReminderDetailsWatchRequested extends ReminderDetailsEvent {
  const ReminderDetailsWatchRequested();
}

final class ReminderDetailsChanged extends ReminderDetailsEvent {
  const ReminderDetailsChanged(this.item);
  final Reminder? item;
  @override
  List<Object?> get props => [item];
}

final class ReminderDetailsFailed extends ReminderDetailsEvent {
  const ReminderDetailsFailed();
}

final class ReminderStatusRequested extends ReminderDetailsEvent {
  const ReminderStatusRequested(this.status, {this.dueAt});
  final ReminderStatus status;
  final DateTime? dueAt;
  @override
  List<Object?> get props => [status, dueAt];
}

final class ReminderLocalSchedulingRetried extends ReminderDetailsEvent {
  const ReminderLocalSchedulingRetried();
}

enum ReminderDetailsStatus { loading, loaded, notFound, saving, failure }

final class ReminderDetailsState extends Equatable {
  const ReminderDetailsState({
    this.status = ReminderDetailsStatus.loading,
    this.item,
    this.errorMessage,
  });
  final ReminderDetailsStatus status;
  final Reminder? item;
  final String? errorMessage;
  @override
  List<Object?> get props => [status, item, errorMessage];
}

final class ReminderDetailsBloc
    extends Bloc<ReminderDetailsEvent, ReminderDetailsState> {
  ReminderDetailsBloc(
    this._repository,
    this._scheduler, {
    required this.userId,
    required this.plantId,
    required this.reminderId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const ReminderDetailsState()) {
    on<ReminderDetailsWatchRequested>(_watch);
    on<ReminderDetailsChanged>(
      (e, emit) => emit(
        ReminderDetailsState(
          status: e.item == null
              ? ReminderDetailsStatus.notFound
              : ReminderDetailsStatus.loaded,
          item: e.item,
        ),
      ),
    );
    on<ReminderStatusRequested>(_change);
    on<ReminderLocalSchedulingRetried>(_retryScheduling);
    on<ReminderDetailsFailed>(
      (event, emit) => emit(
        const ReminderDetailsState(
          status: ReminderDetailsStatus.failure,
          errorMessage: 'Couldn’t load this reminder.',
        ),
      ),
    );
  }
  final ReminderRepository _repository;
  final NotificationScheduler _scheduler;
  final String userId, plantId, reminderId;
  final DateTime Function() _now;
  StreamSubscription<Reminder?>? _subscription;
  bool _saving = false;
  Future<void> _watch(
    ReminderDetailsWatchRequested event,
    Emitter<ReminderDetailsState> emit,
  ) async {
    await _subscription?.cancel();
    emit(const ReminderDetailsState());
    _subscription = _repository
        .watchOne(plantId, reminderId)
        .listen(
          (item) => add(ReminderDetailsChanged(item)),
          onError: (_) => add(const ReminderDetailsFailed()),
        );
  }

  Future<void> _change(
    ReminderStatusRequested event,
    Emitter<ReminderDetailsState> emit,
  ) async {
    final item = state.item;
    if (item == null || _saving) return;
    if (event.status == ReminderStatus.active &&
        (event.dueAt == null || !event.dueAt!.isAfter(_now()))) {
      emit(
        ReminderDetailsState(
          status: ReminderDetailsStatus.failure,
          item: item,
          errorMessage: 'Choose a future time to reactivate this reminder.',
        ),
      );
      return;
    }
    _saving = true;
    emit(
      ReminderDetailsState(status: ReminderDetailsStatus.saving, item: item),
    );
    try {
      await _repository.setStatus(
        plantId,
        reminderId,
        event.status,
        dueAt: event.dueAt,
      );
      if (event.status == ReminderStatus.active) {
        final updated = item.copyWith(status: event.status, dueAt: event.dueAt);
        if (await _scheduler.checkPermission() ==
            NotificationPermission.granted) {
          await _scheduler.schedule(
            userId: userId,
            reminder: updated,
            plantName: 'your plant',
          );
        }
      } else {
        await _scheduler.cancel(userId: userId, reminderId: reminderId);
      }
    } catch (_) {
      emit(
        ReminderDetailsState(
          status: ReminderDetailsStatus.failure,
          item: item,
          errorMessage: 'Couldn’t update this reminder. Try again.',
        ),
      );
    } finally {
      _saving = false;
    }
  }

  Future<void> _retryScheduling(
    ReminderLocalSchedulingRetried event,
    Emitter<ReminderDetailsState> emit,
  ) async {
    final item = state.item;
    if (item == null || item.status != ReminderStatus.active || _saving) return;
    _saving = true;
    emit(
      ReminderDetailsState(status: ReminderDetailsStatus.saving, item: item),
    );
    try {
      if (await _scheduler.requestPermission() !=
          NotificationPermission.granted) {
        emit(
          ReminderDetailsState(
            status: ReminderDetailsStatus.failure,
            item: item,
            errorMessage: 'Device notifications are disabled. The reminder remains in-app; enable notifications in system Settings.',
          ),
        );
      } else {
        await _scheduler.schedule(
          userId: userId,
          reminder: item,
          plantName: 'your plant',
        );
        emit(
          ReminderDetailsState(
            status: ReminderDetailsStatus.loaded,
            item: item,
          ),
        );
      }
    } catch (_) {
      emit(
        ReminderDetailsState(
          status: ReminderDetailsStatus.failure,
          item: item,
          errorMessage: 'The reminder is saved, but its device notification could not be scheduled.',
        ),
      );
    } finally {
      _saving = false;
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
