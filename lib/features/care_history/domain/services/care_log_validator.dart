import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';
import 'package:plantcare_shared/errors.dart';

abstract final class CareLogLimits {
  static const notes = 500;
  static const productName = 120;
  static const applicationNote = 500;
  static const maxAmountMl = 100000.0;
  static const futureClockSkew = Duration(minutes: 5);
  static const oldestAge = Duration(days: 365);
}

abstract final class CareLogValidator {
  static String? optionalText(String? value, int maxLength, String label) {
    if (value == null || value.isEmpty) return null;
    if (value.trim() != value) {
      return '$label must not start or end with spaces.';
    }
    if (value.length > maxLength) {
      return '$label must be $maxLength characters or fewer.';
    }
    return null;
  }

  static void validate(CareLog log, {DateTime? now}) {
    final reference = (now ?? DateTime.now()).toUtc();
    final occurred = log.occurredAt.toUtc();
    final dateError =
        occurred.isAfter(reference.add(CareLogLimits.futureClockSkew))
        ? 'The action time cannot be in the future.'
        : occurred.isBefore(reference.subtract(CareLogLimits.oldestAge))
        ? 'The action time cannot be more than one year ago.'
        : null;
    final notesError = optionalText(log.notes, CareLogLimits.notes, 'Notes');
    final error =
        dateError ??
        notesError ??
        switch (log) {
          WateringLog(:final amountMl) =>
            amountMl != null &&
                    (!amountMl.isFinite ||
                        amountMl <= 0 ||
                        amountMl > CareLogLimits.maxAmountMl)
                ? 'Amount must be greater than 0 and no more than 100,000 mL.'
                : null,
          FertilizingLog(:final productName, :final applicationNote) =>
            optionalText(
                  productName,
                  CareLogLimits.productName,
                  'Product name',
                ) ??
                optionalText(
                  applicationNote,
                  CareLogLimits.applicationNote,
                  'Application note',
                ),
        };
    if (error != null) throw ValidationAppError(error);
  }

  static String? normalizedOptional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
