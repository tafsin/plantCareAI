import 'package:plantcare_ai/features/reminders/domain/entities/reminder.dart';

extension ReminderTypeLabel on ReminderType {
  String get label => switch (this) {
    ReminderType.soilCheck => 'Check soil moisture',
    ReminderType.fertilizerReview => 'Review fertilizer guidance',
  };
}
