import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/local_plant_images.dart';
import 'package:plantcare_domain/plant_observation.dart';

import '../bloc/local_plant_images_bloc.dart';

class LocalPlantImagesPanel extends StatelessWidget {
  const LocalPlantImagesPanel({
    this.title = 'Local plant images',
    this.showStorageSummary = false,
    this.showDeleteAll = false,
    super.key,
  });

  final String title;
  final bool showStorageSummary;
  final bool showDeleteAll;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LocalPlantImagesBloc, LocalPlantImagesState>(
      listenWhen: (previous, current) =>
          current.actionRevision > previous.actionRevision,
      listener: (context, state) {
        final message = state.actionMessage;
        if (message != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) => Card(
        key: const ValueKey('local-plant-images-panel'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                state.isSessionOnly
                    ? 'Web images are temporary and remain only for this browser session.'
                    : 'Processed images are stored privately on this device and do not synchronize.',
              ),
              if (showStorageSummary) ...[
                const SizedBox(height: 8),
                Text('Storage used: ${_sizeLabel(state.storageUsedBytes)}'),
              ],
              const SizedBox(height: 12),
              switch (state.status) {
                LocalPlantImagesStatus.initial ||
                LocalPlantImagesStatus.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                LocalPlantImagesStatus.failure => Text(
                  state.errorMessage ?? 'Local images could not be loaded.',
                ),
                LocalPlantImagesStatus.empty => const Text(
                  'No local plant images are stored for this view.',
                ),
                LocalPlantImagesStatus.loaded => Column(
                  children: state.items
                      .map((item) => _LocalImageRow(item: item))
                      .toList(growable: false),
                ),
              },
              if (showDeleteAll && state.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('delete-all-local-images'),
                  onPressed: state.busyImageIds.isNotEmpty
                      ? null
                      : () => _confirmDeleteAll(context),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Delete all local plant images'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete all local plant images?'),
        content: const Text(
          'This removes every processed plant image stored for this account on this device. Cloud plant and observation records are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<LocalPlantImagesBloc>().add(
        const LocalPlantImagesDeleteAllRequested(),
      );
    }
  }
}

class _LocalImageRow extends StatelessWidget {
  const _LocalImageRow({required this.item});

  final LocalPlantImageItem item;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<LocalPlantImagesBloc, bool>(
      (bloc) => bloc.state.busyImageIds.contains(item.image.id),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.bytes == null
                ? const SizedBox(
                    key: ValueKey('local-image-missing'),
                    height: 180,
                    child: ColoredBox(
                      color: Color(0xFFE9EFE8),
                      child: Center(
                        child: Text('Local image is missing or unavailable.'),
                      ),
                    ),
                  )
                : Image.memory(
                    item.bytes!,
                    key: const ValueKey('local-image-preview'),
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 180,
                      child: Center(child: Text('Local image is unavailable.')),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            item.image.purpose == LocalPlantImagePurpose.plantIdentification
                ? 'Plant cover image'
                : 'Health-check image',
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => context.read<LocalPlantImagesBloc>().add(
                        LocalPlantImageReplaceRequested(
                          item.image.id,
                          PlantImageSource.gallery,
                        ),
                      ),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Replace local copy'),
              ),
              TextButton.icon(
                onPressed: busy ? null : () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete local copy'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this local image?'),
        content: const Text(
          'The cloud plant and observation records will remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<LocalPlantImagesBloc>().add(
        LocalPlantImageDeleteRequested(item.image.id),
      );
    }
  }
}

String _sizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(1)} KB';
  return '${(kib / 1024).toStringAsFixed(1)} MB';
}
