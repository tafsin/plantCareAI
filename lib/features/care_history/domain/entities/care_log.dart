import 'package:equatable/equatable.dart';

abstract final class CareLogVersions {
  static const schema = 1;
  static const source = 'user_entered';
}

enum CareLogType { watering, fertilizing }

enum WateringMethod { top, bottom, soak, drip, other }

enum FertilizerForm {
  liquid,
  granular,
  slowRelease,
  compost,
  organicOther,
  other,
}

extension WateringMethodValue on WateringMethod {
  String get value => name;

  static WateringMethod parse(String value) => switch (value) {
    'top' => WateringMethod.top,
    'bottom' => WateringMethod.bottom,
    'soak' => WateringMethod.soak,
    'drip' => WateringMethod.drip,
    'other' => WateringMethod.other,
    _ => throw const FormatException('Invalid watering method.'),
  };
}

extension FertilizerFormValue on FertilizerForm {
  String get value => switch (this) {
    FertilizerForm.slowRelease => 'slow_release',
    FertilizerForm.organicOther => 'organic_other',
    _ => name,
  };

  static FertilizerForm parse(String value) => switch (value) {
    'liquid' => FertilizerForm.liquid,
    'granular' => FertilizerForm.granular,
    'slow_release' => FertilizerForm.slowRelease,
    'compost' => FertilizerForm.compost,
    'organic_other' => FertilizerForm.organicOther,
    'other' => FertilizerForm.other,
    _ => throw const FormatException('Invalid fertilizer form.'),
  };
}

sealed class CareLog extends Equatable {
  const CareLog({
    required this.id,
    required this.occurredAt,
    this.notes,
    this.createdAt,
  });

  final String id;
  final DateTime occurredAt;
  final String? notes;
  final DateTime? createdAt;
  CareLogType get type;

  @override
  List<Object?> get props => [id, occurredAt, notes, createdAt, type];
}

final class WateringLog extends CareLog {
  const WateringLog({
    required super.id,
    required super.occurredAt,
    required this.wateringMethod,
    super.notes,
    super.createdAt,
    this.amountMl,
  });

  final WateringMethod wateringMethod;
  final double? amountMl;

  @override
  CareLogType get type => CareLogType.watering;

  @override
  List<Object?> get props => [...super.props, wateringMethod, amountMl];
}

final class FertilizingLog extends CareLog {
  const FertilizingLog({
    required super.id,
    required super.occurredAt,
    required this.fertilizerForm,
    super.notes,
    super.createdAt,
    this.productName,
    this.applicationNote,
  });

  final FertilizerForm fertilizerForm;
  final String? productName;
  final String? applicationNote;

  @override
  CareLogType get type => CareLogType.fertilizing;

  @override
  List<Object?> get props => [
    ...super.props,
    fertilizerForm,
    productName,
    applicationNote,
  ];
}
