import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/plant_observation/data/services/local_plant_image_processor.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/selected_plant_image.dart';

void main() {
  const processor = LocalPlantImageProcessor();

  test('accepts and normalizes a valid JPEG selection', () async {
    final source = img.Image(width: 200, height: 100)
      ..clear(img.ColorRgb8(1, 2, 3));
    final result = await processor.process(
      PickedPlantImage(
        bytes: Uint8List.fromList(img.encodeJpg(source)),
        filename: 'leaf.jpeg',
      ),
    );

    expect(result.mimeType, 'image/jpeg');
    expect(result.filename, 'leaf-analysis.jpg');
    expect(result.bytes.length, lessThanOrEqualTo(2 * 1024 * 1024));
    expect(result.bytes.take(3), [0xff, 0xd8, 0xff]);
  });

  test('rejects unsupported files', () async {
    await expectLater(
      processor.process(
        PickedPlantImage(
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          filename: 'leaf.gif',
        ),
      ),
      throwsA(
        isA<PlantObservationFailure>().having(
          (error) => error.type,
          'type',
          PlantObservationFailureType.unsupportedFormat,
        ),
      ),
    );
  });

  test('rejects inputs larger than 10 MB before decoding', () async {
    final bytes = Uint8List(LocalPlantImageProcessor.maxOriginalBytes + 1)
      ..setAll(0, [0xff, 0xd8, 0xff]);
    await expectLater(
      processor.process(PickedPlantImage(bytes: bytes, filename: 'huge.jpg')),
      throwsA(
        isA<PlantObservationFailure>().having(
          (error) => error.type,
          'type',
          PlantObservationFailureType.imageTooLarge,
        ),
      ),
    );
  });
}
