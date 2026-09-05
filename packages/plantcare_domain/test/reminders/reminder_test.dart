import 'package:plantcare_domain/reminders.dart';
import 'package:test/test.dart';

Reminder _reminder({
  ReminderStatus status = ReminderStatus.active,
  ReminderSource source = ReminderSource.userCreated,
  ReminderType type = ReminderType.soilCheck,
  DateTime? dueAt,
  String? soilCheckId,
  String? fertilizerAssessmentId,
}) => Reminder(
  id: 'reminder-1',
  plantId: 'plant-1',
  type: type,
  dueAt: dueAt ?? DateTime.utc(2030),
  status: status,
  title: 'Check soil',
  source: source,
  soilCheckId: soilCheckId,
  fertilizerAssessmentId: fertilizerAssessmentId,
);

void main() {
  test('validation rejects cross-type and missing suggestion references', () {
    expect(
      () => validateReminder(
        _reminder(
          source: ReminderSource.soilCheckSuggestion,
          type: ReminderType.fertilizerReview,
          soilCheckId: 'soil-1',
        ),
        now: DateTime.utc(2029),
      ),
      throwsFormatException,
    );
    expect(
      () => validateReminder(
        _reminder(
          source: ReminderSource.fertilizerAssessmentSuggestion,
          type: ReminderType.fertilizerReview,
        ),
        now: DateTime.utc(2029),
      ),
      throwsFormatException,
    );
  });

  test('categorizes reminders using local dates and historical status', () {
    final now = DateTime(2030, 1, 2, 12);
    expect(
      categorizeReminder(_reminder(dueAt: DateTime(2030, 1, 1, 23)), now),
      ReminderBucket.overdue,
    );
    expect(
      categorizeReminder(_reminder(dueAt: DateTime(2030, 1, 2, 23)), now),
      ReminderBucket.today,
    );
    expect(
      categorizeReminder(_reminder(dueAt: DateTime(2030, 1, 3)), now),
      ReminderBucket.upcoming,
    );
    expect(
      categorizeReminder(_reminder(status: ReminderStatus.completed), now),
      ReminderBucket.history,
    );
  });

  test('notification IDs are stable and collision-aware', () {
    expect(
      stableNotificationHash('alice:one'),
      stableNotificationHash('alice:one'),
    );
    expect(
      stableNotificationHash('alice:one'),
      isNot(stableNotificationHash('alice:two')),
    );
    expect(allocateNotificationId('two', {7}, hash: (_) => 7), 8);
  });

  test('future-active selection excludes past and inactive reminders', () {
    final selected = futureActiveReminders([
      _reminder(),
      _reminder(dueAt: DateTime.utc(2028)),
      _reminder(status: ReminderStatus.completed),
      _reminder(status: ReminderStatus.cancelled),
    ], DateTime.utc(2029));
    expect(selected.keys, ['reminder-1']);
  });
}
