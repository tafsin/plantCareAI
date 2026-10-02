import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';

final class AdaptySdkProfile {
  const AdaptySdkProfile({
    required this.customerUserId,
    required this.isPremiumActive,
    required this.premiumExpiresAt,
  });

  final String? customerUserId;
  final bool isPremiumActive;
  final DateTime? premiumExpiresAt;
}

final class AdaptySdkFlow {
  const AdaptySdkFlow({required this.handle});

  final Object handle;
}

final class AdaptySdkProduct {
  const AdaptySdkProduct({
    required this.handle,
    required this.vendorProductId,
    required this.basePlanId,
    required this.localizedTitle,
    required this.localizedPrice,
    required this.localizedPeriod,
    required this.hasOffer,
  });

  final Object handle;
  final String vendorProductId;
  final String? basePlanId;
  final String? localizedTitle;
  final String? localizedPrice;
  final String? localizedPeriod;
  final bool hasOffer;
}

sealed class AdaptySdkPurchaseResult {
  const AdaptySdkPurchaseResult();
}

final class AdaptySdkPurchaseSuccess extends AdaptySdkPurchaseResult {
  const AdaptySdkPurchaseSuccess(this.profile);

  final AdaptySdkProfile profile;
}

final class AdaptySdkPurchasePending extends AdaptySdkPurchaseResult {
  const AdaptySdkPurchasePending();
}

final class AdaptySdkPurchaseCancelled extends AdaptySdkPurchaseResult {
  const AdaptySdkPurchaseCancelled();
}

enum AdaptySdkFailureType { network, cancelled, pending, other }

final class AdaptySdkFailure implements Exception {
  const AdaptySdkFailure(this.type);

  final AdaptySdkFailureType type;
}

abstract interface class AdaptySdkFacade {
  Stream<AdaptySdkProfile> get profileUpdates;

  Future<void> activate({required String apiKey, String? customerUserId});

  Future<void> identify(String customerUserId);

  Future<void> logout();

  Future<AdaptySdkProfile> getProfile();

  Future<AdaptySdkFlow> getFlow(String placementId);

  Future<List<AdaptySdkProduct>> getProducts(AdaptySdkFlow flow);

  Future<AdaptySdkPurchaseResult> makePurchase(AdaptySdkProduct product);

  Future<AdaptySdkProfile> restorePurchases();

  Future<void> dispose();
}

final class FlutterAdaptySdkFacade implements AdaptySdkFacade {
  FlutterAdaptySdkFacade();

  final _profiles = StreamController<AdaptySdkProfile>.broadcast();
  StreamSubscription<AdaptyProfile>? _profileSubscription;

  @override
  Stream<AdaptySdkProfile> get profileUpdates => _profiles.stream;

  @override
  Future<void> activate({
    required String apiKey,
    String? customerUserId,
  }) async {
    final configuration = AdaptyConfiguration(apiKey: apiKey)
      ..withActivateUI(false);
    if (customerUserId != null) {
      configuration.withCustomerUserId(customerUserId);
    }
    await _call(() => Adapty().activate(configuration: configuration));
    _profileSubscription ??= Adapty().didUpdateProfileStream.listen(
      (profile) => _profiles.add(_profile(profile)),
    );
  }

  @override
  Future<void> identify(String customerUserId) =>
      _call(() => Adapty().identify(customerUserId));

  @override
  Future<void> logout() => _call(Adapty().logout);

  @override
  Future<AdaptySdkProfile> getProfile() async =>
      _profile(await _call(Adapty().getProfile));

  @override
  Future<AdaptySdkFlow> getFlow(String placementId) async => AdaptySdkFlow(
    handle: await _call(() => Adapty().getFlow(placementId: placementId)),
  );

  @override
  Future<List<AdaptySdkProduct>> getProducts(AdaptySdkFlow flow) async {
    final products = await _call(
      () => Adapty().getPaywallProducts(flow: flow.handle as AdaptyFlow),
    );
    return products
        .map(
          (product) => AdaptySdkProduct(
            handle: product,
            vendorProductId: product.vendorProductId,
            basePlanId: product.subscription?.basePlanId,
            localizedTitle: product.localizedTitle,
            localizedPrice: product.price.localizedString,
            localizedPeriod: product.subscription?.localizedPeriod,
            hasOffer: product.subscription?.offer != null,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<AdaptySdkPurchaseResult> makePurchase(AdaptySdkProduct product) async {
    final result = await _call(
      () => Adapty().makePurchase(
        product: product.handle as AdaptyPaywallProduct,
      ),
    );
    return switch (result) {
      AdaptyPurchaseResultSuccess(:final profile) => AdaptySdkPurchaseSuccess(
        _profile(profile),
      ),
      AdaptyPurchaseResultPending() => const AdaptySdkPurchasePending(),
      AdaptyPurchaseResultUserCancelled() => const AdaptySdkPurchaseCancelled(),
    };
  }

  @override
  Future<AdaptySdkProfile> restorePurchases() async =>
      _profile(await _call(Adapty().restorePurchases));

  AdaptySdkProfile _profile(AdaptyProfile profile) {
    final premium = profile.accessLevels[PremiumSubscriptionIds.accessLevel];
    return AdaptySdkProfile(
      customerUserId: profile.customerUserId,
      isPremiumActive: premium?.isActive ?? false,
      premiumExpiresAt: premium?.expiresAt,
    );
  }

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AdaptyError catch (error) {
      throw AdaptySdkFailure(_failureType(error.code));
    }
  }

  AdaptySdkFailureType _failureType(int code) => switch (code) {
    AdaptyErrorCode.networkFailed ||
    AdaptyErrorCode.serverError ||
    AdaptyErrorCode.fetchTimeoutError ||
    AdaptyErrorCode.billingServiceTimeout ||
    AdaptyErrorCode.billingServiceDisconnected ||
    AdaptyErrorCode.billingServiceUnavailable => AdaptySdkFailureType.network,
    AdaptyErrorCode.paymentCancelled => AdaptySdkFailureType.cancelled,
    AdaptyErrorCode.pendingPurchase => AdaptySdkFailureType.pending,
    _ => AdaptySdkFailureType.other,
  };

  @override
  Future<void> dispose() async {
    await _profileSubscription?.cancel();
    await _profiles.close();
  }
}
