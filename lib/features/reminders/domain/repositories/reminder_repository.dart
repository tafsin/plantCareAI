import 'package:plantcare_ai/features/reminders/domain/entities/reminder.dart';

abstract interface class ReminderRepository {
  Stream<List<Reminder>> watchAll();
  Stream<List<Reminder>> watchForPlant(String plantId);
  Stream<Reminder?> watchOne(String plantId, String reminderId);
  Future<String> create(Reminder reminder);
  Future<void> setStatus(
    String plantId,
    String reminderId,
    ReminderStatus status, {
    DateTime? dueAt,
  });
}
