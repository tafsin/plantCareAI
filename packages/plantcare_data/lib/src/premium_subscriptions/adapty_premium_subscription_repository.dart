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
  }) : _sdk = sdk ?? FlutterAdaptySdkFacade(),
       platform = platform ?? currentPurchasePlatform();

  final AuthenticationSession _session;
  final PremiumSubscriptionConfiguration _configuration;
  final AdaptySdkFacade _sdk;
  @override
  final PurchasePlatform platform;
  final _access = StreamController<PremiumAccessSnapshot>.broadcast();
  final _paywallEvents = StreamController<PaywallEvent>.broadcast();
  StreamSubscription<AppUser?>? _authSubscription;
  StreamSubscription<AdaptySdkProfile>? _profileSubscription;
  StreamSubscription<AdaptySdkEvent>? _eventSubscription;
  PremiumAccessSnapshot _currentAccess =
      const PremiumAccessSnapshot.signedOut();
  Future<void> _tail = Future.value();
  Future<void>? _initialization;
  Object? _initializationError;
  String? _identifiedUserId;
  int _identityGeneration = 0;
  AdaptySdkFlow? _flow;
  PremiumOffer? _offer;

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
      _eventSubscription = _sdk.events.listen(_onSdkEvent);
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
      _initializationError = error;
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
    _flow = null;
    _offer = null;
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
    await initialize();
    await _tail;
    if (_initializationError case final Object error) {
      throw PremiumSubscriptionFailure(
        error is PremiumSubscriptionFailure
            ? error.type
            : PremiumFailureType.unavailable,
        error is PremiumSubscriptionFailure
            ? error.message
            : 'Premium purchasing is unavailable right now.',
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
    try {
      final userId = await _readyUser();
      final generation = _identityGeneration;
      final flow = await _sdk.getFlow(PremiumSubscriptionIds.placement);
      if (!_isCurrentIdentity(userId, generation)) {
        throw const PremiumSubscriptionFailure(
          PremiumFailureType.notReady,
          'Your account changed while Premium was loading. Please try again.',
        );
      }
      if (!flow.hasViewConfiguration) {
        _flow = null;
        return const PaywallPreparation(
          PaywallAvailability.paywallUnavailable,
          message: 'The premium offer is unavailable right now.',
        );
      }
      final products = await _sdk.getProducts(flow);
      if (!_isCurrentIdentity(userId, generation)) {
        throw const PremiumSubscriptionFailure(
          PremiumFailureType.notReady,
          'Your account changed while Premium was loading. Please try again.',
        );
      }
      final product = products.where(_isExpectedProduct).firstOrNull;
      if (product == null) {
        _flow = null;
        return const PaywallPreparation(
          PaywallAvailability.productUnavailable,
          message: 'The monthly Google Play product is unavailable right now.',
        );
      }
      final price = product.localizedPrice?.trim();
      final period = product.localizedPeriod?.trim();
      if (price == null || price.isEmpty || period == null || period.isEmpty) {
        _flow = null;
        return const PaywallPreparation(
          PaywallAvailability.productUnavailable,
          message: 'Google Play pricing is unavailable right now.',
        );
      }
      final offer = PremiumOffer(
        productId: product.vendorProductId,
        basePlanId: product.basePlanId!,
        localizedPrice: price,
        billingPeriod: period,
      );
      _flow = flow;
      _offer = offer;
      return PaywallPreparation(PaywallAvailability.ready, offer: offer);
    } on PremiumSubscriptionFailure catch (error) {
      return PaywallPreparation(
        error.type == PremiumFailureType.configuration
            ? PaywallAvailability.configurationUnavailable
            : PaywallAvailability.paywallUnavailable,
        message: error.message,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Premium Flow loading failed',
        name: 'plantcare_ai.subscriptions',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
      return const PaywallPreparation(
        PaywallAvailability.paywallUnavailable,
        message: 'The premium offer could not be loaded. Please try again.',
      );
    }
  }

  bool _isExpectedProduct(AdaptySdkProduct product) =>
      product.vendorProductId == PremiumSubscriptionIds.product &&
      product.basePlanId == PremiumSubscriptionIds.basePlan &&
      !product.hasOffer;

  bool _isCurrentIdentity(String userId, int generation) =>
      generation == _identityGeneration &&
      userId == _identifiedUserId &&
      _session.currentUser?.uid == userId;

  @override
  Future<void> presentPaywall() async {
    await _readyUser();
    final flow = _flow;
    if (flow == null || _offer == null) {
      throw const PremiumSubscriptionFailure(
        PremiumFailureType.notReady,
        'Reload the premium offer before continuing.',
      );
    }
    try {
      await _sdk.present(flow);
    } catch (_) {
      throw const PremiumSubscriptionFailure(
        PremiumFailureType.purchase,
        'The premium offer could not be displayed. Please try again.',
      );
    }
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
    } catch (_) {
      const failure = PremiumSubscriptionFailure(
        PremiumFailureType.restore,
        'Purchases could not be restored. Please try again.',
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

  Future<void> _onSdkEvent(AdaptySdkEvent event) async {
    switch (event) {
      case AdaptySdkPurchaseStarted():
        _paywallEvents.add(const PaywallPurchaseStarted());
      case AdaptySdkPurchasePending():
        _paywallEvents.add(const PaywallPurchasePending());
      case AdaptySdkPurchaseCancelled():
        _paywallEvents.add(const PaywallPurchaseCancelled());
      case AdaptySdkPurchaseSucceeded(:final profile):
        var verified = _applyProfile(
          profile,
          expectedUserId: _identifiedUserId,
        );
        if (!verified) {
          try {
            final current = await _sdk.getProfile();
            verified = _applyProfile(
              current,
              expectedUserId: _identifiedUserId,
            );
          } catch (_) {
            verified = false;
          }
        }
        _paywallEvents.add(
          verified
              ? const PaywallPurchaseVerified()
              : const PaywallOperationFailed(
                  'Google Play did not confirm premium access. Please retry or restore purchases.',
                ),
        );
      case AdaptySdkRestoreStarted():
        _paywallEvents.add(const PaywallRestoreStarted());
      case AdaptySdkRestoreSucceeded(:final profile):
        final restored = _applyProfile(
          profile,
          expectedUserId: _identifiedUserId,
        );
        _paywallEvents.add(PaywallRestoreCompleted(hasPremium: restored));
      case AdaptySdkViewDismissed():
        _paywallEvents.add(const PaywallDismissed());
      case AdaptySdkFailed(:final message):
        _warnIfActive(message);
        _paywallEvents.add(PaywallOperationFailed(message));
    }
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
    _emitAccess(
      PremiumAccessSnapshot(
        userId: expectedUserId,
        status: profile.hasPremium
            ? PremiumAccessStatus.active
            : PremiumAccessStatus.inactive,
      ),
    );
    return profile.hasPremium;
  }

  void _warnIfActive(String message) {
    if (_currentAccess.isActive) {
      _emitAccess(_currentAccess.withWarning(message));
    }
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

  @override
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _profileSubscription?.cancel();
    await _eventSubscription?.cancel();
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
