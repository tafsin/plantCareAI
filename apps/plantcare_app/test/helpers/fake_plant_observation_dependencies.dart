import 'dart:async';
import 'dart:typed_data';

import 'package:plantcare_domain/plant_observation.dart';

const sampleObservation = PlantObservation(
  schemaVersion: 1,
  plantVisible: true,
  imageQuality: ImageQuality(usable: true, issues: []),
  possibleIdentification: PossiblePlantIdentification(
    commonName: 'Tomato',
    scientificName: 'Solanum lycopersicum',
    confidence: 0.82,
  ),
  affectedParts: [AffectedPlantPart.leaf],
  observations: [
    VisibleObservation(
      type: VisualObservationType.yellowing,
      description: 'Yellow areas are visible between several leaf veins.',
      confidence: 0.88,
    ),
  ],
  distribution: 'Mostly visible on older lower leaves.',
  severity: ObservationSeverity.moderate,
  followUp: ObservationFollowUp(
    anotherPhotoHelpful: true,
    instruction: 'Take a clear photo of the underside of an affected leaf.',
  ),
);

final sampleSelectedImage = SelectedPlantImage(
  bytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
  mimeType: 'image/jpeg',
  filename: 'plant-analysis.jpg',
);

class FakePlantImagePicker implements PlantImagePicker {
  FakePlantImagePicker({this.supportsCamera = true});
  @override
  final bool supportsCamera;
  PickedPlantImage? result;
  Object? error;
  int calls = 0;
  @override
  Future<PickedPlantImage?> pick(PlantImageSource source) async {
    calls++;
    if (error case final Object value) throw value;
    return result;
  }
}

class FakePlantImageProcessor implements PlantImageProcessor {
  SelectedPlantImage result = sampleSelectedImage;
  Object? error;
  int calls = 0;
  @override
  Future<SelectedPlantImage> process(PickedPlantImage image) async {
    calls++;
    if (error case final Object value) throw value;
    return result;
  }
}

class FakePlantObservationService implements PlantObservationService {
  @override
  String get modelName => 'fake-model';
  PlantObservation result = sampleObservation;
  Object? error;
  Completer<PlantObservation>? completer;
  int calls = 0;
  @override
  Future<PlantObservation> observe({
    required SelectedPlantImage image,
    required PlantObservationContext context,
  }) {
    calls++;
    if (error case final Object value) return Future.error(value);
    return completer?.future ?? Future.value(result);
  }
}

class FakePlantObservationRepository implements PlantObservationRepository {
  final StreamController<List<PlantObservation>> historyController =
      StreamController<List<PlantObservation>>.broadcast(sync: true);
  final StreamController<PlantObservation?> detailsController =
      StreamController<PlantObservation?>.broadcast(sync: true);
  Object? saveError;
  int saveCalls = 0;
  String savedId = 'observation-1';

  @override
  Future<String> saveObservation(
    String plantId,
    PlantObservation observation,
  ) async {
    saveCalls++;
    if (saveError case final Object value) throw value;
    return savedId;
  }

  @override
  Stream<List<PlantObservation>> watchObservations(String plantId) =>
      historyController.stream;

  @override
  Stream<PlantObservation?> watchObservation(
    String plantId,
    String observationId,
  ) => detailsController.stream;

  Future<void> close() async {
    await historyController.close();
    await detailsController.close();
  }
}
