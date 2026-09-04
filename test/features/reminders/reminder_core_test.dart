import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/reminders/data/models/reminder_codec.dart';
import 'package:plantcare_ai/features/reminders/data/services/local_notification_scheduler.dart';
import 'package:plantcare_ai/features/reminders/data/services/shared_preferences_notification_id_store.dart';
import 'package:plantcare_ai/features/reminders/domain/entities/reminder.dart';
import 'package:plantcare_ai/features/reminders/domain/services/notification_scheduler.dart';
import 'package:plantcare_ai/features/reminders/presentation/widgets/reminder_labels.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

Reminder reminder({
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
  title: type.label,
  source: source,
  soilCheckId: soilCheckId,
  fertilizerAssessmentId: fertilizerAssessmentId,
);

void main() {
  test('codec persists UTC timestamp and only relevant conditional fields', () {
    final data = ReminderCodec.toCreate(
      reminder(
        source: ReminderSource.soilCheckSuggestion,
        soilCheckId: 'soil-1',
      ),
    );
    expect(
      (data['dueAt']! as Timestamp).millisecondsSinceEpoch,
      DateTime.utc(2030).millisecondsSinceEpoch,
    );
    expect(data['soilCheckId'], 'soil-1');
    expect(data, isNot(contains('fertilizerAssessmentId')));
  });

  test(
    'validation rejects cross-type references and missing suggestion date',
    () {
      expect(
        () => validateReminder(
          reminder(
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
          reminder(
            source: ReminderSource.fertilizerAssessmentSuggestion,
            type: ReminderType.fertilizerReview,
          ),
          now: DateTime.utc(2029),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'categorizes overdue, today, upcoming, and history using local dates',
    () {
      final now = DateTime(2030, 1, 2, 12);
      expect(
        categorizeReminder(reminder(dueAt: DateTime(2030, 1, 1, 23)), now),
        ReminderBucket.overdue,
      );
      expect(
        categorizeReminder(reminder(dueAt: DateTime(2030, 1, 2, 23)), now),
        ReminderBucket.today,
      );
      expect(
        categorizeReminder(reminder(dueAt: DateTime(2030, 1, 3)), now),
        ReminderBucket.upcoming,
      );
      expect(
        categorizeReminder(reminder(status: ReminderStatus.completed), now),
        ReminderBucket.history,
      );
    },
  );

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

  test('zoned scheduling follows daylight-saving offset changes', () {
    tz_data.initializeTimeZones();
    final toronto = tz.getLocation('America/Toronto');
    final before = zonedReminderTime(DateTime.utc(2026, 3, 8, 6, 30), toronto);
    final after = zonedReminderTime(DateTime.utc(2026, 3, 8, 7, 30), toronto);
    expect(
      (before.hour, before.timeZoneOffset),
      (1, const Duration(hours: -5)),
    );
    expect((after.hour, after.timeZoneOffset), (3, const Duration(hours: -4)));
  });

  test('reconciliation selection excludes past and inactive reminders and deduplicates IDs', () {
    final now = DateTime.utc(2029);
    final selected = futureActiveReminders([
      reminder(),
      reminder(dueAt: DateTime.utc(2028)),
      reminder(status: ReminderStatus.completed),
      reminder(status: ReminderStatus.cancelled),
    ], now);
    expect(selected.keys, ['reminder-1']);
  });

  test(
    'clearing one user leaves another user notification mapping intact',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesNotificationIdStore();
      await store.idFor('alice', 'one');
      await store.idFor('bob', 'two');
      await store.clear('alice');
      expect(await store.entries('alice'), isEmpty);
      expect(await store.entries('bob'), contains('two'));
    },
  );
}
