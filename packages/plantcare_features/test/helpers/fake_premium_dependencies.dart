import 'dart:async';

import 'package:plantcare_domain/premium_subscriptions.dart';

final class FakePremiumSubscriptionRepository
    implements PremiumSubscriptionRepository {
  FakePremiumSubscriptionRepository({
    PurchasePlatform platform = PurchasePlatform.android,
    PremiumAccessSnapshot currentAccess =
        const PremiumAccessSnapshot.signedOut(),
  }) : this._(platform, currentAccess);

  FakePremiumSubscriptionRepository._(this.platform, this._currentAccess);

  @override
  final PurchasePlatform platform;
  final _access = StreamController<PremiumAccessSnapshot>.broadcast();
  final _events = StreamController<PaywallEvent>.broadcast();
  PremiumAccessSnapshot _currentAccess;
  PaywallPreparation preparation = const PaywallPreparation(
    PaywallAvailability.ready,
    offer: PremiumOffer(
      productId: 'plantcare_premium',
      basePlanId: 'monthly',
      localizedPrice: r'$1.99',
      billingPeriod: 'month',
    ),
  );
  Object? presentError;
  Object? restoreError;
  RestorePurchasesResult restoreResult = const RestorePurchasesResult(
    hasPremium: false,
  );
  int prepareCalls = 0;
  int presentCalls = 0;
  int restoreCalls = 0;

  @override
  Stream<PremiumAccessSnapshot> get accessChanges => _access.stream;

  @override
  Stream<PaywallEvent> get paywallEvents => _events.stream;

  @override
  PremiumAccessSnapshot get currentAccess => _currentAccess;

  void emitAccess(PremiumAccessSnapshot value) {
    _currentAccess = value;
    _access.add(value);
  }

  void emitEvent(PaywallEvent event) => _events.add(event);

  @override
  Future<void> initialize() async {}

  @override
  Future<PaywallPreparation> preparePaywall() async {
    prepareCalls++;
    return preparation;
  }

  @override
  Future<void> presentPaywall() async {
    presentCalls++;
    if (presentError case final Object error) throw error;
  }

  @override
  Future<RestorePurchasesResult> restorePurchases() async {
    restoreCalls++;
    if (restoreError case final Object error) throw error;
    emitEvent(PaywallRestoreCompleted(hasPremium: restoreResult.hasPremium));
    return restoreResult;
  }

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<void> dispose() async {
    await _access.close();
    await _events.close();
  }
}

final class FakePremiumDestinationLauncher
    implements PremiumDestinationLauncher {
  FakePremiumDestinationLauncher({
    this.hasPrivacyPolicy = true,
    this.hasTermsOfService = true,
  });

  @override
  final bool hasPrivacyPolicy;
  @override
  final bool hasTermsOfService;
  final calls = <String>[];
  Object? error;

  Future<void> _call(String value) async {
    calls.add(value);
    if (error case final Object failure) throw failure;
  }

  @override
  Future<void> openManageSubscription({String? productId}) =>
      _call('manage:$productId');

  @override
  Future<void> openPrivacyPolicy() => _call('privacy');

  @override
  Future<void> openTermsOfService() => _call('terms');
}
