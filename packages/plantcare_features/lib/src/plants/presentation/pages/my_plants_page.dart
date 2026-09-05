import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_features/src/navigation/app_routes.dart';
import 'package:plantcare_features/src/plants/presentation/bloc/plants_bloc.dart';
import 'package:plantcare_features/src/plants/presentation/widgets/plant_labels.dart';

class MyPlantsPage extends StatelessWidget {
  const MyPlantsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PlantsBloc, PlantsState>(
      key: const ValueKey('my-plants-page'),
      listenWhen: (previous, current) =>
          current.actionRevision > previous.actionRevision &&
          current.deleteFailureMessage != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.deleteFailureMessage!)));
      },
      builder: (context, state) {
        return switch (state.status) {
          PlantsStatus.initial || PlantsStatus.loading => const Center(
            child: CircularProgressIndicator(key: ValueKey('plants-loading')),
          ),
          PlantsStatus.failure => _PlantsFailure(message: state.errorMessage),
          PlantsStatus.empty => const _EmptyPlants(),
          PlantsStatus.loaded => _PlantCollection(plants: state.plants),
        };
      },
    );
  }
}

class _EmptyPlants extends StatelessWidget {
  const _EmptyPlants();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('plants-empty'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_florist_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'No plants yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Add your first plant to start your collection.'),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('add-first-plant'),
              onPressed: () => context.go(AppRoutes.newPlant),
              icon: const Icon(Icons.add),
              label: const Text('Add plant'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantsFailure extends StatelessWidget {
  const _PlantsFailure({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('plants-failure'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message ?? 'Couldn\'t load your plants.'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  context.read<PlantsBloc>().add(const PlantsWatchRequested()),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantCollection extends StatelessWidget {
  const _PlantCollection({required this.plants});
  final List<Plant> plants;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 700
            ? 2
            : 1;
        return CustomScrollView(
          key: const ValueKey('plants-loaded'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your plants',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('add-plant'),
                      onPressed: () => context.go(AppRoutes.newPlant),
                      icon: const Icon(Icons.add),
                      label: const Text('Add plant'),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 190,
                ),
                itemCount: plants.length,
                itemBuilder: (context, index) =>
                    _PlantCard(plant: plants[index]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.plant});
  final Plant plant;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        key: ValueKey('plant-card-${plant.id}'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go(AppRoutes.plantDetails(plant.id)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plant.commonName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (plant.scientificName case final String name) ...[
                const SizedBox(height: 4),
                Text(name, style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
              const Spacer(),
              Text('${plant.environment.label} • ${plant.sunlight.label}'),
              const SizedBox(height: 4),
              Text(plant.growthStage.label),
              const SizedBox(height: 8),
              Text('Updated ${plantDateLabel(plant.updatedAt)}'),
            ],
          ),
        ),
      ),
    );
  }
}
