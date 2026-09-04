import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';

String careDateTimeLabel(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String careDateLabel(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

String careActionTitle(CareLog log) => switch (log) {
  WateringLog() => 'Watered',
  FertilizingLog() => 'Fertilized',
};

String careMethodLabel(CareLog log) => switch (log) {
  WateringLog(:final wateringMethod) => wateringMethod.label,
  FertilizingLog(:final fertilizerForm) => fertilizerForm.label,
};
