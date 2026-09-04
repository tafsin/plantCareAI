import 'package:flutter/material.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';
import 'package:plantcare_ai/features/soil_check/domain/entities/soil_check.dart';
import 'package:url_launcher/url_launcher.dart';

class WateringGuidanceView extends StatelessWidget {
  const WateringGuidanceView({
    required this.guidance,
    this.sources = const [],
    super.key,
  });
  final WateringGuidance guidance;
  final List<KnowledgeSource> sources;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('watering-guidance'),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(guidance.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(guidance.explanation),
          if (guidance.cautions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Cautions', style: Theme.of(context).textTheme.titleMedium),
            ...guidance.cautions.map(
              (item) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $item'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Supporting evidence',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (sources.isEmpty)
            const Text(
              'Trusted source details are loaded before this check is saved.',
            )
          else
            ...sources.map(
              (source) => TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(source.url)),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text('${source.publisher}: ${source.title}'),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'This is bounded guidance, not a guarantee. Weather and sensor data are not considered.',
          ),
        ],
      ),
    ),
  );
}
