import '../entities/plant_observation.dart';

abstract interface class PlantObservationRepository {
  Future<String> saveObservation(String plantId, PlantObservation observation);
  Stream<List<PlantObservation>> watchObservations(String plantId);
  Stream<PlantObservation?> watchObservation(
    String plantId,
    String observationId,
  );
}
