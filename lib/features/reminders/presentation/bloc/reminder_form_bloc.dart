import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/features/reminders/domain/entities/reminder.dart';
import 'package:plantcare_ai/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:plantcare_ai/features/reminders/domain/services/notification_scheduler.dart';

sealed class ReminderFormEvent extends Equatable {
  const ReminderFormEvent();
  @override
  List<Object?> get props => [];
}

final class ReminderFormSubmitted extends ReminderFormEvent {
  const ReminderFormSubmitted({
    required this.type,
    required this.dueAt,
    required this.title,
    required this.note,
    required this.permissionConfirmed,
  });
  final ReminderType type;
  final DateTime dueAt;
  final String title;
  final String note;
  final bool permissionConfirmed;
  @override
  List<Object?> get props => [type, dueAt, title, note, permissionConfirmed];
}

final class ReminderSchedulingRetried extends ReminderFormEvent {
  const ReminderSchedulingRetried();
}

enum ReminderFormStatus {
  ready,
  submitting,
  savedAndScheduled,
  savedInAppOnly,
  failure,
}

final class ReminderFormState extends Equatable {
  const ReminderFormState({
    this.status = ReminderFormStatus.ready,
    this.saved,
    this.errorMessage,
  });
  final ReminderFormStatus status;
  final Reminder? saved;
  final String? errorMessage;
  @override
  List<Object?> get props => [status, saved, errorMessage];
}

final class ReminderFormBloc
    extends Bloc<ReminderFormEvent, ReminderFormState> {
  ReminderFormBloc(
    this._repository,
    this._scheduler, {
    required this.userId,
    required this.plantId,
    required this.plantName,
    required this.source,
    this.suggestedAt,
    this.soilCheckId,
    this.fertilizerAssessmentId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const ReminderFormState()) {
    on<ReminderFormSubmitted>(_submit);
    on<ReminderSchedulingRetried>(_retry);
  }
  final ReminderRepository _repository;
  final NotificationScheduler _scheduler;
  final String userId, plantId, plantName;
  final ReminderSource source;
  final DateTime? suggestedAt;
  final String? soilCheckId, fertilizerAssessmentId;
  final DateTime Function() _now;
  bool _submitting = false;

  Future<void> _submit(
    ReminderFormSubmitted event,
    Emitter<ReminderFormState> emit,
  ) async {
    if (_submitting) return;
    _submitting = true;
    final draft = Reminder(
      id: '',
      plantId: plantId,
      type: event.type,
      dueAt: event.dueAt.toUtc(),
      status: ReminderStatus.active,
      title: event.title.trim(),
      note: event.note.trim().isEmpty ? null : event.note.trim(),
      source: source,
      soilCheckId: soilCheckId,
      fertilizerAssessmentId: fertilizerAssessmentId,
    );
    try {
      validateReminder(draft, now: _now());
      emit(
        ReminderFormState(status: ReminderFormStatus.submitting, saved: draft),
      );
      final id = await _repository.create(draft);
      final saved = Reminder(
        id: id,
        plantId: plantId,
        type: draft.type,
        dueAt: draft.dueAt,
        status: draft.status,
        title: draft.title,
        note: draft.note,
        source: source,
        soilCheckId: soilCheckId,
        fertilizerAssessmentId: fertilizerAssessmentId,
      );
      if (!_scheduler.isSupported || !event.permissionConfirmed) {
        emit(
          ReminderFormState(
            status: ReminderFormStatus.savedInAppOnly,
            saved: saved,
          ),
        );
      } else {
        final permission = await _scheduler.requestPermission();
        if (permission != NotificationPermission.granted) {
          emit(
            ReminderFormState(
              status: ReminderFormStatus.savedInAppOnly,
              saved: saved,
              errorMessage: 'Saved in PlantCare AI. Device notifications are not enabled.',
            ),
          );
        } else {
          try {
            await _scheduler.schedule(
              userId: userId,
              reminder: saved,
              plantName: plantName,
            );
            emit(
              ReminderFormState(
                status: ReminderFormStatus.savedAndScheduled,
                saved: saved,
              ),
            );
          } catch (_) {
            emit(
              ReminderFormState(
                status: ReminderFormStatus.savedInAppOnly,
                saved: saved,
                errorMessage: 'Saved in PlantCare AI, but the device notification could not be scheduled.',
              ),
            );
          }
        }
      }
    } catch (error) {
      emit(
        ReminderFormState(
          status: ReminderFormStatus.failure,
          errorMessage: error is FormatException
              ? error.message
              : 'Couldn’t save this reminder. Try again.',
        ),
      );
    } finally {
      _submitting = false;
    }
  }

  Future<void> _retry(
    ReminderSchedulingRetried event,
    Emitter<ReminderFormState> emit,
  ) async {
    final saved = state.saved;
    if (saved == null || _submitting) return;
    _submitting = true;
    emit(
      ReminderFormState(status: ReminderFormStatus.submitting, saved: saved),
    );
    try {
      if (await _scheduler.requestPermission() !=
          NotificationPermission.granted) {
        emit(
          ReminderFormState(
            status: ReminderFormStatus.savedInAppOnly,
            saved: saved,
            errorMessage: 'Device notifications remain disabled. The reminder is still saved in-app.',
          ),
        );
      } else {
        await _scheduler.schedule(
          userId: userId,
          reminder: saved,
          plantName: plantName,
        );
        emit(
          ReminderFormState(
            status: ReminderFormStatus.savedAndScheduled,
            saved: saved,
          ),
        );
      }
    } catch (_) {
      emit(
        ReminderFormState(
          status: ReminderFormStatus.savedInAppOnly,
          saved: saved,
          errorMessage: 'The device notification still could not be scheduled.',
        ),
      );
    } finally {
      _submitting = false;
    }
  }
}
