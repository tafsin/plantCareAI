import 'package:equatable/equatable.dart';

import 'premium_subscriptions.dart';

final class PlantCreationCapability extends Equatable {
  const PlantCreationCapability._({required this.allowed, this.message});

  const PlantCreationCapability.allowed() : this._(allowed: true);

  const PlantCreationCapability.denied(String message)
    : this._(allowed: false, message: message);

  final bool allowed;
  final String? message;

  @override
  List<Object?> get props => [allowed, message];
}

/// Deterministic entitlement policy for capabilities that may vary by plan.
///
/// Creating another saved plant is the only plan-dependent capability in the
/// current product. All AI, guidance, history, care-log, and reminder behavior
/// remains outside this policy and therefore available under its existing
/// rules.
abstract final class PlantCapabilityPolicy {
  static const freeSavedPlantLimit = 3;
  static const plantLimitMessage =
      'Your free plan includes up to 3 plants. Upgrade to save unlimited plants.';

  static PlantCreationCapability createSavedPlant({
    required int savedPlantCount,
    required PremiumAccessSnapshot premiumAccess,
  }) {
    if (savedPlantCount < 0) {
      throw ArgumentError.value(
        savedPlantCount,
        'savedPlantCount',
        'must not be negative',
      );
    }
    if (premiumAccess.isActive || savedPlantCount < freeSavedPlantLimit) {
      return const PlantCreationCapability.allowed();
    }
    return const PlantCreationCapability.denied(plantLimitMessage);
  }
}
