import 'package:flutter/material.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/widgets/fertilizer_assessment_labels.dart';
import 'package:plantcare_domain/fertilizer_assessment.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:url_launcher/url_launcher.dart';

class FertilizerGuidanceView extends StatelessWidget {
  const FertilizerGuidanceView({
    required this.guidance,
    required this.sources,
    super.key,
  });

  final FertilizerGuidance guidance;
  final List<KnowledgeSource> sources;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('fertilizer-guidance'),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(guidance.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(guidance.explanation),
          if (guidance.fertilizerCategory case final category?) ...[
            const SizedBox(height: 12),
            Text(
              'Broad category',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(category.label),
          ],
          if (guidance.suggestedReviewAt case final date?) ...[
            const SizedBox(height: 12),
            Text('Review again after ${date.toLocal()}'),
          ],
          if (guidance.cautions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Keep in mind', style: Theme.of(context).textTheme.labelLarge),
            ...guidance.cautions.map((item) => Text('• $item')),
          ],
          const SizedBox(height: 12),
          const Text(
            'This is general fertilizer guidance, not a dosage or treatment plan. Follow the product label and never fertilize to treat a suspected disease.',
          ),
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Reviewed sources',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...sources.map(
              (source) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(source.title),
                subtitle: Text(source.publisher),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => launchUrl(Uri.parse(source.url)),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
