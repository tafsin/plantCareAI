import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';

import 'adapty_sdk_facade.dart';

final class AdaptyPremiumSubscriptionRepository
    implements PremiumSubscriptionRepository {
  AdaptyPremiumSubscriptionRepository(
    this._session,
    this._configuration, {
    AdaptySdkFacade? sdk,
    PurchasePlatform? platform,
    DateTime Function()? now,
  }) : _sdk = sdk ?? FlutterAdaptySdkFacade(),
       platform = platform ?? currentPurchasePlatform(),
       _now = now ?? DateTime.now;

  final AuthenticationSession _session;
  final PremiumSubscriptionConfiguration _configuration;
  final AdaptySdkFacade _sdk;
  final DateTime Function() _now;
  @override
  final PurchasePlatform platform;
  final _access = StreamController<PremiumAccessSnapshot>.broadcast();
  final _paywallEvents = StreamController<PaywallEvent>.broadcast();
  StreamSubscription<AppUser?>? _authSubscription;
  StreamSubscription<AdaptySdkProfile>? _profileSubscription;
  PremiumAccessSnapshot _currentAccess =
      const PremiumAccessSnapshot.signedOut();
  Future<void> _tail = Future.value();
  Future<void>? _initialization;
  Object? _initializationError;
  String? _identifiedUserId;
  int _identityGeneration = 0;
  AdaptySdkProduct? _product;
  PremiumOffer? _offer;
  String? _productUserId;
  int? _productGeneration;

  @override
  Stream<PremiumAccessSnapshot> get accessChanges => _access.stream;

  @override
  Stream<PaywallEvent> get paywallEvents => _paywallEvents.stream;

  @override
  PremiumAccessSnapshot get currentAccess => _currentAccess;

  @override
  Future<void> initialize() {
    final existing = _initialization;
    if (existing != null) return existing;
    final attempt = _initializeSafely();
    _initialization = attempt;
    unawaited(
      attempt.whenComplete(() {
        if (_initializationError != null &&
            identical(_initialization, attempt)) {
          _initialization = null;
        }
      }),
    );
    return attempt;
  }

  Future<void> _initializeSafely() async {
    _initializationError = null;
    if (platform != PurchasePlatform.android) return;
    final key = _configuration.publicSdkKey?.trim();
    if (key == null || key.isEmpty) {
      _initializationError = const PremiumSubscriptionFailure(
        PremiumFailureType.configuration,
        'Premium purchasing is not configured for this build.',
      );
      return;
    }
    try {
      final currentUser = _session.currentUser;
      await _sdk.activate(apiKey: key, customerUserId: currentUser?.uid);
      _identifiedUserId = currentUser?.uid;
      _profileSubscription = _sdk.profileUpdates.listen(_onProfileUpdate);
      _authSubscription = _session.authStateChanges.listen(_queueIdentity);
      if (currentUser != null) {
        try {
          await _refreshFor(currentUser.uid, _identityGeneration);
        } catch (error, stackTrace) {
          _warnOrInactive(
            currentUser.uid,
            'Premium status could not be refreshed. Please try again.',
          );
          developer.log(
            'Initial premium profile refresh failed',
            name: 'plantcare_ai.subscriptions',
            error: error.runtimeType,
            stackTrace: stackTrace,
          );
        }
      }
    } catch (error, stackTrace) {
      _initializationError = _subscriptionFailure(
        error,
        fallbackType: PremiumFailureType.paywallUnavailable,
        fallbackMessage: 'Premium purchasing is unavailable right now.',
      );
      developer.log(
        'Premium subscription initialization failed',
        name: 'plantcare_ai.subscriptions',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
  }

  void _queueIdentity(AppUser? user) {
    if (user?.uid == _identifiedUserId) return;
    final generation = ++_identityGeneration;
    _tail = _tail
        .then((_) => _synchronizeIdentity(user, generation))
        .catchError((Object error, StackTrace stackTrace) {
          _warnOrInactive(
            user?.uid,
            'Premium status could not be refreshed. Please try again.',
          );
          developer.log(
            'Premium identity synchronization failed',
            name: 'plantcare_ai.subscriptions',
            error: error.runtimeType,
            stackTrace: stackTrace,
          );
        });
  }

  Future<void> _synchronizeIdentity(AppUser? user, int generation) async {
    final nextUserId = user?.uid;
    if (generation != _identityGeneration) return;
    _clearProduct();
    if (_identifiedUserId != null) await _sdk.logout();
    _identifiedUserId = null;
    if (nextUserId == null) {
      _emitAccess(const PremiumAccessSnapshot.signedOut());
      return;
    }
    _emitAccess(
      PremiumAccessSnapshot(
        userId: nextUserId,
        status: PremiumAccessStatus.checking,
      ),
    );
    await _sdk.identify(nextUserId);
    if (generation != _identityGeneration) return;
    _identifiedUserId = nextUserId;
    await _refreshFor(nextUserId, generation);
  }

  Future<void> _refreshFor(String userId, int generation) async {
    final profile = await _sdk.getProfile();
    if (generation != _identityGeneration || _identifiedUserId != userId) {
      return;
    }
    _applyProfile(profile, expectedUserId: userId);
  }

  Future<String> _readyUser() async {
    if (platform != PurchasePlatform.android) {
      throw const PremiumSubscriptionFailure(
        PremiumFailureType.unsupported,
        'Premium purchasing is currently available on Android.',
      );
    }
    await initialize();
    await _tail;
    if (_initializationError case final Object error) {
      if (error is PremiumSubscriptionFailure) throw error;
      throw const PremiumSubscriptionFailure(
        PremiumFailureType.paywallUnavailable,
        'Premium purchasing is unavailable right now.',
      );
    }
    final userId = _session.currentUser?.uid;
    if (userId == null || userId != _identifiedUserId) {
      throw const PremiumSubscriptionFailure(
        PremiumFailureType.notReady,
        'Premium purchasing is still connecting to your account.',
      );
    }
    return userId;
  }

  @override
  Future<PaywallPreparation> preparePaywall() async {
    if (platform != PurchasePlatform.android) {
      return const PaywallPreparation(PaywallAvailability.unsupported);
    }
    _clearProduct();
    try {
      final userId = await _readyUser();
      final generation = _identityGeneration;
      final flow = await _sdk.getFlow(PremiumSubscriptionIds.placement);
      _ensureCurrentIdentity(userId, generation);
      final products = await _sdk.getProducts(flow);
      _ensureCurrentIdentity(userId, generation);
      final product = products.where(_isExpectedProduct).firstOrNull;
      if (product == null) {
        return const PaywallPreparation(
          PaywallAvailability.productUnavailable,
          failureType: PremiumFailureType.productUnavailable,
          message: 'The monthly Google Play product is unavailable right now.',
        );
      }
      final title = product.localizedTitle?.trim();
      final price = product.localizedPrice?.trim();
      final period = product.localizedPeriod?.trim();
      if (title == null ||
          title.isEmpty ||
          price == null ||
          price.isEmpty ||
          period == null ||
          period.isEmpty) {
        return const PaywallPreparation(
          PaywallAvailability.productUnavailable,
          failureType: PremiumFailureType.productUnavailable,
          message: 'Google Play product details are unavailable right now.',
        );
      }
      final offer = PremiumOffer(
        productId: product.vendorProductId,
        basePlanId: product.basePlanId!,
        localizedTitle: title,
        localizedPrice: price,
        billingPeriod: period,
      );
      _product = product;
      _offer = offer;
      _productUserId = userId;
      _productGeneration = generation;
      return PaywallPreparation(PaywallAvailability.ready, offer: offer);
    } on PremiumSubscriptionFailure catch (error) {
      return PaywallPreparation(
        error.type == PremiumFailureType.configuration
            ? PaywallAvailability.configurationUnavailable
            : PaywallAvailability.paywallUnavailable,
        failureType: error.type,
        message: error.message,
      );
    } catch (error, stackTrace) {
      final failure = _subscriptionFailure(
        error,
        fallbackType: PremiumFailureType.paywallUnavailable,
        fallbackMessage:
            'The premium offer could not be loaded. Please try again.',
      );
      developer.log(
        'Premium product loading failed',
        name: 'plantcare_ai.subscriptions',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
      return PaywallPreparation(
        PaywallAvailability.paywallUnavailable,
        failureType: failure.type,
        message: failure.message,
      );
    }
  }

  bool _isExpectedProduct(AdaptySdkProduct product) =>
      product.vendorProductId == PremiumSubscriptionIds.product &&
      product.basePlanId == PremiumSubscriptionIds.basePlan &&
      !product.hasOffer;

  void _ensureCurrentIdentity(String userId, int generation) {
    if (!_isCurrentIdentity(userId, generation)) {
      throw const PremiumSubscriptionFailure(
        PremiumFailureType.notReady,
        'Your account changed while Premium was loading. Please try again.',
      );
    }
  }

  bool _isCurrentIdentity(String userId, int generation) =>
      generation == _identityGeneration &&
      userId == _identifiedUserId &&
      _session.currentUser?.uid == userId;

  @override
  Future<PremiumPurchaseResult> purchase() async {
    final userId = await _readyUser();
    final generation = _identityGeneration;
    final product = _product;
    if (product == null ||
        _offer == null ||
        _productUserId != userId ||
        _productGeneration != generation ||
        !_isCurrentIdentity(userId, generation)) {
      throw const PremiumSubscriptionFailure(
        PremiumFailureType.notReady,
        'Reload the premium offer before continuing.',
      );
    }
    try {
      final result = await _sdk.makePurchase(product);
      _ensureCurrentIdentity(userId, generation);
      return switch (result) {
        AdaptySdkPurchasePending() => const PremiumPurchasePending(),
        AdaptySdkPurchaseCancelled() => const PremiumPurchaseCancelled(),
        AdaptySdkPurchaseSuccess(:final profile) => await _verifyPurchase(
          profile,
          userId,
          generation,
        ),
      };
    } catch (error) {
      if (error is PremiumSubscriptionFailure) rethrow;
      if (error case AdaptySdkFailure(type: AdaptySdkFailureType.cancelled)) {
        return const PremiumPurchaseCancelled();
      }
      if (error case AdaptySdkFailure(type: AdaptySdkFailureType.pending)) {
        return const PremiumPurchasePending();
      }
      throw _subscriptionFailure(
        error,
        fallbackType: PremiumFailureType.purchaseFailed,
        fallbackMessage: 'Purchase could not be completed. Please try again.',
      );
    }
  }

  Future<PremiumPurchaseResult> _verifyPurchase(
    AdaptySdkProfile profile,
    String userId,
    int generation,
  ) async {
    var verified = _applyProfile(profile, expectedUserId: userId);
    if (!verified) {
      final current = await _sdk.getProfile();
      _ensureCurrentIdentity(userId, generation);
      verified = _applyProfile(current, expectedUserId: userId);
    }
    if (!verified) {
      throw const PremiumSubscriptionFailure(
        PremiumFailureType.invalidEntitlement,
        'Google Play did not confirm premium access. Please retry or restore purchases.',
      );
    }
    return const PremiumPurchaseVerified();
  }

  @override
  Future<RestorePurchasesResult> restorePurchases() async {
    await _readyUser();
    _paywallEvents.add(const PaywallRestoreStarted());
    try {
      final profile = await _sdk.restorePurchases();
      final hasPremium = _applyProfile(
        profile,
        expectedUserId: _identifiedUserId,
      );
      _paywallEvents.add(PaywallRestoreCompleted(hasPremium: hasPremium));
      return RestorePurchasesResult(hasPremium: hasPremium);
    } catch (error) {
      final failure = _subscriptionFailure(
        error,
        fallbackType: PremiumFailureType.restorationFailed,
        fallbackMessage: 'Purchases could not be restored. Please try again.',
      );
      _paywallEvents.add(PaywallOperationFailed(failure.message));
      throw failure;
    }
  }

  @override
  Future<void> refreshProfile() async {
    final userId = await _readyUser();
    try {
      await _refreshFor(userId, _identityGeneration);
    } catch (_) {
      _warnOrInactive(
        userId,
        'Premium status could not be refreshed. Your last verified status is preserved.',
      );
      rethrow;
    }
  }

  void _onProfileUpdate(AdaptySdkProfile profile) {
    _applyProfile(profile, expectedUserId: _identifiedUserId);
  }

  bool _applyProfile(
    AdaptySdkProfile profile, {
    required String? expectedUserId,
  }) {
    if (expectedUserId == null ||
        _session.currentUser?.uid != expectedUserId ||
        (profile.customerUserId != null &&
            profile.customerUserId != expectedUserId)) {
      return false;
    }
    final expiresAt = profile.premiumExpiresAt;
    final hasPremium =
        profile.isPremiumActive &&
        (expiresAt == null || expiresAt.isAfter(_now()));
    _emitAccess(
      PremiumAccessSnapshot(
        userId: expectedUserId,
        status: hasPremium
            ? PremiumAccessStatus.active
            : PremiumAccessStatus.inactive,
      ),
    );
    return hasPremium;
  }

  PremiumSubscriptionFailure _subscriptionFailure(
    Object error, {
    required PremiumFailureType fallbackType,
    required String fallbackMessage,
  }) {
    if (error is PremiumSubscriptionFailure) return error;
    if (error case AdaptySdkFailure(type: AdaptySdkFailureType.network)) {
      return const PremiumSubscriptionFailure(
        PremiumFailureType.network,
        'A network connection is required. Please try again.',
      );
    }
    return PremiumSubscriptionFailure(fallbackType, fallbackMessage);
  }

  void _warnOrInactive(String? userId, String message) {
    if (_currentAccess.isActive && _currentAccess.userId == userId) {
      _emitAccess(_currentAccess.withWarning(message));
    } else {
      _emitAccess(
        PremiumAccessSnapshot(
          userId: userId,
          status: PremiumAccessStatus.inactive,
          warningMessage: message,
        ),
      );
    }
  }

  void _emitAccess(PremiumAccessSnapshot snapshot) {
    _currentAccess = snapshot;
    _access.add(snapshot);
  }

  void _clearProduct() {
    _product = null;
    _offer = null;
    _productUserId = null;
    _productGeneration = null;
  }

  @override
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _profileSubscription?.cancel();
    await _sdk.dispose();
    await _access.close();
    await _paywallEvents.close();
  }
}

PurchasePlatform currentPurchasePlatform() {
  if (kIsWeb) return PurchasePlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => PurchasePlatform.android,
    TargetPlatform.iOS => PurchasePlatform.ios,
    _ => PurchasePlatform.unsupported,
  };
}
