import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_features/src/local_plant_images/presentation/widgets/local_plant_images_panel.dart';
import 'package:plantcare_features/src/navigation/app_routes.dart';
import 'package:plantcare_features/src/plant_health_check/presentation/bloc/plant_health_assessment_bloc.dart';
import 'package:plantcare_features/src/plant_health_check/presentation/bloc/plant_health_check_bloc.dart';
import 'package:plantcare_features/src/plant_health_check/presentation/widgets/health_assessment_view.dart';
import 'package:plantcare_features/src/plants/presentation/bloc/plant_details_bloc.dart';

class PlantHealthAssessmentPage extends StatelessWidget {
  const PlantHealthAssessmentPage({
    required this.plantId,
    required this.observationId,
    this.enableLocalImages = false,
    super.key,
  });

  final String plantId;
  final String observationId;
  final bool enableLocalImages;

  @override
  Widget build(BuildContext context) {
    final plantState = context.watch<PlantDetailsBloc>().state;
    final assessmentState = context.watch<PlantHealthAssessmentBloc>().state;
    if (plantState.status == PlantDetailsStatus.initial ||
        plantState.status == PlantDetailsStatus.loading ||
        assessmentState.status == PlantHealthAssessmentStatus.initial ||
        assessmentState.status == PlantHealthAssessmentStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (plantState.status == PlantDetailsStatus.notFound ||
        assessmentState.status == PlantHealthAssessmentStatus.notFound) {
      return const Center(child: Text('Health assessment not found.'));
    }
    if (plantState.status == PlantDetailsStatus.failure ||
        assessmentState.status == PlantHealthAssessmentStatus.failure) {
      return Center(
        child: Text(
          assessmentState.errorMessage ??
              'Couldn\'t load this health assessment.',
        ),
      );
    }
    final plant = plantState.plant!;
    final observation = assessmentState.observation!;
    final latestDiagnosis = assessmentState.diagnosis;
    return BlocBuilder<PlantHealthCheckBloc, PlantHealthCheckState>(
      builder: (context, checkState) {
        final activeObservation = checkState.observation ?? observation;
        final activeDiagnosis = checkState.diagnosis ?? latestDiagnosis;
        return SingleChildScrollView(
          key: const ValueKey('plant-health-assessment-page'),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back to health history',
                        onPressed: () =>
                            context.go(AppRoutes.healthHistory(plantId)),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Text(
                          'Health Assessment',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (enableLocalImages) ...[
                    const LocalPlantImagesPanel(title: 'Health-check image'),
                    const SizedBox(height: 16),
                  ],
                  if (checkState.busy) _ProgressLabel(state: checkState),
                  if (checkState.errorMessage != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(checkState.errorMessage!),
                      ),
                    ),
                  if (activeDiagnosis == null && !checkState.busy) ...[
                    Card(
                      key: const ValueKey('health-assessment-incomplete'),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assessment incomplete',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Photo findings were saved, but no health assessment is saved for this entry yet.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              key: const ValueKey('continue-health-assessment'),
                              onPressed: () =>
                                  context.read<PlantHealthCheckBloc>().add(
                                    PlantHealthCheckAssessmentRetryRequested(
                                      plantId: plantId,
                                      plant: plant,
                                      observationId: observationId,
                                      observation: observation,
                                    ),
                                  ),
                              icon: const Icon(Icons.play_arrow_outlined),
                              label: const Text('Continue assessment'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  HealthAssessmentView(
                    observation: activeObservation,
                    diagnosis: activeDiagnosis,
                    retrieval: checkState.retrieval,
                    sources: checkState.retrieval == null
                        ? assessmentState.sources
                        : const [],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressLabel extends StatelessWidget {
  const _ProgressLabel({required this.state});

  final PlantHealthCheckState state;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(_label(state.activeStage))),
        ],
      ),
    ),
  );

  String _label(PlantHealthCheckStage? stage) => switch (stage) {
    PlantHealthCheckStage.checkingPhoto => 'Checking photo',
    PlantHealthCheckStage.lookingForVisibleSigns => 'Looking for visible signs',
    PlantHealthCheckStage.reviewingTrustedInformation =>
      'Reviewing trusted plant-care information',
    PlantHealthCheckStage.preparingAssessment =>
      'Preparing your health assessment',
    PlantHealthCheckStage.savingResults => 'Saving results',
    null => 'Preparing your health assessment',
  };
}
