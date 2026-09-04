import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/features/reminders/domain/entities/reminder.dart';
import 'package:plantcare_ai/features/reminders/domain/repositories/reminder_repository.dart';

sealed class RemindersEvent extends Equatable {
  const RemindersEvent();
  @override
  List<Object?> get props => [];
}

final class RemindersWatchRequested extends RemindersEvent {
  const RemindersWatchRequested([this.plantId]);
  final String? plantId;
  @override
  List<Object?> get props => [plantId];
}

final class RemindersChanged extends RemindersEvent {
  const RemindersChanged(this.items);
  final List<Reminder> items;
  @override
  List<Object?> get props => [items];
}

final class RemindersFailed extends RemindersEvent {
  const RemindersFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

enum RemindersStatus { initial, loading, empty, loaded, failure }

final class RemindersState extends Equatable {
  const RemindersState({
    this.status = RemindersStatus.initial,
    this.items = const [],
    this.errorMessage,
  });
  final RemindersStatus status;
  final List<Reminder> items;
  final String? errorMessage;
  Map<ReminderBucket, List<Reminder>> categorized(DateTime now) => {
    for (final bucket in ReminderBucket.values)
      bucket: items
          .where((item) => categorizeReminder(item, now) == bucket)
          .toList(),
  };
  @override
  List<Object?> get props => [status, items, errorMessage];
}

final class RemindersBloc extends Bloc<RemindersEvent, RemindersState> {
  RemindersBloc(this._repository) : super(const RemindersState()) {
    on<RemindersWatchRequested>(_watch);
    on<RemindersChanged>(_changed);
    on<RemindersFailed>(
      (event, emit) => emit(
        RemindersState(
          status: RemindersStatus.failure,
          items: state.items,
          errorMessage: event.message,
        ),
      ),
    );
  }
  final ReminderRepository _repository;
  StreamSubscription<List<Reminder>>? _subscription;
  Future<void> _watch(
    RemindersWatchRequested event,
    Emitter<RemindersState> emit,
  ) async {
    await _subscription?.cancel();
    emit(RemindersState(status: RemindersStatus.loading, items: state.items));
    final stream = event.plantId == null
        ? _repository.watchAll()
        : _repository.watchForPlant(event.plantId!);
    _subscription = stream.listen(
      (items) => add(RemindersChanged(items)),
      onError: (_) =>
          add(const RemindersFailed('Couldn’t load reminders. Try again.')),
    );
  }

  void _changed(RemindersChanged event, Emitter<RemindersState> emit) => emit(
    RemindersState(
      status: event.items.isEmpty
          ? RemindersStatus.empty
          : RemindersStatus.loaded,
      items: event.items,
    ),
  );
  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
