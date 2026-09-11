import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_features/src/navigation/app_routes.dart';
import 'package:plantcare_features/src/plant_health_check/presentation/bloc/plant_health_check_bloc.dart';
import 'package:plantcare_features/src/plant_health_check/presentation/widgets/health_assessment_view.dart';
import 'package:plantcare_features/src/plants/presentation/bloc/plant_details_bloc.dart';

class PlantHealthCheckPage extends StatelessWidget {
  const PlantHealthCheckPage({required this.plantId, super.key});

  final String plantId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlantDetailsBloc, PlantDetailsState>(
      builder: (context, state) => switch (state.status) {
        PlantDetailsStatus.initial || PlantDetailsStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        PlantDetailsStatus.notFound => const _PageMessage(
          title: 'Plant not found',
          message: 'This plant may have been deleted or is unavailable.',
        ),
        PlantDetailsStatus.failure => _PageMessage(
          title: 'Couldn\'t load this plant',
          message: state.errorMessage ?? 'Please try again.',
        ),
        PlantDetailsStatus.loaded => _HealthCheckWorkflow(
          plantId: plantId,
          plant: state.plant!,
        ),
      },
    );
  }
}

class _HealthCheckWorkflow extends StatelessWidget {
  const _HealthCheckWorkflow({required this.plantId, required this.plant});

  final String plantId;
  final Plant plant;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlantHealthCheckBloc, PlantHealthCheckState>(
      builder: (context, state) {
        return SingleChildScrollView(
          key: const ValueKey('plant-health-check-page'),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          context.go(AppRoutes.healthHistory(plantId)),
                      icon: const Icon(Icons.history),
                      label: const Text('Health history'),
                    ),
                  ),
                  Text(
                    plant.commonName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  if (!state.hasSavedObservation) ...[
                    const _PhotoGuidance(),
                    const SizedBox(height: 16),
                    _ImageActions(state: state),
                    if (state.status == PlantHealthCheckStatus.processingImage)
                      const _InlineProgress(label: 'Checking photo'),
                    if (state.hasImage) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          context
                              .read<PlantHealthCheckBloc>()
                              .selectedImageBytes!,
                          key: const ValueKey('health-image-preview'),
                          height: 320,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const SizedBox(
                            height: 160,
                            child: Center(
                              child: Text('Photo preview unavailable.'),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: const ValueKey('remove-health-image'),
                          onPressed: state.busy
                              ? null
                              : () => context.read<PlantHealthCheckBloc>().add(
                                  const PlantHealthCheckImageRemoved(),
                                ),
                          icon: const Icon(Icons.close),
                          label: const Text('Remove'),
                        ),
                      ),
                    ],
                    TextField(
                      key: const ValueKey('health-note'),
                      enabled: !state.busy,
                      maxLength: PlantHealthCheckState.maxNoteLength,
                      onChanged: (value) => context
                          .read<PlantHealthCheckBloc>()
                          .add(PlantHealthCheckNoteChanged(value)),
                      decoration: const InputDecoration(
                        labelText: 'Optional note',
                        hintText: 'Lower leaves started yellowing this week',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _PrivacyDisclosure(),
                    FilledButton.icon(
                      key: const ValueKey('analyze-plant-health'),
                      onPressed: state.canAnalyze
                          ? () => context.read<PlantHealthCheckBloc>().add(
                              PlantHealthCheckAnalysisRequested(
                                plantId: plantId,
                                plant: plant,
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.health_and_safety_outlined),
                      label: const Text('Analyze plant'),
                    ),
                  ],
                  if (state.busy) ...[
                    const SizedBox(height: 20),
                    _ProgressStages(state: state),
                  ],
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _MessageCard(
                      title: _errorTitle(state),
                      message: state.errorMessage!,
                    ),
                  ],
                  if (state.localImageWarning != null) ...[
                    const SizedBox(height: 16),
                    _MessageCard(
                      title: 'Local image not saved',
                      message: state.localImageWarning!,
                    ),
                  ],
                  if (state.observationSaveRetryAvailable) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('retry-health-observation-save'),
                      onPressed: () => context.read<PlantHealthCheckBloc>().add(
                        const PlantHealthCheckObservationSaveRetryRequested(),
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Retry saving photo findings'),
                    ),
                  ],
                  if (state.status ==
                          PlantHealthCheckStatus.insufficientEvidence &&
                      state.observation != null) ...[
                    const SizedBox(height: 16),
                    HealthAssessmentView(
                      observation: state.observation!,
                      retrieval: state.retrieval,
                    ),
                  ],
                  if (state.status == PlantHealthCheckStatus.failure &&
                      state.saveRetryAvailable) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('retry-health-diagnosis-save'),
                      onPressed: () => context.read<PlantHealthCheckBloc>().add(
                        const PlantHealthCheckDiagnosisSaveRetryRequested(),
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Retry save'),
                    ),
                  ],
                  if (state.status == PlantHealthCheckStatus.complete &&
                      state.observation != null) ...[
                    const SizedBox(height: 16),
                    HealthAssessmentView(
                      observation: state.observation!,
                      diagnosis: state.diagnosis,
                      retrieval: state.retrieval,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _errorTitle(PlantHealthCheckState state) => switch (state.status) {
    PlantHealthCheckStatus.photoRejected => 'Try another photo',
    PlantHealthCheckStatus.insufficientEvidence => 'Assessment incomplete',
    _ =>
      state.hasSavedObservation
          ? 'Assessment incomplete'
          : 'Health check unavailable',
  };
}

class _ImageActions extends StatelessWidget {
  const _ImageActions({required this.state});

  final PlantHealthCheckState state;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      FilledButton.icon(
        key: const ValueKey('pick-health-gallery'),
        onPressed: state.busy
            ? null
            : () => context.read<PlantHealthCheckBloc>().add(
                const PlantHealthCheckImageRequested(PlantImageSource.gallery),
              ),
        icon: const Icon(Icons.photo_library_outlined),
        label: Text(!state.hasImage ? 'Choose photo' : 'Replace photo'),
      ),
      if (context.read<PlantHealthCheckBloc>().supportsCamera)
        OutlinedButton.icon(
          key: const ValueKey('pick-health-camera'),
          onPressed: state.busy
              ? null
              : () => context.read<PlantHealthCheckBloc>().add(
                  const PlantHealthCheckImageRequested(PlantImageSource.camera),
                ),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Use camera'),
        )
      else
        const Tooltip(
          message: 'Browser camera capture is not offered because support varies. Choose an existing file instead.',
          child: Chip(label: Text('Choose file on web')),
        ),
    ],
  );
}

class _PhotoGuidance extends StatelessWidget {
  const _PhotoGuidance();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'Photograph the affected area clearly in good light. Fill the frame with the leaf, stem, flower, fruit, or other symptom you want checked.',
      ),
    ),
  );
}

class _PrivacyDisclosure extends StatelessWidget {
  const _PrivacyDisclosure();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'When you select Analyze plant, the processed photo is sent to Firebase AI. After the structured findings are saved, a processed copy is stored automatically and privately on this device (or temporarily for this browser session on web). It is not uploaded to Firebase Storage or synchronized. Avoid faces, children, documents, addresses, and private home details.',
      ),
    ),
  );
}

class _ProgressStages extends StatelessWidget {
  const _ProgressStages({required this.state});

  final PlantHealthCheckState state;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Plant health check progress',
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: PlantHealthCheckStage.values
                .map(
                  (stage) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: state.completedStages.contains(stage)
                        ? const Icon(Icons.check_circle_outline)
                        : state.activeStage == stage
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.radio_button_unchecked),
                    title: Text(_stageLabel(stage)),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }

  String _stageLabel(PlantHealthCheckStage value) => switch (value) {
    PlantHealthCheckStage.checkingPhoto => 'Checking photo',
    PlantHealthCheckStage.lookingForVisibleSigns => 'Looking for visible signs',
    PlantHealthCheckStage.reviewingTrustedInformation =>
      'Reviewing trusted plant-care information',
    PlantHealthCheckStage.preparingAssessment =>
      'Preparing your health assessment',
    PlantHealthCheckStage.savingResults => 'Saving results',
  };
}

class _InlineProgress extends StatelessWidget {
  const _InlineProgress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message),
        ],
      ),
    ),
  );
}

class _PageMessage extends StatelessWidget {
  const _PageMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
