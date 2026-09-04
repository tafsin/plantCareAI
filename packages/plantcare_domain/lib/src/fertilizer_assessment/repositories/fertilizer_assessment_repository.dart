import '../entities/fertilizer_assessment.dart';

abstract interface class FertilizerAssessmentRepository {
  Future<String> save(String plantId, FertilizerAssessment assessment);
  Stream<List<FertilizerAssessment>> watchHistory(String plantId);
  Stream<FertilizerAssessment?> watchDetails(
    String plantId,
    String assessmentId,
  );
  Future<void> delete(String plantId, String assessmentId);
}
