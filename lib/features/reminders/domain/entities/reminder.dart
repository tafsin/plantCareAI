import 'package:equatable/equatable.dart';

abstract final class ReminderLimits {
  static const schemaVersion = 1;
  static const title = 120;
  static const note = 500;
}

enum ReminderType { soilCheck, fertilizerReview }

enum ReminderStatus { active, completed, cancelled }

enum ReminderSource {
  userCreated,
  soilCheckSuggestion,
  fertilizerAssessmentSuggestion,
}

extension ReminderTypeValue on ReminderType {
  String get value => switch (this) {
    ReminderType.soilCheck => 'soil_check',
    ReminderType.fertilizerReview => 'fertilizer_review',
  };
  static ReminderType parse(String value) => switch (value) {
    'soil_check' => ReminderType.soilCheck,
    'fertilizer_review' => ReminderType.fertilizerReview,
    _ => throw const FormatException('Invalid reminder type.'),
  };
}

extension ReminderStatusValue on ReminderStatus {
  String get value => name;
  static ReminderStatus parse(String value) => ReminderStatus.values.firstWhere(
    (item) => item.name == value,
    orElse: () => throw const FormatException('Invalid reminder status.'),
  );
}

extension ReminderSourceValue on ReminderSource {
  String get value => switch (this) {
    ReminderSource.userCreated => 'user_created',
    ReminderSource.soilCheckSuggestion => 'soil_check_suggestion',
    ReminderSource.fertilizerAssessmentSuggestion =>
      'fertilizer_assessment_suggestion',
  };
  static ReminderSource parse(String value) => switch (value) {
    'user_created' => ReminderSource.userCreated,
    'soil_check_suggestion' => ReminderSource.soilCheckSuggestion,
    'fertilizer_assessment_suggestion' =>
      ReminderSource.fertilizerAssessmentSuggestion,
    _ => throw const FormatException('Invalid reminder source.'),
  };
}

final class Reminder extends Equatable {
  const Reminder({
    required this.id,
    required this.plantId,
    required this.type,
    required this.dueAt,
    required this.status,
    required this.title,
    required this.source,
    this.note,
    this.soilCheckId,
    this.fertilizerAssessmentId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String plantId;
  final ReminderType type;
  final DateTime dueAt;
  final ReminderStatus status;
  final String title;
  final String? note;
  final ReminderSource source;
  final String? soilCheckId;
  final String? fertilizerAssessmentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Reminder copyWith({ReminderStatus? status, DateTime? dueAt}) => Reminder(
    id: id,
    plantId: plantId,
    type: type,
    dueAt: dueAt ?? this.dueAt,
    status: status ?? this.status,
    title: title,
    note: note,
    source: source,
    soilCheckId: soilCheckId,
    fertilizerAssessmentId: fertilizerAssessmentId,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    plantId,
    type,
    dueAt,
    status,
    title,
    note,
    source,
    soilCheckId,
    fertilizerAssessmentId,
    createdAt,
    updatedAt,
  ];
}

enum ReminderBucket { overdue, today, upcoming, history }

ReminderBucket categorizeReminder(Reminder reminder, DateTime now) {
  if (reminder.status != ReminderStatus.active) return ReminderBucket.history;
  final localDue = reminder.dueAt.toLocal();
  final localNow = now.toLocal();
  final dueDay = DateTime(localDue.year, localDue.month, localDue.day);
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  if (dueDay.isBefore(today)) return ReminderBucket.overdue;
  if (dueDay == today) return ReminderBucket.today;
  return ReminderBucket.upcoming;
}

void validateReminder(Reminder reminder, {required DateTime now}) {
  if (reminder.title.trim() != reminder.title ||
      reminder.title.isEmpty ||
      reminder.title.length > ReminderLimits.title) {
    throw const FormatException('Enter a title of 120 characters or fewer.');
  }
  if (reminder.note case final note?) {
    if (note.trim() != note ||
        note.isEmpty ||
        note.length > ReminderLimits.note) {
      throw const FormatException('Enter a note of 500 characters or fewer.');
    }
  }
  if (!reminder.dueAt.isAfter(now)) {
    throw const FormatException('Choose a future reminder time.');
  }
  final validReference = switch (reminder.source) {
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
  if (!validReference) {
    throw const FormatException('Invalid reminder reference.');
  }
}
