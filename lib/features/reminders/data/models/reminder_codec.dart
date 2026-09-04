import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plantcare_ai/features/reminders/domain/entities/reminder.dart';

abstract final class ReminderCodec {
  static Map<String, Object?> toCreate(Reminder reminder) {
    return {
      'schemaVersion': ReminderLimits.schemaVersion,
      'type': reminder.type.value,
      'dueAt': Timestamp.fromDate(reminder.dueAt.toUtc()),
      'status': reminder.status.value,
      'title': reminder.title,
      'note': ?reminder.note,
      'source': reminder.source.value,
      'soilCheckId': ?reminder.soilCheckId,
      'fertilizerAssessmentId': ?reminder.fertilizerAssessmentId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Reminder fromFirestore(
    String plantId,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) throw const FormatException('Missing reminder.');
    final allowed = {
      'schemaVersion',
      'type',
      'dueAt',
      'status',
      'title',
      'note',
      'source',
      'soilCheckId',
      'fertilizerAssessmentId',
      'createdAt',
      'updatedAt',
    };
    if (data.keys.any((key) => !allowed.contains(key)) ||
        data['schemaVersion'] != ReminderLimits.schemaVersion ||
        data['dueAt'] is! Timestamp ||
        data['createdAt'] is! Timestamp ||
        data['updatedAt'] is! Timestamp ||
        data['title'] is! String) {
      throw const FormatException('Invalid reminder schema.');
    }
    final reminder = Reminder(
      id: snapshot.id,
      plantId: plantId,
      type: ReminderTypeValue.parse(data['type'] as String),
      dueAt: (data['dueAt'] as Timestamp).toDate().toUtc(),
      status: ReminderStatusValue.parse(data['status'] as String),
      title: data['title'] as String,
      note: data['note'] as String?,
      source: ReminderSourceValue.parse(data['source'] as String),
      soilCheckId: data['soilCheckId'] as String?,
      fertilizerAssessmentId: data['fertilizerAssessmentId'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
    _validateStored(reminder);
    return reminder;
  }

  static void _validateStored(Reminder reminder) {
    if (reminder.title.trim() != reminder.title ||
        reminder.title.isEmpty ||
        reminder.title.length > ReminderLimits.title ||
        (reminder.note != null &&
            (reminder.note!.trim() != reminder.note ||
                reminder.note!.isEmpty ||
                reminder.note!.length > ReminderLimits.note))) {
      throw const FormatException('Invalid reminder text.');
    }
    final valid = switch (reminder.source) {
      ReminderSource.userCreated =>
        reminder.soilCheckId == null && reminder.fertilizerAssessmentId == null,
      ReminderSource.soilCheckSuggestion =>
        reminder.type == ReminderType.soilCheck &&
            reminder.soilCheckId != null &&
            reminder.fertilizerAssessmentId == null,
      ReminderSource.fertilizerAssessmentSuggestion =>
        reminder.type == ReminderType.fertilizerReview &&
            reminder.fertilizerAssessmentId != null &&
            reminder.soilCheckId == null,
    };
    if (!valid) throw const FormatException('Invalid reminder reference.');
  }
}
