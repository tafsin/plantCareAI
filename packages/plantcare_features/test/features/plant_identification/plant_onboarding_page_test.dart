import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_domain/plant_identification.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_features/plant_identification.dart';
import 'package:plantcare_features/plants.dart';

import '../../helpers/fake_plant_repository.dart';
import 'fakes.dart';

void main() {
  late PlantIdentificationBloc bloc;
  late FakePlantRepository repository;
  late IdentificationService service;
  setUp(() {
    repository = FakePlantRepository();
    service = IdentificationService();
  });
  tearDown(() async {
    await bloc.close();
    await repository.close();
  });
  Future<void> show(WidgetTester tester) async {
    bloc = PlantIdentificationBloc(Picker(), Processor(), service, repository);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: const PlantOnboardingPage(),
          ),
        ),
      ),
    );
  }

  Future<void> identify(WidgetTester tester) async {
    bloc.add(const IdentificationPhotoRequested(PlantImageSource.gallery));
    await tester.pumpAndSettle();
    bloc.add(const IdentificationConsentGranted());
    await tester.pumpAndSettle();
  }

  for (final width in [360.0, 1280.0]) {
    testWidgets('full review and save at width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await show(tester);
      await tester.tap(find.text('Identify from photo'));
      await tester.pumpAndSettle();
      expect(service.calls, 0);
      expect(
        bloc.state.step,
        PlantOnboardingStep.consent,
        reason: bloc.state.message,
      );
      expect(find.text('Agree & identify'), findsOneWidget);
      await tester.tap(find.text('Agree & identify'));
      await tester.pumpAndSettle();
      expect(find.text('Leading match · confirmation needed'), findsOneWidget);
      await tester.tap(find.text('Confirm Pothos'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Pothos'), findsOneWidget);
      expect(repository.addCalls, 0);
      await tester.ensureVisible(
        find.byKey(const ValueKey('plant-growing-medium')),
      );
      await tester.tap(find.byKey(const ValueKey('plant-growing-medium')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ground').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plant-pot-size')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('plant-growth-stage')),
      );
      await tester.tap(find.byKey(const ValueKey('plant-growth-stage')));
      await tester.pumpAndSettle();
      expect(find.text('Fruiting'), findsNothing);
      await tester.tap(find.text('Mature').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review plant'));
      await tester.tap(find.text('Review plant'));
      await tester.pumpAndSettle();
      expect(find.text('Step 5 of 5 · Review your plant'), findsOneWidget);
      expect(find.text('Growing medium: Ground'), findsOneWidget);
      expect(repository.addCalls, 0);
      await tester.tap(find.text('Edit details'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Pothos'), findsOneWidget);
      await tester.ensureVisible(find.text('Review plant'));
      await tester.tap(find.text('Review plant'));
      await tester.pumpAndSettle();
      repository.addError = Exception('offline');
      await tester.tap(find.text('Save plant'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Your details are still here'),
        findsOneWidget,
      );
      expect(service.calls, 1);
      expect(tester.takeException(), isNull);
    });
  }
  for (final confidence in [.3, .7]) {
    testWidgets('confidence $confidence presentation', (tester) async {
      service.value = result(confidence);
      await show(tester);
      await identify(tester);
      expect(find.text('Leading match · confirmation needed'), findsNothing);
      if (confidence < .6) {
        expect(
          find.text('Not enough confidence to suggest a match'),
          findsOneWidget,
        );
        expect(find.text('Confirm Pothos'), findsNothing);
      } else {
        expect(find.text('Confirm Pothos'), findsOneWidget);
      }
    });
  }
  testWidgets('unsupported identity displays warning and can enter profile', (
    tester,
  ) async {
    service.value = PlantIdentificationResult(
      imageStatus: IdentificationImageStatus.usableImage,
      candidates: [
        PlantIdentificationCandidate(
          commonName: 'Monstera',
          scientificName: 'Monstera deliciosa',
          confidence: .9,
          visibleEvidence: ['Split leaves'],
        ),
      ],
    );
    await show(tester);
    await identify(tester);
    expect(
      find.text(OnboardingPlantSupport.limitedGuidanceMessage),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Confirm Monstera'));
    await tester.tap(find.text('Confirm Monstera'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Monstera'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('plant-growth-stage')),
    );
    await tester.tap(find.byKey(const ValueKey('plant-growth-stage')));
    await tester.pumpAndSettle();
    expect(find.text('Fruiting'), findsWidgets);
  });
  for (final status in [
    IdentificationImageStatus.noPlantVisible,
    IdentificationImageStatus.insufficientImageQuality,
  ]) {
    testWidgets('unusable image ${status.name}', (tester) async {
      service.value = PlantIdentificationResult(
        imageStatus: status,
        candidates: [],
      );
      await show(tester);
      await identify(tester);
      expect(
        find.text(
          status == IdentificationImageStatus.noPlantVisible
              ? 'No plant visible'
              : 'We need a clearer photo',
        ),
        findsOneWidget,
      );
      expect(find.text('Try another photo'), findsOneWidget);
    });
  }
  testWidgets('manual fallback opens unchanged plant form without AI', (
    tester,
  ) async {
    bloc = PlantIdentificationBloc(Picker(), Processor(), service, repository);
    final form = PlantFormBloc(repository);
    final router = GoRouter(
      initialLocation: '/plants/new',
      routes: [
        GoRoute(
          path: '/plants/new',
          builder: (_, _) => Scaffold(
            body: BlocProvider.value(
              value: bloc,
              child: const PlantOnboardingPage(),
            ),
          ),
        ),
        GoRoute(
          path: '/plants/new/manual',
          builder: (_, _) => Scaffold(
            body: BlocProvider.value(value: form, child: const PlantFormPage()),
          ),
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await form.close();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add manually'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/plants/new/manual');
    expect(find.byKey(const ValueKey('plant-common-name')), findsOneWidget);
    expect(service.calls, 0);
  });
  testWidgets('fresh workflow resets at method selection', (tester) async {
    await show(tester);
    await identify(tester);
    final previous = bloc;
    await tester.pumpWidget(const SizedBox());
    addTearDown(previous.close);
    await show(tester);
    expect(find.text('Identify from photo'), findsOneWidget);
    expect(bloc.state.result, isNull);
  });
}
