import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/plant_observation.dart';

@LazySingleton(as: PlantImageProcessor)
final class LocalPlantImageProcessor implements PlantImageProcessor {
  const LocalPlantImageProcessor();

  static const maxOriginalBytes = 10 * 1024 * 1024;
  static const maxProcessedBytes = 2 * 1024 * 1024;

  @override
  Future<SelectedPlantImage> process(PickedPlantImage image) async {
    if (image.bytes.length > maxOriginalBytes) {
      throw const PlantObservationFailure(
        PlantObservationFailureType.imageTooLarge,
        'Choose an image smaller than 10 MB.',
      );
    }
    final format = _detectFormat(image.bytes);
    if (format == null) {
      throw const PlantObservationFailure(
        PlantObservationFailureType.unsupportedFormat,
        'Choose a valid JPEG or PNG image.',
      );
    }
    try {
      final bytes = await compute(_normalizeImage, image.bytes);
      if (bytes.length > maxProcessedBytes) {
        throw const PlantObservationFailure(
          PlantObservationFailureType.imageTooLarge,
          'This image could not be reduced below 2 MB. Choose a smaller photo.',
        );
      }
      return SelectedPlantImage(
        bytes: bytes,
        mimeType: 'image/jpeg',
        filename: _jpegFilename(image.filename),
      );
    } on PlantObservationFailure {
      rethrow;
    } catch (_) {
      throw const PlantObservationFailure(
        PlantObservationFailureType.imageProcessing,
        'This image could not be processed. Try another photo.',
      );
    }
  }

  String? _detectFormat(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return 'png';
    }
    return null;
  }

  String _jpegFilename(String filename) {
    final dot = filename.lastIndexOf('.');
    final base = dot > 0 ? filename.substring(0, dot) : filename;
    return '$base-analysis.jpg';
  }
}

Uint8List _normalizeImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width < 16 || decoded.height < 16) {
    throw const FormatException('Malformed image.');
  }
  var normalized = img.bakeOrientation(decoded);
  const edges = [1600, 1400, 1200, 1000, 800];
  for (final edge in edges) {
    if (normalized.width > edge || normalized.height > edge) {
      normalized = normalized.width >= normalized.height
          ? img.copyResize(normalized, width: edge)
          : img.copyResize(normalized, height: edge);
    }
    for (final quality in const [85, 75, 65, 55, 45]) {
      final encoded = Uint8List.fromList(
        img.encodeJpg(normalized, quality: quality),
      );
      if (encoded.length <= LocalPlantImageProcessor.maxProcessedBytes) {
        return encoded;
      }
    }
  }
  throw const PlantObservationFailure(
    PlantObservationFailureType.imageTooLarge,
    'This image could not be reduced below 2 MB. Choose a smaller photo.',
  );
}
