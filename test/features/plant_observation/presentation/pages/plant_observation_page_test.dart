import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:plantcare_ai/features/plant_observation/presentation/bloc/plant_observation_bloc.dart';
import 'package:plantcare_ai/features/plant_observation/presentation/pages/plant_observation_page.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_details_bloc.dart';
import 'package:plantcare_domain/plant_observation.dart';

import '../../../../helpers/fake_plant_observation_dependencies.dart';
import '../../../../helpers/fake_plant_repository.dart';
import '../../../plants/plant_test_data.dart';

void main() {
  testWidgets('previews one image, requires consent, and renders result', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final plantRepository = FakePlantRepository();
    final observationRepository = FakePlantObservationRepository();
    final picker = FakePlantImagePicker(supportsCamera: false)
      ..result = PickedPlantImage(
        bytes: sampleSelectedImage.bytes,
        filename: 'plant.jpg',
      );
    final processor = FakePlantImageProcessor()
      ..result = SelectedPlantImage(
        bytes: img.encodeJpg(img.Image(width: 20, height: 20)),
        mimeType: 'image/jpeg',
        filename: 'plant-analysis.jpg',
      );
    final observationBloc = PlantObservationBloc(
      picker,
      processor,
      FakePlantObservationService(),
      observationRepository,
    );
    final detailsBloc = PlantDetailsBloc(plantRepository)
      ..add(PlantDetailsChanged(samplePlant));
    addTearDown(() async {
      await detailsBloc.close();
      await observationBloc.close();
      await observationRepository.close();
      await plantRepository.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: detailsBloc),
            BlocProvider.value(value: observationBloc),
          ],
          child: const Scaffold(body: PlantObservationPage(plantId: 'plant-1')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Web camera unavailable'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pick-gallery')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('image-preview')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('analyze-image')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('privacy-consent')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('analyze-image')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('analyze-image')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('observation-result')), findsOneWidget);
    expect(
      find.text('Visual observation—not a confirmed diagnosis'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('image-preview')), findsNothing);
  });
}
