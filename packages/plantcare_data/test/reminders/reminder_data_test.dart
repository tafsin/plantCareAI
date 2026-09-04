import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_data/src/reminders/models/reminder_codec.dart';
import 'package:plantcare_data/src/reminders/services/local_notification_scheduler.dart';
import 'package:plantcare_data/src/reminders/services/shared_preferences_notification_id_store.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

Reminder reminder({
  String id = 'reminder-1',
  String plantId = 'plant-1',
  ReminderStatus status = ReminderStatus.active,
  ReminderSource source = ReminderSource.userCreated,
  ReminderType type = ReminderType.soilCheck,
  DateTime? dueAt,
  String? soilCheckId,
  String? fertilizerAssessmentId,
}) => Reminder(
  id: id,
  plantId: plantId,
  type: type,
  dueAt: dueAt ?? DateTime.utc(2030),
  status: status,
  title: 'Check plant care',
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

  test('notification payload safely encodes route segments', () {
    final value = reminder(id: 'reminder/one', plantId: 'plant one');

    expect(
      reminderNotificationPayload(value),
      '/plants/plant%20one/reminders/reminder%2Fone',
    );
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
