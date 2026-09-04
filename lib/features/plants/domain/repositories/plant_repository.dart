import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';

abstract interface class PlantRepository {
  Stream<List<Plant>> watchPlants();
  Stream<Plant?> watchPlant(String plantId);
  Future<String> addPlant(PlantDraft plant);
  Future<void> updatePlant(String plantId, PlantDraft plant);
  Future<void> deletePlant(String plantId);
}
