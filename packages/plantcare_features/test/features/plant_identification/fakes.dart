import 'dart:async';
import 'dart:typed_data';

import 'package:plantcare_domain/plant_identification.dart';
import 'package:plantcare_domain/plant_observation.dart';

PlantIdentificationCandidate candidate([double confidence = 0.9]) =>
    PlantIdentificationCandidate(
      commonName: 'Pothos',
      scientificName: 'Epipremnum aureum',
      confidence: confidence,
      visibleEvidence: ['Heart shaped leaves'],
    );
PlantIdentificationResult result([double confidence = 0.9]) =>
    PlantIdentificationResult(
      imageStatus: IdentificationImageStatus.usableImage,
      candidates: [candidate(confidence)],
    );

class Picker implements PlantImagePicker {
  PickedPlantImage? image = PickedPlantImage(
    bytes: Uint8List.fromList([1, 2, 3]),
    filename: 'private.jpg',
  );
  Completer<PickedPlantImage?>? pending;
  int calls = 0;
  @override
  bool get supportsCamera => true;
  @override
  Future<PickedPlantImage?> pick(PlantImageSource source) async {
    calls++;
    return pending == null ? image : pending!.future;
  }
}

class Processor implements PlantImageProcessor {
  SelectedPlantImage? last;
  Object? error;
  @override
  Future<SelectedPlantImage> process(PickedPlantImage image) async {
    if (error != null) throw error!;
    return last = SelectedPlantImage(
      bytes: Uint8List.fromList(image.bytes),
      mimeType: 'image/jpeg',
      filename: 'processed.jpg',
    );
  }
}

class IdentificationService implements PlantIdentificationService {
  PlantIdentificationResult value = result();
  Object? error;
  Completer<PlantIdentificationResult>? pending;
  int calls = 0;
  @override
  Future<PlantIdentificationResult> identify({
    required SelectedPlantImage image,
  }) async {
    calls++;
    if (error != null) throw error!;
    return pending == null ? value : pending!.future;
  }
}
