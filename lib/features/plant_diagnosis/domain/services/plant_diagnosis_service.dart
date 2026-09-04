import 'package:plantcare_ai/features/plant_diagnosis/domain/entities/plant_diagnosis.dart';

abstract interface class PlantDiagnosisService {
  String get modelName;

  Future<PlantDiagnosis> generate(DiagnosisRequest request);
}
