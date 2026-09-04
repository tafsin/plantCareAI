import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/plants/data/models/firestore_plant_model.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';

void main() {
  test('maps a normalized draft to Firestore create data', () {
    const draft = PlantDraft(
      commonName: '  Basil ',
      scientificName: ' ',
      environment: PlantEnvironment.outdoor,
      growingMedium: GrowingMedium.ground,
      potSizeLiters: 5,
      sunlight: Sunlight.full,
      growthStage: GrowthStage.vegetative,
      notes: '  Kitchen herb ',
    );

    final data = FirestorePlantModel.createData(draft);
    expect(data['commonName'], 'Basil');
    expect(data['scientificName'], isNull);
    expect(data['environment'], 'outdoor');
    expect(data['growingMedium'], 'ground');
    expect(data['potSizeLiters'], isNull);
    expect(data['notes'], 'Kitchen herb');
    expect(data['createdAt'], isA<FieldValue>());
    expect(data['updatedAt'], isA<FieldValue>());
  });

  test('update data never includes createdAt', () {
    const draft = PlantDraft(
      commonName: 'Basil',
      environment: PlantEnvironment.indoor,
      growingMedium: GrowingMedium.pot,
      sunlight: Sunlight.partial,
      growthStage: GrowthStage.mature,
    );
    expect(FirestorePlantModel.updateData(draft), isNot(contains('createdAt')));
  });
}
