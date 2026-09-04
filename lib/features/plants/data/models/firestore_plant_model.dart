import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plantcare_domain/plants.dart';

final class FirestorePlantModel {
  const FirestorePlantModel._();

  static Plant fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) throw const FormatException('Plant document is missing.');
    return Plant(
      id: snapshot.id,
      commonName: _requiredString(data, 'commonName'),
      scientificName: _optionalString(data, 'scientificName'),
      environment: _enumValue(PlantEnvironment.values, data['environment']),
      growingMedium: _enumValue(GrowingMedium.values, data['growingMedium']),
      potSizeLiters: _optionalNumber(data, 'potSizeLiters'),
      sunlight: _enumValue(Sunlight.values, data['sunlight']),
      growthStage: _enumValue(GrowthStage.values, data['growthStage']),
      notes: _optionalString(data, 'notes'),
      createdAt: _dateTime(data['createdAt']),
      updatedAt: _dateTime(data['updatedAt']),
    );
  }

  static Map<String, Object?> createData(PlantDraft draft) {
    final plant = draft.normalized();
    return {
      'commonName': plant.commonName,
      'scientificName': plant.scientificName,
      'environment': plant.environment.name,
      'growingMedium': plant.growingMedium.name,
      'potSizeLiters': plant.potSizeLiters,
      'sunlight': plant.sunlight.name,
      'growthStage': plant.growthStage.name,
      'notes': plant.notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, Object?> updateData(PlantDraft draft) {
    final data = createData(draft)..remove('createdAt');
    data['updatedAt'] = FieldValue.serverTimestamp();
    return data;
  }

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static String? _optionalString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static double? _optionalNumber(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! num) throw FormatException('$key must be a number.');
    return value.toDouble();
  }

  static T _enumValue<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! String) throw const FormatException('Invalid enum value.');
    return values.firstWhere(
      (value) => value.name == raw,
      orElse: () => throw FormatException('Unknown enum value: $raw'),
    );
  }

  static DateTime? _dateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    throw const FormatException('Timestamp field has an invalid type.');
  }
}
