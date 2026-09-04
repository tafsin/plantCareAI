import 'package:plantcare_ai/features/plant_diagnosis/domain/entities/plant_diagnosis.dart';

abstract interface class PlantDiagnosisRepository {
  Future<String> saveDiagnosis(
    String plantId,
    String observationId,
    PlantDiagnosis diagnosis,
  );

  Stream<List<PlantDiagnosis>> watchDiagnoses(
    String plantId,
    String observationId,
  );

  Stream<PlantDiagnosis?> watchDiagnosis(
    String plantId,
    String observationId,
    String diagnosisId,
  );
}
