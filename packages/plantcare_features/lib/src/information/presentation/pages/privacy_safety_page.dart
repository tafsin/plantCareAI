import 'package:flutter/material.dart';
import 'package:plantcare_features/src/local_plant_images/presentation/widgets/local_plant_images_panel.dart';

class PrivacySafetyPage extends StatelessWidget {
  const PrivacySafetyPage({this.enableLocalImages = false, super.key});

  final bool enableLocalImages;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('privacy-safety-page'),
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Privacy & Safety',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'How PlantCare AI Spark V1 handles photos, records, advice, and reminders.',
                ),
                const SizedBox(height: 24),
                const _InformationSection(
                  icon: Icons.photo_camera_outlined,
                  title: 'Plant photos',
                  body: 'When you explicitly submit a selected photo, its processed copy is sent to Firebase AI for visual analysis. After the related plant or photo findings are saved, PlantCare AI automatically keeps that processed copy privately on this device. The untouched original is not copied, and the processing pipeline removes image metadata. Web copies last only for the current browser session. Local images do not synchronize and may be lost if the app is removed or app/browser data is cleared.',
                ),
                const _InformationSection(
                  icon: Icons.storage_outlined,
                  title: 'Saved records',
                  body: 'Structured visual observations, diagnoses, plant profiles, care logs, soil checks, fertilizer assessments, and reminders are stored in Firestore for your signed-in account. Image bytes, local image paths, local image IDs, prompts, and raw AI responses are not stored in Firestore or Firebase Storage.',
                ),
                const _InformationSection(
                  icon: Icons.health_and_safety_outlined,
                  title: 'AI and plant-care safety',
                  body: 'AI observations and diagnoses can be wrong. Results are informational, uncertain, and not guaranteed. For serious, uncertain, toxic, pesticide-related, or food-crop concerns, consult a qualified local horticultural, agricultural, poison-control, or other appropriate expert.',
                ),
                if (enableLocalImages) ...[
                  const LocalPlantImagesPanel(
                    showStorageSummary: true,
                    showDeleteAll: true,
                  ),
                  const SizedBox(height: 16),
                ],
                const _InformationSection(
                  icon: Icons.notifications_none,
                  title: 'Reminder limits',
                  body: 'Mobile reminders are best-effort local notifications and are not guaranteed by a server. Web reminders appear only while PlantCare AI is in use; background web notifications are not available in this version.',
                ),
                const _InformationSection(
                  icon: Icons.manage_accounts_outlined,
                  title: 'V1 account limits',
                  body: 'Account deletion and full data export are not included in V1. Contact the Firebase project operator before release if an account-data request process is required.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InformationSection extends StatelessWidget {
  const _InformationSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, semanticLabel: title),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
