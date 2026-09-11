import 'package:flutter/material.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_features/src/plant_observation/presentation/widgets/observation_result_view.dart';
import 'package:url_launcher/url_launcher.dart';

class HealthAssessmentView extends StatelessWidget {
  const HealthAssessmentView({
    required this.observation,
    this.diagnosis,
    this.retrieval,
    this.sources = const [],
    super.key,
  });

  final PlantObservation observation;
  final PlantDiagnosis? diagnosis;
  final KnowledgeRetrievalResult? retrieval;
  final List<KnowledgeSource> sources;

  @override
  Widget build(BuildContext context) {
    final diagnosis = this.diagnosis;
    final trustedSources = sources.isNotEmpty
        ? sources
        : retrieval?.rankedMatches
                  .expand((match) => match.sources)
                  .fold(<String, KnowledgeSource>{}, (map, source) {
                    map[source.id] = source;
                    return map;
                  })
                  .values
                  .toList(growable: false) ??
              const <KnowledgeSource>[];
    return Semantics(
      label: 'Plant health assessment result',
      child: Column(
        key: const ValueKey('health-assessment-result'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _summaryText(diagnosis),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Overall status',
            child: Text(_statusText(diagnosis, observation)),
          ),
          _Section(
            title: 'What the photo shows',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: observation.observations.isEmpty
                  ? [
                      const Text(
                        'No clear problem was identified in the photo.',
                      ),
                    ]
                  : observation.observations
                        .map((item) => Text('• ${item.description}'))
                        .toList(growable: false),
            ),
          ),
          if (diagnosis?.possibleIssues.isNotEmpty ?? false)
            _Section(
              title: 'Possible causes',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: diagnosis!.possibleIssues
                    .map(
                      (issue) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Possible cause: ${issue.name}\n${issue.reasoning}',
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          if (diagnosis?.recommendedActions.isNotEmpty ?? false)
            _Section(
              title: 'Recommended next steps',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: diagnosis!.recommendedActions
                    .map((item) => Text('• ${item.action}\n  ${item.reason}'))
                    .toList(growable: false),
              ),
            ),
          if (diagnosis?.avoidActions.isNotEmpty ?? false)
            _Section(
              title: 'What to avoid',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: diagnosis!.avoidActions
                    .map((item) => Text('• ${item.action}\n  ${item.reason}'))
                    .toList(growable: false),
              ),
            ),
          _Section(
            title: 'Follow-up photo',
            child: Text(_followUpText(diagnosis, observation)),
          ),
          if (trustedSources.isNotEmpty)
            _Section(
              title: 'Trusted sources',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: trustedSources
                    .map(
                      (source) => Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(source.url),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: Text('${source.publisher} - ${source.title}'),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ExpansionTile(
            key: const ValueKey('photo-findings-expansion'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Photo findings'),
            children: [ObservationResultView(observation: observation)],
          ),
          const SizedBox(height: 12),
          const Text(
            'PlantCare AI may be wrong. Use this as cautious guidance from one photo, not a guaranteed diagnosis. Follow product labels and seek local expert help for severe, spreading, edible-crop, child, pet, or pollinator safety concerns.',
          ),
        ],
      ),
    );
  }

  String _summaryText(PlantDiagnosis? diagnosis) {
    if (diagnosis == null) {
      return 'Photo findings were saved, but the assessment is incomplete.';
    }
    return diagnosis.summary;
  }

  String _statusText(PlantDiagnosis? diagnosis, PlantObservation observation) {
    if (!observation.plantVisible) return 'I need another photo.';
    if (!observation.imageQuality.usable) {
      return 'The photo needs to be retaken.';
    }
    return switch (diagnosis?.status) {
      DiagnosisStatus.healthyAppearance => 'No clear problem was identified.',
      DiagnosisStatus.insufficientEvidence =>
        'There is not enough trusted information to complete an assessment.',
      DiagnosisStatus.possibleIssuesFound => 'Possible issue found.',
      null => 'Assessment incomplete.',
    };
  }

  String _followUpText(
    PlantDiagnosis? diagnosis,
    PlantObservation observation,
  ) {
    if (diagnosis?.followUp.anotherPhotoHelpful ?? false) {
      return diagnosis!.followUp.instruction ?? 'Another clear photo may help.';
    }
    if (observation.followUp.anotherPhotoHelpful) {
      return observation.followUp.instruction ??
          'Another clear photo may help.';
    }
    return 'No additional photo is requested right now.';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}
