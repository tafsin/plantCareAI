import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';
import 'package:plantcare_ai/features/care_history/presentation/bloc/care_history_bloc.dart';
import 'package:plantcare_ai/features/care_history/presentation/bloc/care_log_form_bloc.dart';
import 'package:plantcare_ai/features/care_history/presentation/pages/care_log_form_page.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/entities/fertilizer_assessment.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/bloc/fertilizer_assessment_history_bloc.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_details_bloc.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plants_bloc.dart';
import 'package:plantcare_ai/features/plants/presentation/pages/plant_details_page.dart';

import '../../../helpers/fake_care_log_dependencies.dart';
import '../../../helpers/fake_fertilizer_assessment_repository.dart';
import '../../../helpers/fake_plant_repository.dart';

void main() {
  testWidgets('forms show only fields for their selected care type', (
    tester,
  ) async {
    final repository = FakeCareLogRepository();
    addTearDown(repository.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) =>
              CareLogFormBloc(repository, 'plant-1', CareLogType.watering),
          child: const CareLogFormPage(
            plantId: 'plant-1',
            type: CareLogType.watering,
          ),
        ),
      ),
    );
    expect(find.text('Amount in mL (optional)'), findsOneWidget);
    expect(find.text('Product name (optional)'), findsNothing);
    expect(find.textContaining('not a recommended amount'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) =>
              CareLogFormBloc(repository, 'plant-1', CareLogType.fertilizing),
          child: const CareLogFormPage(
            plantId: 'plant-1',
            type: CareLogType.fertilizing,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Product name (optional)'), findsOneWidget);
    expect(find.text('Application note (optional)'), findsOneWidget);
    expect(find.text('Amount in mL (optional)'), findsNothing);
    expect(find.textContaining('not confirming'), findsOneWidget);
  });

  testWidgets('Plant Details presents latest watering and fertilizer dates', (
    tester,
  ) async {
    final plants = FakePlantRepository();
    final care = FakeCareLogRepository();
    final assessments = FakeFertilizerAssessmentRepository();
    final detailsBloc = PlantDetailsBloc(plants)
      ..add(const PlantDetailsWatchRequested('plant-1'));
    final plantsBloc = PlantsBloc(plants);
    final historyBloc = CareHistoryBloc(care)
      ..add(const CareHistoryWatchRequested('plant-1'));
    final assessmentHistoryBloc = FertilizerAssessmentHistoryBloc(assessments)
      ..add(const FertilizerAssessmentHistoryWatchRequested('plant-1'));
    addTearDown(() async {
      await detailsBloc.close();
      await plantsBloc.close();
      await historyBloc.close();
      await assessmentHistoryBloc.close();
      await plants.close();
      await care.close();
      await assessments.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: detailsBloc),
            BlocProvider.value(value: plantsBloc),
            BlocProvider.value(value: historyBloc),
            BlocProvider.value(value: assessmentHistoryBloc),
          ],
          child: const PlantDetailsPage(
            plantId: 'plant-1',
            enableCareLogs: true,
            enableFertilizerAssessments: true,
          ),
        ),
      ),
    );
    plants.emitPlant('plant-1', _plant);
    care.history.add([
      WateringLog(
        id: 'water',
        occurredAt: DateTime(2026, 9, 2, 10),
        wateringMethod: WateringMethod.top,
      ),
      FertilizingLog(
        id: 'feed',
        occurredAt: DateTime(2026, 8, 20, 10),
        fertilizerForm: FertilizerForm.compost,
      ),
    ]);
    assessments.history.add([
      const FertilizerAssessment(
        id: 'assessment',
        growthActivity: GrowthActivity.activeGrowth,
        growthStageSnapshot: GrowthStage.mature,
        environmentSnapshot: PlantEnvironment.indoor,
        guidance: FertilizerGuidance(
          canonicalPlantKey: 'pothos',
          outcome: FertilizerOutcome.wait,
          title: 'Wait before reviewing fertilizer again',
          explanation: 'A recent log is inside the supported interval.',
          cautions: ['Follow the product label.'],
          evidenceChunkIds: [
            'pothos__nutrient_guidance__fertilizer_active_growth_interval',
          ],
        ),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('care-section')), findsOneWidget);
    expect(find.text('Last watered'), findsOneWidget);
    expect(find.text('2026-09-02'), findsOneWidget);
    expect(find.text('Last fertilized'), findsNWidgets(2));
    expect(find.text('2026-08-20'), findsNWidgets(2));
    expect(find.text('Log watering'), findsOneWidget);
    expect(find.text('Log fertilizer'), findsNWidgets(2));
    expect(find.text('View care history'), findsOneWidget);
    expect(find.byKey(const ValueKey('fertilizer-section')), findsOneWidget);
    expect(find.text('Wait before reviewing fertilizer again'), findsOneWidget);
    expect(find.text('Check fertilizer guidance'), findsOneWidget);
    expect(find.text('View assessment history'), findsOneWidget);
  });
}

const _plant = Plant(
  id: 'plant-1',
  commonName: 'Pothos',
  environment: PlantEnvironment.indoor,
  growingMedium: GrowingMedium.pot,
  sunlight: Sunlight.partial,
  growthStage: GrowthStage.mature,
);
