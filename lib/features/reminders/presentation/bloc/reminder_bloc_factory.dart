import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/features/reminders/domain/entities/reminder.dart';
import 'package:plantcare_ai/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:plantcare_ai/features/reminders/domain/services/notification_scheduler.dart';
import 'package:plantcare_ai/features/reminders/presentation/bloc/reminder_details_bloc.dart';
import 'package:plantcare_ai/features/reminders/presentation/bloc/reminder_form_bloc.dart';
import 'package:plantcare_ai/features/reminders/presentation/bloc/reminders_bloc.dart';

@lazySingleton
final class ReminderBlocFactory {
  const ReminderBlocFactory(this._repository, this._scheduler, this._auth);
  final ReminderRepository _repository;
  final NotificationScheduler _scheduler;
  final FirebaseAuth _auth;
  String get _uid =>
      _auth.currentUser?.uid ?? (throw StateError('Sign in first.'));
  RemindersBloc createListBloc() => RemindersBloc(_repository);
  ReminderFormBloc createFormBloc({
    required String plantId,
    required String plantName,
    ReminderSource source = ReminderSource.userCreated,
    DateTime? suggestedAt,
    String? soilCheckId,
    String? fertilizerAssessmentId,
  }) => ReminderFormBloc(
    _repository,
    _scheduler,
    userId: _uid,
    plantId: plantId,
    plantName: plantName,
    source: source,
    suggestedAt: suggestedAt,
    soilCheckId: soilCheckId,
    fertilizerAssessmentId: fertilizerAssessmentId,
  );
  ReminderDetailsBloc createDetailsBloc(String plantId, String reminderId) =>
      ReminderDetailsBloc(
        _repository,
        _scheduler,
        userId: _uid,
        plantId: plantId,
        reminderId: reminderId,
      );
}
