import 'package:flutter/material.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';
import 'package:plantcare_ai/features/plant_diagnosis/domain/entities/plant_diagnosis.dart';
import 'package:url_launcher/url_launcher.dart';

class DiagnosisResultView extends StatelessWidget {
  const DiagnosisResultView({
    required this.diagnosis,
    this.retrieval,
    this.sources = const [],
    super.key,
  });

  final PlantDiagnosis diagnosis;
  final KnowledgeRetrievalResult? retrieval;
  final List<KnowledgeSource> sources;

  @override
  Widget build(BuildContext context) {
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
    return Column(
      key: const ValueKey('diagnosis-result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'AI-assisted, not guaranteed. This is a cautious interpretation of one saved visual observation using the sources shown below.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _statusLabel(diagnosis.status),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(diagnosis.summary),
        if (diagnosis.possibleIssues.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Possible issues',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...diagnosis.possibleIssues.map(
            (issue) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${_label(issue.likelihood.name)} • ${_label(issue.evidenceStrength.name)} evidence',
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'What the image observation showed',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    ...issue.supportingObservations.map(
                      (value) => Text('• $value'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'What Gemini cautiously inferred',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(issue.reasoning),
                    Text(
                      'Evidence: ${issue.evidenceChunkIds.join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (diagnosis.recommendedActions.isNotEmpty)
          _TextSection(
            title: 'Recommended low-risk actions',
            children: diagnosis.recommendedActions
                .map(
                  (item) =>
                      '${_label(item.priority.name)} — ${item.action}\n${item.reason}',
                )
                .toList(),
          ),
        if (diagnosis.avoidActions.isNotEmpty)
          _TextSection(
            title: 'Actions to avoid',
            children: diagnosis.avoidActions
                .map((item) => '${item.action}\n${item.reason}')
                .toList(),
          ),
        if (diagnosis.uncertainties.isNotEmpty)
          _TextSection(
            title: 'Uncertainties',
            children: diagnosis.uncertainties,
          ),
        const SizedBox(height: 20),
        Text(
          'Follow-up guidance',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          diagnosis.followUp.anotherPhotoHelpful
              ? diagnosis.followUp.instruction ??
                    'Another clear photo may help.'
              : 'Another photo is not currently requested.',
        ),
        if (diagnosis.followUp.professionalHelpRecommended)
          Text(
            diagnosis.followUp.professionalHelpReason ?? 'Consider consulting a local horticultural or agricultural professional.',
          ),
        const SizedBox(height: 20),
        Text(
          'What the sources state',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (retrieval != null)
          ...retrieval!.rankedMatches.map(
            (match) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${match.chunk.title}: ${match.chunk.content}'),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Evidence used: ${diagnosis.evidenceChunkIds.join(', ')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Trusted source attribution',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ...trustedSources.map(
          (source) => Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(source.url),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text('${source.publisher} — ${source.title}'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Dataset ${diagnosis.datasetVersion} • Retrieval ${diagnosis.retrievalAlgorithmVersion} • Model ${diagnosis.modelName}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  static String _statusLabel(DiagnosisStatus value) => switch (value) {
    DiagnosisStatus.healthyAppearance => 'Healthy appearance',
    DiagnosisStatus.insufficientEvidence => 'Insufficient evidence',
    DiagnosisStatus.possibleIssuesFound => 'Possible issues found',
  };

  static String _label(String value) => value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAll('_', ' ');
}

class _TextSection extends StatelessWidget {
  const _TextSection({required this.title, required this.children});
  final String title;
  final List<String> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        ...children.map(
          (value) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('• $value'),
          ),
        ),
      ],
    ),
  );
}
