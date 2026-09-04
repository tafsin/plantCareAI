import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';
import 'package:plantcare_ai/features/soil_check/domain/entities/soil_check.dart';

abstract final class SoilCheckCodec {
  static Map<String, Object?> toFirestore(SoilCheckRecord record) {
    final guidance = record.guidance;
    return {
      'schemaVersion': guidance.schemaVersion,
      'policyVersion': guidance.policyVersion,
      'datasetVersion': guidance.datasetVersion,
      'moistureLevel': record.moistureLevel.value,
      'method': SoilCheckVersions.method,
      'outcome': guidance.outcome.value,
      'title': guidance.title,
      'explanation': guidance.explanation,
      'cautions': guidance.cautions,
      'canonicalPlantKey': guidance.canonicalPlantKey,
      'evidenceChunkIds': guidance.evidenceChunkIds,
      if (record.suggestedCheckAt != null)
        'suggestedCheckAt': Timestamp.fromDate(record.suggestedCheckAt!),
      'environmentSnapshot': record.environmentSnapshot.name,
      'growingMediumSnapshot': record.growingMediumSnapshot.name,
      'createdAt': FieldValue.serverTimestamp(),
      'source': SoilCheckVersions.source,
    };
  }

  static SoilCheckRecord fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) throw const FormatException('Missing soil check.');
    return fromFirestoreData(id: snapshot.id, data: data);
  }

  static SoilCheckRecord fromFirestoreData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final keys = data.keys.toSet();
    const required = {
      'schemaVersion',
      'policyVersion',
      'moistureLevel',
      'method',
      'outcome',
      'title',
      'explanation',
      'cautions',
      'canonicalPlantKey',
      'evidenceChunkIds',
      'environmentSnapshot',
      'growingMediumSnapshot',
      'createdAt',
      'source',
    };
    if (!keys.containsAll(required) ||
        keys.difference({
          ...required,
          'suggestedCheckAt',
          'datasetVersion',
        }).isNotEmpty ||
        data['schemaVersion'] != SoilCheckVersions.schema ||
        data['policyVersion'] != SoilCheckVersions.policy ||
        data['method'] != SoilCheckVersions.method ||
        data['source'] != SoilCheckVersions.source) {
      throw const FormatException('Invalid soil check schema.');
    }
    final cautions = _strings(data['cautions']);
    final evidence = _strings(data['evidenceChunkIds']);
    final createdAt = data['createdAt'];
    final suggestedAt = data['suggestedCheckAt'];
    return SoilCheckRecord(
      id: id,
      moistureLevel: SoilMoistureLevelValue.parse(
        data['moistureLevel'] as String,
      ),
      guidance: WateringGuidance(
        datasetVersion: _datasetVersion(data['datasetVersion']),
        canonicalPlantKey: data['canonicalPlantKey'] as String?,
        outcome: WateringOutcomeValue.parse(data['outcome'] as String),
        title: data['title'] as String,
        explanation: data['explanation'] as String,
        cautions: cautions,
        evidenceChunkIds: evidence,
      ),
      environmentSnapshot: PlantEnvironment.values.byName(
        data['environmentSnapshot'] as String,
      ),
      growingMediumSnapshot: GrowingMedium.values.byName(
        data['growingMediumSnapshot'] as String,
      ),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      suggestedCheckAt: suggestedAt is Timestamp ? suggestedAt.toDate() : null,
    );
  }

  static List<String> _strings(Object? value) {
    if (value is! List || value.any((item) => item is! String)) {
      throw const FormatException('Invalid string list.');
    }
    return value.cast<String>().toList(growable: false);
  }

  static String _datasetVersion(Object? value) {
    if (value == null) return SoilCheckVersions.legacyDataset;
    if (value == SoilCheckVersions.legacyDataset ||
        value == SoilCheckVersions.dataset) {
      return value as String;
    }
    throw const FormatException('Invalid soil check dataset version.');
  }
}
