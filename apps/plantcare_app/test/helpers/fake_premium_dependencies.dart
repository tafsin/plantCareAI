import 'dart:async';

import 'package:plantcare_domain/premium_subscriptions.dart';

final class FakePremiumSubscriptionRepository
    implements PremiumSubscriptionRepository {
  FakePremiumSubscriptionRepository({
    PurchasePlatform platform = PurchasePlatform.android,
    PremiumAccessSnapshot currentAccess = const PremiumAccessSnapshot(
      userId: 'user-1',
      status: PremiumAccessStatus.inactive,
    ),
  }) : this._(platform, currentAccess);

  FakePremiumSubscriptionRepository._(this.platform, this._currentAccess);

  @override
  final PurchasePlatform platform;
  final _access = StreamController<PremiumAccessSnapshot>.broadcast();
  final _events = StreamController<PaywallEvent>.broadcast();
  PremiumAccessSnapshot _currentAccess;

  @override
  Stream<PremiumAccessSnapshot> get accessChanges => _access.stream;

  @override
  Stream<PaywallEvent> get paywallEvents => _events.stream;

  @override
  PremiumAccessSnapshot get currentAccess => _currentAccess;

  void emitAccess(PremiumAccessSnapshot access) {
    _currentAccess = access;
    _access.add(access);
  }

  void emitEvent(PaywallEvent event) => _events.add(event);

  @override
  Future<void> initialize() async {}

  @override
  Future<PaywallPreparation> preparePaywall() async => const PaywallPreparation(
    PaywallAvailability.ready,
    offer: PremiumOffer(
      productId: PremiumSubscriptionIds.product,
      basePlanId: PremiumSubscriptionIds.basePlan,
      localizedPrice: r'$1.99',
      billingPeriod: 'month',
    ),
  );

  @override
  Future<void> presentPaywall() async {}

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<RestorePurchasesResult> restorePurchases() async =>
      const RestorePurchasesResult(hasPremium: false);

  @override
  Future<void> dispose() async {
    await _access.close();
    await _events.close();
  }
}

final class FakePremiumDestinationLauncher
    implements PremiumDestinationLauncher {
  @override
  bool get hasPrivacyPolicy => true;

  @override
  bool get hasTermsOfService => true;

  @override
  Future<void> openManageSubscription({String? productId}) async {}

  @override
  Future<void> openPrivacyPolicy() async {}

  @override
  Future<void> openTermsOfService() async {}
}
