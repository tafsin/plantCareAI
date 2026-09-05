import 'dart:typed_data';

import 'package:equatable/equatable.dart';

enum PlantImageSource { gallery, camera }

final class PickedPlantImage extends Equatable {
  const PickedPlantImage({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;

  @override
  List<Object?> get props => [filename, bytes.length];
}

final class SelectedPlantImage extends Equatable {
  const SelectedPlantImage({
    required this.bytes,
    required this.mimeType,
    required this.filename,
  });

  final Uint8List bytes;
  final String mimeType;
  final String filename;

  @override
  List<Object?> get props => [mimeType, filename, bytes.length];
}
