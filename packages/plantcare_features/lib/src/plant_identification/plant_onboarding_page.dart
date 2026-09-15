import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_domain/plant_identification.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_features/src/navigation/app_routes.dart';
import 'package:plantcare_features/src/plant_identification/plant_identification_bloc.dart';
import 'package:plantcare_features/src/plants/presentation/pages/plant_form_page.dart';
import 'package:plantcare_features/src/plants/presentation/widgets/plant_labels.dart';

class PlantOnboardingPage extends StatelessWidget {
  const PlantOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PlantIdentificationBloc>();
    void reset() => bloc.add(const IdentificationReset());
    void manual() {
      reset();
      context.go(AppRoutes.manualPlant);
    }

    return BlocConsumer<PlantIdentificationBloc, PlantIdentificationState>(
      listener: (context, state) {},
      builder: (context, state) {
        if (state.step == PlantOnboardingStep.profile) {
          return Column(
            children: [
              if (state.message != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    state.message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: PlantFormPage(
                  initialDraft: state.draft,
                  showHeader: false,
                  onBack: reset,
                  onReview: (draft) =>
                      bloc.add(OnboardingReviewRequested(draft)),
                ),
              ),
            ],
          );
        }
        final saving = state.step == PlantOnboardingStep.saving;
        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.message != null)
                    Semantics(
                      liveRegion: true,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(state.message!),
                        ),
                      ),
                    ),
                  if (state.plantLimitReached)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: FilledButton.icon(
                        key: const ValueKey('photo-creation-upgrade'),
                        onPressed: () => context.go(
                          AppRoutes.premiumLocation(
                            returnTo: AppRoutes.newPlant,
                          ),
                        ),
                        icon: const Icon(Icons.workspace_premium_outlined),
                        label: const Text('Upgrade to Premium'),
                      ),
                    ),
                  ...switch (state.step) {
                    PlantOnboardingStep.method => [
                      const Text('Step 1 of 5 · A new plant to get to know'),
                      const SizedBox(height: 20),
                      _Panel(
                        icon: Icons.eco_outlined,
                        title: 'Meet your next green companion',
                        children: [
                          const Text(
                            'Start with a photo, then confirm the plant and tell us where it grows.',
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => bloc.add(
                              const IdentificationPhotoRequested(
                                PlantImageSource.gallery,
                              ),
                            ),
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: const Text('Identify from photo'),
                          ),
                          if (bloc.supportsCamera)
                            OutlinedButton.icon(
                              onPressed: () => bloc.add(
                                const IdentificationPhotoRequested(
                                  PlantImageSource.camera,
                                ),
                              ),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Take a photo'),
                            ),
                        ],
                      ),
                      TextButton(
                        onPressed: manual,
                        child: const Text('Add manually'),
                      ),
                    ],
                    PlantOnboardingStep.picking => [
                      const _Busy('Preparing your photo…'),
                      TextButton(onPressed: reset, child: const Text('Cancel')),
                    ],
                    PlantOnboardingStep.preview => [
                      const Text('Step 2 of 5 · Photo & privacy'),
                      const SizedBox(height: 20),
                      if (bloc.selectedImageBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            bloc.selectedImageBytes!,
                            key: const ValueKey('identification-photo-preview'),
                            height: 320,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox(
                              height: 160,
                              child: Center(
                                child: Text('Photo preview unavailable.'),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      const _Panel(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Ready to identify?',
                        children: [
                          Text(
                            'Your photo has been checked and prepared on this device. When you select Identify plant, it will be sent to Firebase AI to suggest possible plant identities.',
                          ),
                          SizedBox(height: 16),
                          Text(
                            'After you create the plant, the processed photo is saved automatically as a private local cover image. It is not uploaded to Firebase Storage or synchronized to other devices.',
                          ),
                        ],
                      ),
                      CheckboxListTile(
                        key: const ValueKey('ai-processing-consent'),
                        contentPadding: EdgeInsets.zero,
                        value: state.aiProcessingConsented,
                        onChanged: (value) => bloc.add(
                          IdentificationConsentChanged(value ?? false),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'I consent to sending this photo to Firebase AI for plant identification.',
                        ),
                      ),
                      FilledButton(
                        key: const ValueKey('identify-plant-submit'),
                        onPressed: state.aiProcessingConsented
                            ? () => bloc.add(const IdentificationSubmitted())
                            : null,
                        child: const Text('Identify plant'),
                      ),
                      TextButton(
                        onPressed: reset,
                        child: const Text('Cancel — don’t send photo'),
                      ),
                      TextButton(
                        onPressed: manual,
                        child: const Text('Add manually'),
                      ),
                    ],
                    PlantOnboardingStep.identifying => [
                      const _Busy('Looking for visible plant features…'),
                      const Text(
                        'You can leave this step. A request already sent may still finish, but its result will be discarded.',
                      ),
                      TextButton(
                        onPressed: reset,
                        child: const Text('Cancel identification'),
                      ),
                    ],
                    PlantOnboardingStep.candidates => [
                      const Text('Step 3 of 5 · Confirm the identity'),
                      const SizedBox(height: 20),
                      ..._candidates(context, state, bloc),
                      OutlinedButton(
                        onPressed: () => bloc.add(
                          const IdentificationPhotoRequested(
                            PlantImageSource.gallery,
                          ),
                        ),
                        child: const Text('Try another photo'),
                      ),
                      TextButton(
                        onPressed: reset,
                        child: const Text('None of these'),
                      ),
                      TextButton(
                        onPressed: manual,
                        child: const Text('Add manually'),
                      ),
                    ],
                    PlantOnboardingStep.review ||
                    PlantOnboardingStep.saving => [
                      const Text('Step 5 of 5 · Review your plant'),
                      const SizedBox(height: 20),
                      _Panel(
                        icon: Icons.fact_check_outlined,
                        title: state.draft!.commonName,
                        children: [
                          Text(
                            state.draft!.scientificName ??
                                'Scientific name not provided',
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Environment: ${state.draft!.environment.label}',
                          ),
                          Text(
                            'Growing medium: ${state.draft!.growingMedium.label}',
                          ),
                          if (state.draft!.potSizeLiters != null)
                            Text(
                              'Pot size: ${state.draft!.potSizeLiters} liters',
                            ),
                          Text('Sunlight: ${state.draft!.sunlight.label}'),
                          Text(
                            'Growth stage: ${state.draft!.growthStage.label}',
                          ),
                          if (state.draft!.notes != null)
                            Text('Notes: ${state.draft!.notes}'),
                        ],
                      ),
                      if (!OnboardingPlantSupport.isSupported(
                        state.draft!.commonName,
                        state.draft!.scientificName,
                      ))
                        const _LimitedGuidance(),
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () => bloc.add(const OnboardingSaveRequested()),
                        child: Text(saving ? 'Saving…' : 'Save plant'),
                      ),
                      TextButton(
                        onPressed: saving
                            ? null
                            : () => bloc.add(const OnboardingEditRequested()),
                        child: const Text('Edit details'),
                      ),
                    ],
                    PlantOnboardingStep.saved => [
                      const Text('Saved'),
                      const SizedBox(height: 20),
                      const _Panel(
                        icon: Icons.health_and_safety_outlined,
                        title: 'Would you like to check this plant’s health?',
                        children: [
                          Text(
                            'Identification photos are for confirming the plant. A health check works best with a close photo of the symptom area.',
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        key: const ValueKey('check-new-plant-health'),
                        onPressed: () =>
                            context.go(AppRoutes.healthCheck(state.plantId!)),
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Check health'),
                      ),
                      TextButton(
                        key: const ValueKey('not-now-health-check'),
                        onPressed: () =>
                            context.go(AppRoutes.plantDetails(state.plantId!)),
                        child: const Text('Not now'),
                      ),
                    ],
                    PlantOnboardingStep.profile => [],
                  },
                  const SizedBox(height: 24),
                  Text(
                    state.step == PlantOnboardingStep.saved
                        ? 'The processed cover image is stored only on this device (or for this browser session on web) and may be deleted from the plant details page.'
                        : 'Before plant creation, the photo and unsaved progress are temporary. Leaving or refreshing this page starts over.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _candidates(
    BuildContext context,
    PlantIdentificationState state,
    PlantIdentificationBloc bloc,
  ) {
    final result = state.result!;
    if (result.imageStatus == IdentificationImageStatus.noPlantVisible) {
      return [
        const _Panel(
          icon: Icons.search_off,
          title: 'No plant visible',
          children: [Text('Choose a photo with one plant clearly in view.')],
        ),
      ];
    }
    if (result.imageStatus ==
        IdentificationImageStatus.insufficientImageQuality) {
      return [
        const _Panel(
          icon: Icons.blur_on,
          title: 'We need a clearer photo',
          children: [
            Text('Try good light, a steady camera, and visible leaves.'),
          ],
        ),
      ];
    }
    if (result.confidence == IdentificationConfidence.low) {
      return [
        const _Panel(
          icon: Icons.help_outline,
          title: 'Not enough confidence to suggest a match',
          children: [Text('Try another photo or add your plant manually.')],
        ),
      ];
    }
    return [
      const Text(
        'These are possibilities, not a guaranteed identification. Confirm only if the name and visible features fit your plant.',
      ),
      const SizedBox(height: 16),
      for (final (index, candidate) in result.candidates.indexed)
        _Panel(
          icon: Icons.eco_outlined,
          title: candidate.commonName,
          emphasized:
              index == 0 && result.confidence == IdentificationConfidence.high,
          children: [
            if (index == 0 &&
                result.confidence == IdentificationConfidence.high)
              const Text('Leading match · confirmation needed'),
            Text(
              candidate.scientificName,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${(candidate.confidence * 100).round()}% · not guaranteed',
              key: ValueKey('candidate-confidence-$index'),
            ),
            const SizedBox(height: 12),
            for (final evidence in candidate.visibleEvidence)
              Text('• $evidence'),
            if (candidate.ambiguityNote != null) Text(candidate.ambiguityNote!),
            if (!OnboardingPlantSupport.isSupported(
              candidate.commonName,
              candidate.scientificName,
            ))
              const _LimitedGuidance(),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () =>
                  bloc.add(IdentificationCandidateConfirmed(candidate)),
              child: Text('Confirm ${candidate.commonName}'),
            ),
          ],
        ),
    ];
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.title,
    required this.children,
    this.emphasized = false,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool emphasized;
  @override
  Widget build(BuildContext context) => Card(
    color: emphasized ? Theme.of(context).colorScheme.primaryContainer : null,
    margin: const EdgeInsets.only(bottom: 20),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

class _LimitedGuidance extends StatelessWidget {
  const _LimitedGuidance();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Text(OnboardingPlantSupport.limitedGuidanceMessage),
  );
}

class _Busy extends StatelessWidget {
  const _Busy(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(message),
        ],
      ),
    ),
  );
}
