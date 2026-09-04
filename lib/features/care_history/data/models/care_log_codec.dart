import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';
import 'package:plantcare_ai/features/care_history/domain/services/care_log_validator.dart';

abstract final class CareLogCodec {
  static const _common = {
    'schemaVersion',
    'type',
    'occurredAt',
    'createdAt',
    'source',
  };

  static Map<String, Object?> toFirestore(CareLog log) {
    CareLogValidator.validate(log);
    final common = <String, Object?>{
      'schemaVersion': CareLogVersions.schema,
      'type': log.type.name,
      'occurredAt': Timestamp.fromDate(log.occurredAt),
      'notes': ?log.notes,
      'createdAt': FieldValue.serverTimestamp(),
      'source': CareLogVersions.source,
    };
    return switch (log) {
      WateringLog(:final wateringMethod, :final amountMl) => {
        ...common,
        'wateringMethod': wateringMethod.value,
        'amountMl': ?amountMl,
      },
      FertilizingLog(
        :final fertilizerForm,
        :final productName,
        :final applicationNote,
      ) =>
        {
          ...common,
          'productName': ?productName,
          'fertilizerForm': fertilizerForm.value,
          'applicationNote': ?applicationNote,
        },
    };
  }

  static CareLog fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) throw const FormatException('Missing care log.');
    return fromMap(snapshot.id, data);
  }

  static CareLog fromMap(String id, Map<String, dynamic> data) {
    if (!_validId(id) ||
        data['schemaVersion'] != CareLogVersions.schema ||
        data['source'] != CareLogVersions.source ||
        data['occurredAt'] is! Timestamp ||
        data['createdAt'] is! Timestamp) {
      throw const FormatException('Invalid care log schema.');
    }
    final notes = _optionalString(data, 'notes', CareLogLimits.notes);
    final occurredAt = (data['occurredAt'] as Timestamp).toDate();
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    final commonKeys = {..._common, if (data.containsKey('notes')) 'notes'};
    final log = switch (data['type']) {
      'watering' => _watering(
        id,
        data,
        commonKeys,
        occurredAt,
        createdAt,
        notes,
      ),
      'fertilizing' => _fertilizing(
        id,
        data,
        commonKeys,
        occurredAt,
        createdAt,
        notes,
      ),
      _ => throw const FormatException('Invalid care log type.'),
    };
    CareLogValidator.validate(log, now: createdAt);
    return log;
  }

  static WateringLog _watering(
    String id,
    Map<String, dynamic> data,
    Set<String> commonKeys,
    DateTime occurredAt,
    DateTime createdAt,
    String? notes,
  ) {
    final allowed = {
      ...commonKeys,
      'wateringMethod',
      if (data.containsKey('amountMl')) 'amountMl',
    };
    _exactKeys(data, allowed);
    final rawAmount = data['amountMl'];
    if (rawAmount != null && rawAmount is! num) {
      throw const FormatException('Invalid watering amount.');
    }
    return WateringLog(
      id: id,
      occurredAt: occurredAt,
      createdAt: createdAt,
      notes: notes,
      wateringMethod: WateringMethodValue.parse(
        data['wateringMethod'] as String,
      ),
      amountMl: (rawAmount as num?)?.toDouble(),
    );
  }

  static FertilizingLog _fertilizing(
    String id,
    Map<String, dynamic> data,
    Set<String> commonKeys,
    DateTime occurredAt,
    DateTime createdAt,
    String? notes,
  ) {
    final allowed = {
      ...commonKeys,
      'fertilizerForm',
      if (data.containsKey('productName')) 'productName',
      if (data.containsKey('applicationNote')) 'applicationNote',
    };
    _exactKeys(data, allowed);
    return FertilizingLog(
      id: id,
      occurredAt: occurredAt,
      createdAt: createdAt,
      notes: notes,
      fertilizerForm: FertilizerFormValue.parse(
        data['fertilizerForm'] as String,
      ),
      productName: _optionalString(
        data,
        'productName',
        CareLogLimits.productName,
      ),
      applicationNote: _optionalString(
        data,
        'applicationNote',
        CareLogLimits.applicationNote,
      ),
    );
  }

  static String? _optionalString(
    Map<String, dynamic> data,
    String field,
    int maxLength,
  ) {
    if (!data.containsKey(field)) return null;
    final value = data[field];
    if (value is! String ||
        value.isEmpty ||
        value.trim() != value ||
        value.length > maxLength) {
      throw FormatException('Invalid $field.');
    }
    return value;
  }

  static void _exactKeys(Map<String, dynamic> data, Set<String> allowed) {
    if (!data.keys.toSet().containsAll(allowed) ||
        data.keys.toSet().difference(allowed).isNotEmpty) {
      throw const FormatException('Invalid fields for care log type.');
    }
  }

  static bool _validId(String value) =>
      value.trim().isNotEmpty && !value.contains('/');
}
