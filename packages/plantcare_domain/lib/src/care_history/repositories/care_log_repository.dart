import '../entities/care_log.dart';

abstract interface class CareLogRepository {
  Stream<List<CareLog>> watchForPlant(String plantId);
  Future<CareLog?> getById(String plantId, String careLogId);
  Future<String> addWatering(String plantId, WateringLog log);
  Future<String> addFertilizing(String plantId, FertilizingLog log);
  Future<void> delete(String plantId, String careLogId);
}
