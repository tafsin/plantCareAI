import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';

({WateringLog? watering, FertilizingLog? fertilizing}) latestCareLogs(
  Iterable<CareLog> logs,
) {
  WateringLog? watering;
  FertilizingLog? fertilizing;
  for (final log in logs) {
    switch (log) {
      case WateringLog():
        if (_isLater(log, watering)) watering = log;
      case FertilizingLog():
        if (_isLater(log, fertilizing)) fertilizing = log;
    }
  }
  return (watering: watering, fertilizing: fertilizing);
}

bool _isLater(CareLog candidate, CareLog? current) {
  if (current == null) return true;
  final timeComparison = candidate.occurredAt.compareTo(current.occurredAt);
  return timeComparison > 0 ||
      timeComparison == 0 && candidate.id.compareTo(current.id) > 0;
}
