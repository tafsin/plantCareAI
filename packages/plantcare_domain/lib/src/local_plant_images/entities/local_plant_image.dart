import 'package:equatable/equatable.dart';

enum LocalPlantImagePurpose { plantIdentification, healthCheck }

enum LocalPlantImageStorageKind { persistent, sessionOnly }

extension LocalPlantImagePurposeValue on LocalPlantImagePurpose {
  String get value => switch (this) {
    LocalPlantImagePurpose.plantIdentification => 'plant_identification',
    LocalPlantImagePurpose.healthCheck => 'health_check',
  };

  static LocalPlantImagePurpose parse(String value) => switch (value) {
    'plant_identification' => LocalPlantImagePurpose.plantIdentification,
    'health_check' => LocalPlantImagePurpose.healthCheck,
    _ => throw const FormatException('Invalid local plant image purpose.'),
  };
}

final class LocalPlantImage extends Equatable {
  const LocalPlantImage({
    required this.id,
    required this.purpose,
    required this.plantId,
    required this.createdAt,
    required this.byteSize,
    this.observationId,
  });

  final String id;
  final LocalPlantImagePurpose purpose;
  final String plantId;
  final String? observationId;
  final DateTime createdAt;
  final int byteSize;

  @override
  List<Object?> get props => [
    id,
    purpose,
    plantId,
    observationId,
    createdAt,
    byteSize,
  ];
}

void validateLocalPlantImage(LocalPlantImage image) {
  if (!_validOpaqueId(image.id) || !_validAssociationId(image.plantId)) {
    throw const FormatException('Invalid local plant image identifier.');
  }
  if (image.byteSize <= 0) {
    throw const FormatException('Local plant image size must be positive.');
  }
  switch (image.purpose) {
    case LocalPlantImagePurpose.plantIdentification:
      if (image.observationId != null) {
        throw const FormatException(
          'Plant identification images cannot reference an observation.',
        );
      }
    case LocalPlantImagePurpose.healthCheck:
      if (!_validAssociationId(image.observationId ?? '')) {
        throw const FormatException(
          'Health-check images require a valid observation.',
        );
      }
  }
}

bool _validOpaqueId(String value) =>
    value.length >= 16 &&
    value.length <= 96 &&
    RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value);

bool _validAssociationId(String value) =>
    value.trim() == value && value.isNotEmpty && !value.contains('/');
