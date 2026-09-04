import '../entities/reminder.dart';

enum NotificationPermission { unavailable, notDetermined, denied, granted }

abstract interface class NotificationScheduler {
  bool get isSupported;
  Future<void> initialize();
  Future<NotificationPermission> checkPermission();
  Future<NotificationPermission> requestPermission();
  Future<void> schedule({
    required String userId,
    required Reminder reminder,
    required String plantName,
  });
  Future<void> cancel({required String userId, required String reminderId});
  Future<void> reconcile({
    required String userId,
    required List<Reminder> reminders,
    required Map<String, String> plantNames,
    required DateTime now,
  });
  Future<void> clearUser(String userId);
  Stream<String> get notificationTapPayloads;
}

abstract interface class NotificationIdStore {
  Future<int> idFor(String userId, String reminderId);
  Future<Map<String, int>> entries(String userId);
  Future<void> remove(String userId, String reminderId);
  Future<void> clear(String userId);
}

int stableNotificationHash(String value) {
  var hash = 0x811c9dc5;
  for (final byte in value.codeUnits) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

int allocateNotificationId(
  String value,
  Set<int> used, {
  int Function(String)? hash,
}) {
  var candidate = (hash ?? stableNotificationHash)(value);
  if (candidate <= 0 || candidate > 0x7fffffff) candidate = 1;
  while (used.contains(candidate)) {
    candidate = candidate == 0x7fffffff ? 1 : candidate + 1;
  }
  return candidate;
}

Map<String, Reminder> futureActiveReminders(
  Iterable<Reminder> reminders,
  DateTime now,
) => {
  for (final reminder in reminders)
    if (reminder.status == ReminderStatus.active && reminder.dueAt.isAfter(now))
      reminder.id: reminder,
};
