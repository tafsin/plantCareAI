import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';

abstract final class PlantValidationLimits {
  static const commonNameMaxLength = 80;
  static const scientificNameMaxLength = 120;
  static const notesMaxLength = 1000;
  static const potSizeLitersMax = 10000.0;
}

abstract final class PlantValidator {
  static String? commonName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter a common name.';
    if (trimmed.length > PlantValidationLimits.commonNameMaxLength) {
      return 'Use 80 characters or fewer.';
    }
    return null;
  }

  static String? scientificName(String? value) {
    if ((value?.trim().length ?? 0) >
        PlantValidationLimits.scientificNameMaxLength) {
      return 'Use 120 characters or fewer.';
    }
    return null;
  }

  static String? notes(String? value) {
    if ((value?.trim().length ?? 0) > PlantValidationLimits.notesMaxLength) {
      return 'Use 1,000 characters or fewer.';
    }
    return null;
  }

  static String? potSize(String? value, GrowingMedium medium) {
    if (medium == GrowingMedium.ground) return null;
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed);
    if (parsed == null ||
        parsed <= 0 ||
        parsed > PlantValidationLimits.potSizeLitersMax) {
      return 'Enter a number greater than 0 and no more than 10,000.';
    }
    return null;
  }

  static String? draft(PlantDraft draft) =>
      commonName(draft.commonName) ??
      scientificName(draft.scientificName) ??
      notes(draft.notes) ??
      _potSizeValue(draft);

  static String? _potSizeValue(PlantDraft draft) {
    final value = draft.potSizeLiters;
    if (draft.growingMedium == GrowingMedium.ground || value == null) {
      return null;
    }
    if (value <= 0 || value > PlantValidationLimits.potSizeLitersMax) {
      return 'Pot size must be greater than 0 and no more than 10,000 liters.';
    }
    return null;
  }
}
