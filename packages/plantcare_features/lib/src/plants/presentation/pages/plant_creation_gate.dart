import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:plantcare_features/src/navigation/app_routes.dart';
import 'package:plantcare_features/src/plants/presentation/bloc/plants_bloc.dart';
import 'package:plantcare_features/src/premium_subscriptions/presentation/bloc/premium_access_bloc.dart';

class PlantCreationGate extends StatelessWidget {
  const PlantCreationGate({
    required this.returnTo,
    required this.child,
    super.key,
  });

  final String returnTo;
  final Widget child;

  @override
  Widget build(BuildContext context) => BlocBuilder<PlantsBloc, PlantsState>(
    builder: (context, plantsState) => switch (plantsState.status) {
      PlantsStatus.initial || PlantsStatus.loading => const Center(
        child: CircularProgressIndicator(
          key: ValueKey('plant-creation-access-loading'),
        ),
      ),
      PlantsStatus.failure => _CountFailure(message: plantsState.errorMessage),
      PlantsStatus.empty ||
      PlantsStatus.loaded => BlocBuilder<PremiumAccessBloc, PremiumAccessState>(
        builder: (context, premiumState) {
          final capability = PlantCapabilityPolicy.createSavedPlant(
            savedPlantCount: plantsState.plants.length,
            premiumAccess: premiumState.snapshot,
          );
          return capability.allowed
              ? child
              : _PlantLimitReached(
                  message:
                      capability.message ??
                      PlantCapabilityPolicy.plantLimitMessage,
                  returnTo: returnTo,
                );
        },
      ),
    },
  );
}

class _PlantLimitReached extends StatelessWidget {
  const _PlantLimitReached({required this.message, required this.returnTo});

  final String message;
  final String returnTo;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          key: const ValueKey('plant-limit-reached'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.eco_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Plant limit reached',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: Text(message)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('plant-limit-upgrade'),
                  onPressed: () =>
                      context.go(AppRoutes.premiumLocation(returnTo: returnTo)),
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: const Text('Upgrade to Premium'),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.plants),
                  child: const Text('Back to plants'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CountFailure extends StatelessWidget {
  const _CountFailure({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message ?? 'Could not load your plants. Please try again.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('plant-creation-count-retry'),
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
