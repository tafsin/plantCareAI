import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plantcare_domain/fertilizer_assessment.dart';
import 'package:plantcare_domain/plants.dart';

abstract final class FertilizerAssessmentCodec {
  static Map<String, Object?> toFirestore(FertilizerAssessment value) {
    final guidance = value.guidance;
    return {
      'schemaVersion': guidance.schemaVersion,
      'policyVersion': guidance.policyVersion,
      'datasetVersion': guidance.datasetVersion,
      'canonicalPlantKey': guidance.canonicalPlantKey,
      'growthActivity': value.growthActivity.value,
      'growthStageSnapshot': value.growthStageSnapshot.name,
      'environmentSnapshot': value.environmentSnapshot.name,
      'outcome': guidance.outcome.value,
      if (guidance.fertilizerCategory != null)
        'fertilizerCategory': guidance.fertilizerCategory!.value,
      'title': guidance.title,
      'explanation': guidance.explanation,
      'cautions': guidance.cautions,
      'evidenceChunkIds': guidance.evidenceChunkIds,
      if (guidance.lastFertilizedAt != null)
        'lastFertilizedAt': Timestamp.fromDate(guidance.lastFertilizedAt!),
      if (guidance.suggestedReviewAt != null)
        'suggestedReviewAt': Timestamp.fromDate(guidance.suggestedReviewAt!),
      'createdAt': FieldValue.serverTimestamp(),
      'source': FertilizerAssessmentVersions.source,
    };
  }

  static FertilizerAssessment fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) throw const FormatException('Missing assessment.');
    const required = {
      'schemaVersion',
      'policyVersion',
      'datasetVersion',
      'canonicalPlantKey',
      'growthActivity',
      'growthStageSnapshot',
      'environmentSnapshot',
      'outcome',
      'title',
      'explanation',
      'cautions',
      'evidenceChunkIds',
      'createdAt',
      'source',
    };
    const optional = {
      'fertilizerCategory',
      'lastFertilizedAt',
      'suggestedReviewAt',
    };
    final keys = data.keys.toSet();
    if (!keys.containsAll(required) ||
        keys.difference({...required, ...optional}).isNotEmpty ||
        data['schemaVersion'] != FertilizerAssessmentVersions.schema ||
        data['policyVersion'] != FertilizerAssessmentVersions.policy ||
        data['datasetVersion'] != FertilizerAssessmentVersions.dataset ||
        data['source'] != FertilizerAssessmentVersions.source) {
      throw const FormatException('Invalid fertilizer assessment schema.');
    }
    final canonicalKey = data['canonicalPlantKey'];
    if (canonicalKey is! String || canonicalKey.isEmpty) {
      throw const FormatException('Invalid canonical plant key.');
    }
    final createdAt = data['createdAt'];
    final last = data['lastFertilizedAt'];
    final suggested = data['suggestedReviewAt'];
    final category = data['fertilizerCategory'];
    return FertilizerAssessment(
      id: snapshot.id,
      growthActivity: GrowthActivityValue.parse(
        data['growthActivity'] as String,
      ),
      growthStageSnapshot: GrowthStage.values.byName(
        data['growthStageSnapshot'] as String,
      ),
      environmentSnapshot: PlantEnvironment.values.byName(
        data['environmentSnapshot'] as String,
      ),
      guidance: FertilizerGuidance(
        canonicalPlantKey: canonicalKey,
        outcome: FertilizerOutcomeValue.parse(data['outcome'] as String),
        fertilizerCategory: category == null
            ? null
            : FertilizerCategoryValue.parse(category as String),
        title: _text(data['title']),
        explanation: _text(data['explanation']),
        cautions: _strings(data['cautions']),
        evidenceChunkIds: _strings(data['evidenceChunkIds']),
        lastFertilizedAt: last is Timestamp ? last.toDate() : null,
        suggestedReviewAt: suggested is Timestamp ? suggested.toDate() : null,
      ),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }

  static String _text(Object? value) {
    if (value is! String || value.trim() != value || value.isEmpty) {
      throw const FormatException('Invalid text.');
    }
    return value;
  }

  static List<String> _strings(Object? value) {
    if (value is! List || value.any((item) => item is! String)) {
      throw const FormatException('Invalid string list.');
    }
    return value.cast<String>().toList(growable: false);
  }
}
