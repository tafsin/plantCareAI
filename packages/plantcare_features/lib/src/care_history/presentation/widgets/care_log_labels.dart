import 'package:plantcare_domain/care_history.dart';

extension WateringMethodLabel on WateringMethod {
  String get label => switch (this) {
    WateringMethod.top => 'Top watering',
    WateringMethod.bottom => 'Bottom watering',
    WateringMethod.soak => 'Soak',
    WateringMethod.drip => 'Drip',
    WateringMethod.other => 'Other',
  };
}

extension FertilizerFormLabel on FertilizerForm {
  String get label => switch (this) {
    FertilizerForm.liquid => 'Liquid',
    FertilizerForm.granular => 'Granular',
    FertilizerForm.slowRelease => 'Slow release',
    FertilizerForm.compost => 'Compost',
    FertilizerForm.organicOther => 'Other organic',
    FertilizerForm.other => 'Other',
  };
}

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
