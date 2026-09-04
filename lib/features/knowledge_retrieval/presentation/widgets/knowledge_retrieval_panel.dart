import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/presentation/bloc/knowledge_retrieval_bloc.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalLinkOpener = Future<bool> Function(Uri uri);

class KnowledgeRetrievalPanel extends StatelessWidget {
  const KnowledgeRetrievalPanel({
    required this.plant,
    required this.observation,
    this.openExternalLink,
    super.key,
  });

  final Plant plant;
  final PlantObservation observation;
  final ExternalLinkOpener? openExternalLink;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KnowledgeRetrievalBloc, KnowledgeRetrievalState>(
      builder: (context, state) => switch (state.status) {
        KnowledgeRetrievalStatus.initial => FilledButton.icon(
          key: const ValueKey('find-relevant-knowledge'),
          onPressed: () => _request(context),
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Find relevant knowledge'),
        ),
        KnowledgeRetrievalStatus.loading => const Card(
          key: ValueKey('knowledge-loading'),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Finding relevant plant-care knowledge…'),
              ],
            ),
          ),
        ),
        KnowledgeRetrievalStatus.unsupportedPlant => _MessageCard(
          key: const ValueKey('knowledge-unsupported'),
          title: 'This plant is not in the current knowledge library',
          message: 'Supported plants: tomato, pumpkin, pothos, snake plant, and peace lily.',
          actionLabel: 'Try again',
          onAction: () => _request(context),
        ),
        KnowledgeRetrievalStatus.candidateConflict => _ConflictCard(
          candidates: state.candidates,
        ),
        KnowledgeRetrievalStatus.noStrongMatch => _MessageCard(
          key: const ValueKey('knowledge-empty'),
          title: 'No strong knowledge match',
          message:
              'No retrieved reference was relevant enough to this observation.',
          actionLabel: 'Try again',
          onAction: () => context.read<KnowledgeRetrievalBloc>().add(
            const KnowledgeRetrievalRetryRequested(),
          ),
          footer: _ResultMetadata(result: state.result!),
        ),
        KnowledgeRetrievalStatus.failure => _MessageCard(
          key: const ValueKey('knowledge-failure'),
          title: 'Couldn’t retrieve knowledge',
          message: state.errorMessage ?? 'Please try again.',
          actionLabel: 'Retry',
          onAction: () => context.read<KnowledgeRetrievalBloc>().add(
            const KnowledgeRetrievalRetryRequested(),
          ),
        ),
        KnowledgeRetrievalStatus.loaded => _LoadedKnowledge(
          result: state.result!,
          openExternalLink: openExternalLink,
        ),
      },
    );
  }

  void _request(BuildContext context) {
    context.read<KnowledgeRetrievalBloc>().add(
      KnowledgeRetrievalRequested(plant: plant, observation: observation),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.candidates});

  final List<String> candidates;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('knowledge-conflict'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose the plant for this search',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'The saved profile and image observation identify different supported plants. This choice applies only to this retrieval.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: candidates
                  .map(
                    (key) => FilledButton.tonal(
                      onPressed: () => context
                          .read<KnowledgeRetrievalBloc>()
                          .add(KnowledgePlantCandidateSelected(key)),
                      child: Text('Use ${SupportedPlants.labels[key] ?? key}'),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadedKnowledge extends StatelessWidget {
  const _LoadedKnowledge({required this.result, this.openExternalLink});

  final KnowledgeRetrievalResult result;
  final ExternalLinkOpener? openExternalLink;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('knowledge-loaded'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Relevant plant-care knowledge',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Resolved plant: ${SupportedPlants.labels[result.canonicalPlantKey]}',
        ),
        const SizedBox(height: 12),
        ...result.rankedMatches.map(
          (match) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _KnowledgeMatchCard(
              match: match,
              openExternalLink: openExternalLink,
            ),
          ),
        ),
        if (result.warnings.isNotEmpty) ...[
          Text(
            'Some references were unavailable:',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          ...result.warnings.map((warning) => Text('• $warning')),
          const SizedBox(height: 8),
        ],
        _ResultMetadata(result: result),
      ],
    );
  }
}

class _KnowledgeMatchCard extends StatelessWidget {
  const _KnowledgeMatchCard({required this.match, this.openExternalLink});

  final RankedKnowledgeMatch match;
  final ExternalLinkOpener? openExternalLink;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              match.chunk.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              _label(match.chunk.category),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 10),
            Text(match.chunk.content),
            const SizedBox(height: 12),
            Text(
              'Why it matched',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            ...match.matchedSignals.map((signal) => Text('• $signal')),
            if (match.chunk.cautions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Cautions', style: Theme.of(context).textTheme.labelLarge),
              ...match.chunk.cautions.map((caution) => Text('• $caution')),
            ],
            const SizedBox(height: 12),
            Text('Sources', style: Theme.of(context).textTheme.labelLarge),
            if (match.sources.isEmpty)
              const Text('Source attribution is currently unavailable.')
            else
              ...match.sources.map(
                (source) => Semantics(
                  link: true,
                  child: TextButton.icon(
                    onPressed: () => _open(context, source),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text('${source.publisher} — ${source.title}'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, KnowledgeSource source) async {
    final uri = Uri.parse(source.url);
    final opened =
        await (openExternalLink?.call(uri) ??
            launchUrl(uri, mode: LaunchMode.externalApplication));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open that source link.')),
      );
    }
  }

  String _label(String value) => value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

class _ResultMetadata extends StatelessWidget {
  const _ResultMetadata({required this.result});

  final KnowledgeRetrievalResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dataset ${result.datasetVersion} • Ranking ${result.algorithmVersion}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'These are potentially relevant references, not a confirmed diagnosis.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.footer,
    super.key,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message),
            if (footer != null) ...[const SizedBox(height: 12), footer!],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
