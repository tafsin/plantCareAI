import 'dart:async';

import 'package:plantcare_ai/features/fertilizer_assessment/domain/entities/fertilizer_assessment.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/repositories/fertilizer_assessment_repository.dart';

final class FakeFertilizerAssessmentRepository
    implements FertilizerAssessmentRepository {
  final history = StreamController<List<FertilizerAssessment>>.broadcast(
    sync: true,
  );
  final details = <String, StreamController<FertilizerAssessment?>>{};
  Object? saveError;
  int saveCalls = 0;
  FertilizerAssessment? savedAssessment;

  @override
  Future<String> save(String plantId, FertilizerAssessment assessment) async {
    saveCalls++;
    savedAssessment = assessment;
    if (saveError != null) throw saveError!;
    return 'assessment-1';
  }

  @override
  Stream<List<FertilizerAssessment>> watchHistory(String plantId) =>
      history.stream;

  @override
  Stream<FertilizerAssessment?> watchDetails(
    String plantId,
    String assessmentId,
  ) =>
      (details[assessmentId] ??=
              StreamController<FertilizerAssessment?>.broadcast(sync: true))
          .stream;

  @override
  Future<void> delete(String plantId, String assessmentId) async {}

  void emitDetail(String id, FertilizerAssessment? item) =>
      (details[id] ??= StreamController<FertilizerAssessment?>.broadcast(
        sync: true,
      )).add(item);

  Future<void> close() async {
    await history.close();
    for (final controller in details.values) {
      await controller.close();
    }
  }
}
