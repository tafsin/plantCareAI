import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';

final class AdaptySdkProfile {
  const AdaptySdkProfile({
    required this.customerUserId,
    required this.hasPremium,
  });

  final String? customerUserId;
  final bool hasPremium;
}

final class AdaptySdkFlow {
  const AdaptySdkFlow({
    required this.handle,
    required this.hasViewConfiguration,
  });

  final Object handle;
  final bool hasViewConfiguration;
}

final class AdaptySdkProduct {
  const AdaptySdkProduct({
    required this.vendorProductId,
    required this.basePlanId,
    required this.localizedPrice,
    required this.localizedPeriod,
    required this.hasOffer,
  });

  final String vendorProductId;
  final String? basePlanId;
  final String? localizedPrice;
  final String? localizedPeriod;
  final bool hasOffer;
}

sealed class AdaptySdkEvent {
  const AdaptySdkEvent();
}

final class AdaptySdkPurchaseStarted extends AdaptySdkEvent {
  const AdaptySdkPurchaseStarted();
}

final class AdaptySdkPurchasePending extends AdaptySdkEvent {
  const AdaptySdkPurchasePending();
}

final class AdaptySdkPurchaseCancelled extends AdaptySdkEvent {
  const AdaptySdkPurchaseCancelled();
}

final class AdaptySdkPurchaseSucceeded extends AdaptySdkEvent {
  const AdaptySdkPurchaseSucceeded(this.profile);

  final AdaptySdkProfile profile;
}

final class AdaptySdkRestoreStarted extends AdaptySdkEvent {
  const AdaptySdkRestoreStarted();
}

final class AdaptySdkRestoreSucceeded extends AdaptySdkEvent {
  const AdaptySdkRestoreSucceeded(this.profile);

  final AdaptySdkProfile profile;
}

final class AdaptySdkViewDismissed extends AdaptySdkEvent {
  const AdaptySdkViewDismissed();
}

final class AdaptySdkFailed extends AdaptySdkEvent {
  const AdaptySdkFailed(this.message);

  final String message;
}

abstract interface class AdaptySdkFacade {
  Stream<AdaptySdkProfile> get profileUpdates;

  Stream<AdaptySdkEvent> get events;

  Future<void> activate({required String apiKey, String? customerUserId});

  Future<void> identify(String customerUserId);

  Future<void> logout();

  Future<AdaptySdkProfile> getProfile();

  Future<AdaptySdkFlow> getFlow(String placementId);

  Future<List<AdaptySdkProduct>> getProducts(AdaptySdkFlow flow);

  Future<void> present(AdaptySdkFlow flow);

  Future<AdaptySdkProfile> restorePurchases();

  Future<void> dispose();
}

final class FlutterAdaptySdkFacade extends AdaptyUIFlowsEventsObserver
    implements AdaptySdkFacade {
  FlutterAdaptySdkFacade();

  final _profiles = StreamController<AdaptySdkProfile>.broadcast();
  final _events = StreamController<AdaptySdkEvent>.broadcast();
  StreamSubscription<AdaptyProfile>? _profileSubscription;

  @override
  Stream<AdaptySdkProfile> get profileUpdates => _profiles.stream;

  @override
  Stream<AdaptySdkEvent> get events => _events.stream;

  @override
  Future<void> activate({
    required String apiKey,
    String? customerUserId,
  }) async {
    final configuration = AdaptyConfiguration(apiKey: apiKey)
      ..withActivateUI(true);
    if (customerUserId != null) {
      configuration.withCustomerUserId(customerUserId);
    }
    await Adapty().activate(configuration: configuration);
    AdaptyUI().setFlowsEventsObserver(this);
    _profileSubscription ??= Adapty().didUpdateProfileStream.listen(
      (profile) => _profiles.add(_profile(profile)),
    );
  }

  @override
  Future<void> identify(String customerUserId) =>
      Adapty().identify(customerUserId);

  @override
  Future<void> logout() => Adapty().logout();

  @override
  Future<AdaptySdkProfile> getProfile() async =>
      _profile(await Adapty().getProfile());

  @override
  Future<AdaptySdkFlow> getFlow(String placementId) async {
    final flow = await Adapty().getFlow(placementId: placementId);
    return AdaptySdkFlow(
      handle: flow,
      hasViewConfiguration: flow.hasViewConfiguration,
    );
  }

  @override
  Future<List<AdaptySdkProduct>> getProducts(AdaptySdkFlow flow) async {
    final products = await Adapty().getPaywallProducts(
      flow: flow.handle as AdaptyFlow,
    );
    return products
        .map(
          (product) => AdaptySdkProduct(
            vendorProductId: product.vendorProductId,
            basePlanId: product.subscription?.basePlanId,
            localizedPrice: product.price.localizedString,
            localizedPeriod: product.subscription?.localizedPeriod,
            hasOffer: product.subscription?.offer != null,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> present(AdaptySdkFlow flow) async {
    final view = await AdaptyUI().createFlowView(
      flow: flow.handle as AdaptyFlow,
      preloadProducts: true,
    );
    await view.present();
  }

  @override
  Future<AdaptySdkProfile> restorePurchases() async =>
      _profile(await Adapty().restorePurchases());

  @override
  void flowViewDidStartPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
  ) => _events.add(const AdaptySdkPurchaseStarted());

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {
    switch (purchaseResult) {
      case AdaptyPurchaseResultSuccess(:final profile):
        _events.add(AdaptySdkPurchaseSucceeded(_profile(profile)));
      case AdaptyPurchaseResultPending():
        _events.add(const AdaptySdkPurchasePending());
      case AdaptyPurchaseResultUserCancelled():
        _events.add(const AdaptySdkPurchaseCancelled());
    }
  }

  @override
  void flowViewDidFailPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyError error,
  ) => _events.add(
    const AdaptySdkFailed('Purchase could not be completed. Please try again.'),
  );

  @override
  void flowViewDidStartRestore(AdaptyUIFlowView view) =>
      _events.add(const AdaptySdkRestoreStarted());

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) =>
      _events.add(AdaptySdkRestoreSucceeded(_profile(profile)));

  @override
  void flowViewDidFailRestore(AdaptyUIFlowView view, AdaptyError error) =>
      _events.add(
        const AdaptySdkFailed(
          'Purchases could not be restored. Please try again.',
        ),
      );

  @override
  void flowViewDidDisappear(AdaptyUIFlowView view) =>
      _events.add(const AdaptySdkViewDismissed());

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) =>
      _events.add(
        const AdaptySdkFailed(
          'The premium offer could not be displayed. Please try again.',
        ),
      );

  @override
  void flowViewDidFailLoadingProducts(
    AdaptyUIFlowView view,
    AdaptyError error,
  ) => _events.add(
    const AdaptySdkFailed(
      'Google Play products are unavailable right now. Please try again.',
    ),
  );

  AdaptySdkProfile _profile(AdaptyProfile profile) => AdaptySdkProfile(
    customerUserId: profile.customerUserId,
    hasPremium:
        profile.accessLevels[PremiumSubscriptionIds.accessLevel]?.isActive ??
        false,
  );

  @override
  Future<void> dispose() async {
    AdaptyUI().setFlowsEventsObserver(null);
    await _profileSubscription?.cancel();
    await _profiles.close();
    await _events.close();
  }
}
