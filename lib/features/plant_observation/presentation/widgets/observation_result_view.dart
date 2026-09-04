import 'package:flutter/material.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';

class ObservationResultView extends StatelessWidget {
  const ObservationResultView({required this.observation, super.key});
  final PlantObservation observation;

  @override
  Widget build(BuildContext context) {
    final identification = observation.possibleIdentification;
    return Card(
      key: const ValueKey('observation-result'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visual observation—not a confirmed diagnosis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _Line(
              label: 'Plant visible',
              value: observation.plantVisible ? 'Yes' : 'No',
            ),
            _Line(
              label: 'Image usable',
              value: observation.imageQuality.usable ? 'Yes' : 'No',
            ),
            _Line(
              label: 'Apparent severity',
              value: observation.severity.label,
            ),
            if (identification.commonName != null)
              _Line(
                label: 'Possible identification',
                value:
                    '${identification.commonName}${identification.scientificName == null ? '' : ' (${identification.scientificName})'} — uncertain${identification.confidence == null ? '' : ', ${(identification.confidence! * 100).round()}% model confidence'}',
              ),
            if (observation.imageQuality.issues.isNotEmpty)
              _Line(
                label: 'Image limitations',
                value: observation.imageQuality.issues
                    .map((value) => value.label)
                    .join(', '),
              ),
            if (observation.affectedParts.isNotEmpty)
              _Line(
                label: 'Affected parts',
                value: observation.affectedParts
                    .map((value) => value.label)
                    .join(', '),
              ),
            if (observation.observations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Visible evidence',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              ...observation.observations.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.visibility_outlined),
                  title: Text(item.type.label),
                  subtitle: Text(item.description),
                  trailing: Text('${(item.confidence * 100).round()}%'),
                ),
              ),
            ],
            if (observation.distribution.isNotEmpty)
              _Line(label: 'Distribution', value: observation.distribution),
            if (observation.followUp.anotherPhotoHelpful)
              _Line(
                label: 'Another photo would help',
                value:
                    observation.followUp.instruction ??
                    'Take another clear plant-only photo.',
              ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}

extension ObservationSeverityLabel on ObservationSeverity {
  String get label => switch (this) {
    ObservationSeverity.none => 'None visible',
    ObservationSeverity.mild => 'Mild',
    ObservationSeverity.moderate => 'Moderate',
    ObservationSeverity.severe => 'Severe',
    ObservationSeverity.unclear => 'Unclear',
  };
}

extension ObservationIssueLabel on ObservationIssue {
  String get label => name.replaceAllMapped(
    RegExp('[A-Z]'),
    (match) => ' ${match.group(0)!.toLowerCase()}',
  );
}

extension VisualObservationTypeLabel on VisualObservationType {
  String get label {
    final value = name.replaceAllMapped(
      RegExp('[A-Z]'),
      (match) => ' ${match.group(0)!.toLowerCase()}',
    );
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

extension AffectedPlantPartLabel on AffectedPlantPart {
  String get label => name.replaceAllMapped(
    RegExp('[A-Z]'),
    (match) => ' ${match.group(0)!.toLowerCase()}',
  );
}
