import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:test/test.dart';

void main() {
  test('premium access equality includes warnings and active status', () {
    const active = PremiumAccessSnapshot(
      userId: 'user-1',
      status: PremiumAccessStatus.active,
    );

    expect(active.isActive, isTrue);
    expect(
      active,
      const PremiumAccessSnapshot(
        userId: 'user-1',
        status: PremiumAccessStatus.active,
      ),
    );
    expect(active.withWarning('Refresh failed'), isNot(active));
  });

  test('paywall is presentable only with a ready localized offer', () {
    const offer = PremiumOffer(
      productId: PremiumSubscriptionIds.product,
      basePlanId: PremiumSubscriptionIds.basePlan,
      localizedPrice: r'$1.99',
      billingPeriod: 'month',
    );

    expect(
      const PaywallPreparation(
        PaywallAvailability.ready,
        offer: offer,
      ).canPresent,
      isTrue,
    );
    expect(
      const PaywallPreparation(PaywallAvailability.productUnavailable)
          .canPresent,
      isFalse,
    );
  });

  test('configuration requires a non-empty public key', () {
    const unavailable = PremiumSubscriptionConfiguration(
      publicSdkKey: null,
      privacyPolicyUrl: null,
      termsOfServiceUrl: null,
    );
    const available = PremiumSubscriptionConfiguration(
      publicSdkKey: 'public-key',
      privacyPolicyUrl: null,
      termsOfServiceUrl: null,
    );

    expect(unavailable.canActivate, isFalse);
    expect(available.canActivate, isTrue);
  });
}
