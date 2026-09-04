import '../entities/plant_diagnosis.dart';

abstract interface class PlantDiagnosisService {
  String get modelName;

  Future<PlantDiagnosis> generate(DiagnosisRequest request);
}
