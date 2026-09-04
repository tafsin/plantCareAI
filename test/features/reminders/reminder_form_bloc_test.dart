import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/reminders/domain/entities/reminder.dart';
import 'package:plantcare_ai/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:plantcare_ai/features/reminders/domain/services/notification_scheduler.dart';
import 'package:plantcare_ai/features/reminders/presentation/bloc/reminder_form_bloc.dart';

final class FakeRepository implements ReminderRepository {
  int creates = 0;
  final Completer<void>? gate;
  FakeRepository({this.gate});
  @override
  Future<String> create(Reminder reminder) async {
    creates++;
    await gate?.future;
    return 'saved-id';
  }

  @override
  Future<void> setStatus(
    String plantId,
    String reminderId,
    ReminderStatus status, {
    DateTime? dueAt,
  }) async {}
  @override
  Stream<List<Reminder>> watchAll() => const Stream.empty();
  @override
  Stream<List<Reminder>> watchForPlant(String plantId) => const Stream.empty();
  @override
  Stream<Reminder?> watchOne(String plantId, String reminderId) =>
      const Stream.empty();
}

final class FakeScheduler implements NotificationScheduler {
  FakeScheduler({
    this.permission = NotificationPermission.granted,
    this.throwOnSchedule = false,
    this.supported = true,
  });
  NotificationPermission permission;
  bool throwOnSchedule;
  bool supported;
  int schedules = 0;
  @override
  bool get isSupported => supported;
  @override
  Future<NotificationPermission> checkPermission() async => permission;
  @override
  Future<NotificationPermission> requestPermission() async => permission;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> schedule({
    required String userId,
    required Reminder reminder,
    required String plantName,
  }) async {
    schedules++;
    if (throwOnSchedule) throw StateError('failed');
  }

  @override
  Future<void> cancel({
    required String userId,
    required String reminderId,
  }) async {}
  @override
  Future<void> reconcile({
    required String userId,
    required List<Reminder> reminders,
    required Map<String, String> plantNames,
    required DateTime now,
  }) async {}
  @override
  Future<void> clearUser(String userId) async {}
  @override
  Stream<String> get notificationTapPayloads => const Stream.empty();
}

ReminderFormBloc makeBloc(FakeRepository repo, FakeScheduler scheduler) =>
    ReminderFormBloc(
      repo,
      scheduler,
      userId: 'alice',
      plantId: 'plant-1',
      plantName: 'Tomato',
      source: ReminderSource.userCreated,
      now: () => DateTime.utc(2029),
    );
final submit = ReminderFormSubmitted(
  type: ReminderType.soilCheck,
  dueAt: DateTime.utc(2030),
  title: 'Check soil moisture',
  note: '',
  permissionConfirmed: true,
);

void main() {
  test(
    'saves first and schedules after explicit notification confirmation',
    () async {
      final repo = FakeRepository();
      final scheduler = FakeScheduler();
      final bloc = makeBloc(repo, scheduler);
      bloc.add(submit);
      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<ReminderFormState>(
            (s) => s.status == ReminderFormStatus.savedAndScheduled,
          ),
        ),
      );
      expect(repo.creates, 1);
      expect(scheduler.schedules, 1);
      await bloc.close();
    },
  );
  test('permission denial keeps the saved in-app reminder', () async {
    final repo = FakeRepository();
    final scheduler = FakeScheduler(permission: NotificationPermission.denied);
    final bloc = makeBloc(repo, scheduler);
    bloc.add(submit);
    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<ReminderFormState>(
          (s) =>
              s.status == ReminderFormStatus.savedInAppOnly &&
              s.saved?.id == 'saved-id',
        ),
      ),
    );
    expect(repo.creates, 1);
    expect(scheduler.schedules, 0);
    await bloc.close();
  });
  test('scheduling failure keeps the saved reminder for retry', () async {
    final repo = FakeRepository();
    final scheduler = FakeScheduler(throwOnSchedule: true);
    final bloc = makeBloc(repo, scheduler);
    bloc.add(submit);
    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<ReminderFormState>(
          (s) => s.status == ReminderFormStatus.savedInAppOnly,
        ),
      ),
    );
    expect(repo.creates, 1);
    await bloc.close();
  });
  test('duplicate submissions create only one reminder', () async {
    final gate = Completer<void>();
    final repo = FakeRepository(gate: gate);
    final bloc = makeBloc(repo, FakeScheduler());
    bloc
      ..add(submit)
      ..add(submit);
    await Future<void>.delayed(Duration.zero);
    expect(repo.creates, 1);
    gate.complete();
    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<ReminderFormState>(
          (s) => s.status == ReminderFormStatus.savedAndScheduled,
        ),
      ),
    );
    await bloc.close();
  });
  test(
    'web or unchecked notification choice never schedules locally',
    () async {
      final repo = FakeRepository();
      final scheduler = FakeScheduler(supported: false);
      final bloc = makeBloc(repo, scheduler);
      bloc.add(
        ReminderFormSubmitted(
          type: ReminderType.fertilizerReview,
          dueAt: DateTime.utc(2030),
          title: 'Review fertilizer guidance',
          note: '',
          permissionConfirmed: false,
        ),
      );
      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<ReminderFormState>(
            (s) => s.status == ReminderFormStatus.savedInAppOnly,
          ),
        ),
      );
      expect(scheduler.schedules, 0);
      await bloc.close();
    },
  );
}
