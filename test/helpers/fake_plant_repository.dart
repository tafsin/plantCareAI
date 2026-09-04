import 'dart:async';

import 'package:plantcare_domain/plants.dart';

final class FakePlantRepository implements PlantRepository {
  final StreamController<List<Plant>> _plantsController =
      StreamController<List<Plant>>.broadcast(sync: true);
  final Map<String, StreamController<Plant?>> _plantControllers = {};

  Object? watchPlantsError;
  Object? addError;
  Object? updateError;
  Object? deleteError;
  String addedPlantId = 'new-plant';
  int watchPlantsCalls = 0;
  int addCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  PlantDraft? lastDraft;
  String? lastPlantId;

  @override
  Stream<List<Plant>> watchPlants() {
    watchPlantsCalls++;
    final error = watchPlantsError;
    if (error != null) return Stream.error(error);
    return _plantsController.stream;
  }

  void emitPlants(List<Plant> plants) => _plantsController.add(plants);
  void emitPlantsError(Object error) => _plantsController.addError(error);

  @override
  Stream<Plant?> watchPlant(String plantId) =>
      (_plantControllers[plantId] ??= StreamController<Plant?>.broadcast(
        sync: true,
      )).stream;

  void emitPlant(String plantId, Plant? plant) =>
      (_plantControllers[plantId] ??= StreamController<Plant?>.broadcast(
        sync: true,
      )).add(plant);

  @override
  Future<String> addPlant(PlantDraft plant) async {
    addCalls++;
    lastDraft = plant;
    if (addError case final Object error) throw error;
    return addedPlantId;
  }

  @override
  Future<void> updatePlant(String plantId, PlantDraft plant) async {
    updateCalls++;
    lastPlantId = plantId;
    lastDraft = plant;
    if (updateError case final Object error) throw error;
  }

  @override
  Future<void> deletePlant(String plantId) async {
    deleteCalls++;
    lastPlantId = plantId;
    if (deleteError case final Object error) throw error;
  }

  Future<void> close() async {
    await _plantsController.close();
    for (final controller in _plantControllers.values) {
      await controller.close();
    }
  }
}
