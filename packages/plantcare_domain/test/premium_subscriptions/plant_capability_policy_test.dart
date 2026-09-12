import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:test/test.dart';

void main() {
  const inactive = PremiumAccessSnapshot(
    userId: 'user-1',
    status: PremiumAccessStatus.inactive,
  );
  const active = PremiumAccessSnapshot(
    userId: 'user-1',
    status: PremiumAccessStatus.active,
  );

  test('Free users can save below three and are denied at or above three', () {
    for (final count in [0, 1, 2]) {
      expect(
        PlantCapabilityPolicy.createSavedPlant(
          savedPlantCount: count,
          premiumAccess: inactive,
        ).allowed,
        isTrue,
      );
    }
    for (final count in [3, 4, 100]) {
      final decision = PlantCapabilityPolicy.createSavedPlant(
        savedPlantCount: count,
        premiumAccess: inactive,
      );
      expect(decision.allowed, isFalse);
      expect(decision.message, PlantCapabilityPolicy.plantLimitMessage);
    }
  });

  test('verified Premium can save at any existing count', () {
    for (final count in [0, 3, 4, 100]) {
      expect(
        PlantCapabilityPolicy.createSavedPlant(
          savedPlantCount: count,
          premiumAccess: active,
        ).allowed,
        isTrue,
      );
    }
  });

  test('checking, signed-out, and warning states retain Free allowance', () {
    for (final access in const [
      PremiumAccessSnapshot(
        userId: 'user-1',
        status: PremiumAccessStatus.checking,
      ),
      PremiumAccessSnapshot.signedOut(),
      PremiumAccessSnapshot(
        userId: 'user-1',
        status: PremiumAccessStatus.inactive,
        warningMessage: 'Status unavailable',
      ),
    ]) {
      expect(
        PlantCapabilityPolicy.createSavedPlant(
          savedPlantCount: 2,
          premiumAccess: access,
        ).allowed,
        isTrue,
      );
      expect(
        PlantCapabilityPolicy.createSavedPlant(
          savedPlantCount: 3,
          premiumAccess: access,
        ).allowed,
        isFalse,
      );
    }
  });

  test('active access remains unlimited when a warning is present', () {
    expect(
      PlantCapabilityPolicy.createSavedPlant(
        savedPlantCount: 20,
        premiumAccess: const PremiumAccessSnapshot(
          userId: 'user-1',
          status: PremiumAccessStatus.active,
          warningMessage: 'Refresh failed',
        ),
      ).allowed,
      isTrue,
    );
  });
}
