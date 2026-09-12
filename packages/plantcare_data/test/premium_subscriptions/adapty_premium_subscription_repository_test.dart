import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_data/src/premium_subscriptions/adapty_premium_subscription_repository.dart';
import 'package:plantcare_data/src/premium_subscriptions/adapty_sdk_facade.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';

void main() {
  const configuration = PremiumSubscriptionConfiguration(
    publicSdkKey: 'public-key',
    privacyPolicyUrl: null,
    termsOfServiceUrl: null,
  );
  late _FakeSession session;
  late _FakeAdapty sdk;
  late AdaptyPremiumSubscriptionRepository repository;

  setUp(() {
    session = _FakeSession(
      const AppUser(uid: 'user-1', email: 'user@example.com'),
    );
    sdk = _FakeAdapty();
    repository = AdaptyPremiumSubscriptionRepository(
      session,
      configuration,
      sdk: sdk,
      platform: PurchasePlatform.android,
    );
  });

  tearDown(() async {
    await repository.dispose();
    await session.dispose();
  });

  test(
    'activates with current UID before retrieving profile and Flow',
    () async {
      await repository.initialize();
      final result = await repository.preparePaywall();

      expect(result.availability, PaywallAvailability.ready);
      expect(result.offer?.localizedPrice, r'$1.99');
      expect(result.offer?.billingPeriod, 'month');
      expect(sdk.calls, [
        'activate:user-1',
        'profile',
        'flow:main_paywall',
        'products',
      ]);
    },
  );

  test(
    'distinguishes missing view configuration from missing product',
    () async {
      sdk.flow = const AdaptySdkFlow(
        handle: 'flow',
        hasViewConfiguration: false,
      );
      await repository.initialize();
      expect(
        (await repository.preparePaywall()).availability,
        PaywallAvailability.paywallUnavailable,
      );

      sdk.flow = const AdaptySdkFlow(
        handle: 'flow',
        hasViewConfiguration: true,
      );
      sdk.products = const [];
      expect(
        (await repository.preparePaywall()).availability,
        PaywallAvailability.productUnavailable,
      );
    },
  );

  test(
    'rejects wrong plan, an offer, missing price, and missing period',
    () async {
      await repository.initialize();
      final invalid = [
        _product(productId: 'other'),
        _product(basePlanId: 'annual'),
        _product(hasOffer: true),
        _product(localizedPrice: null),
        _product(localizedPeriod: null),
      ];

      for (final product in invalid) {
        sdk.products = [product];
        expect(
          (await repository.preparePaywall()).availability,
          PaywallAvailability.productUnavailable,
        );
      }
    },
  );

  test('non-Android boundary never activates or retrieves', () async {
    final unsupportedSdk = _FakeAdapty();
    final unsupported = AdaptyPremiumSubscriptionRepository(
      session,
      configuration,
      sdk: unsupportedSdk,
      platform: PurchasePlatform.web,
    );
    addTearDown(unsupported.dispose);

    await unsupported.initialize();
    expect(
      (await unsupported.preparePaywall()).availability,
      PaywallAvailability.unsupported,
    );
    expect(unsupportedSdk.calls, isEmpty);
  });

  test(
    'missing public key is non-fatal and reported as configuration',
    () async {
      final missingSdk = _FakeAdapty();
      final missing = AdaptyPremiumSubscriptionRepository(
        session,
        const PremiumSubscriptionConfiguration(
          publicSdkKey: null,
          privacyPolicyUrl: null,
          termsOfServiceUrl: null,
        ),
        sdk: missingSdk,
        platform: PurchasePlatform.android,
      );
      addTearDown(missing.dispose);

      await missing.initialize();
      expect(
        (await missing.preparePaywall()).availability,
        PaywallAvailability.configurationUnavailable,
      );
      expect(missingSdk.calls, isEmpty);
    },
  );

  test(
    'account changes serialize logout, identify, and profile refresh',
    () async {
      await repository.initialize();
      session.emit(const AppUser(uid: 'user-2', email: null));
      await Future<void>.delayed(Duration.zero);
      await repository.preparePaywall();

      expect(
        sdk.calls,
        containsAllInOrder(['logout', 'identify:user-2', 'profile']),
      );
      expect(repository.currentAccess.userId, 'user-2');
    },
  );

  test('operations wait for an identified signed-in user', () async {
    final signedOutSession = _FakeSession(null);
    final signedOutSdk = _FakeAdapty();
    final signedOutRepository = AdaptyPremiumSubscriptionRepository(
      signedOutSession,
      configuration,
      sdk: signedOutSdk,
      platform: PurchasePlatform.android,
    );
    addTearDown(signedOutRepository.dispose);
    addTearDown(signedOutSession.dispose);

    await signedOutRepository.initialize();
    expect(
      (await signedOutRepository.preparePaywall()).availability,
      PaywallAvailability.paywallUnavailable,
    );
    expect(signedOutSdk.calls, ['activate:null']);

    signedOutSession.emit(const AppUser(uid: 'user-2', email: null));
    await Future<void>.delayed(Duration.zero);
    expect(
      (await signedOutRepository.preparePaywall()).availability,
      PaywallAvailability.ready,
    );
    expect(
      signedOutSdk.calls,
      containsAllInOrder(['identify:user-2', 'profile', 'flow:main_paywall']),
    );
  });

  test('discards a Flow result when the Firebase UID changes', () async {
    await repository.initialize();
    final flowCompletion = Completer<AdaptySdkFlow>();
    sdk.flowCompletion = flowCompletion;
    final preparation = repository.preparePaywall();
    await Future<void>.delayed(Duration.zero);

    session.emit(const AppUser(uid: 'user-2', email: null));
    await Future<void>.delayed(Duration.zero);
    flowCompletion.complete(sdk.flow);

    expect(
      (await preparation).availability,
      PaywallAvailability.paywallUnavailable,
    );
    expect(sdk.calls.where((call) => call == 'products'), isEmpty);
  });

  test('verified purchase is emitted only from an active profile', () async {
    await repository.initialize();
    final events = <PaywallEvent>[];
    final subscription = repository.paywallEvents.listen(events.add);
    addTearDown(subscription.cancel);

    sdk.emitEvent(
      const AdaptySdkPurchaseSucceeded(
        AdaptySdkProfile(customerUserId: 'user-1', hasPremium: true),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(repository.currentAccess.isActive, isTrue);
    expect(events, contains(isA<PaywallPurchaseVerified>()));
  });

  test(
    'inactive success checks current profile before refusing access',
    () async {
      await repository.initialize();
      sdk.profile = const AdaptySdkProfile(
        customerUserId: 'user-1',
        hasPremium: false,
      );
      final events = <PaywallEvent>[];
      final subscription = repository.paywallEvents.listen(events.add);
      addTearDown(subscription.cancel);

      sdk.emitEvent(
        const AdaptySdkPurchaseSucceeded(
          AdaptySdkProfile(customerUserId: 'user-1', hasPremium: false),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.currentAccess.isActive, isFalse);
      expect(events, contains(isA<PaywallOperationFailed>()));
    },
  );

  test('later failure preserves verified premium with warning', () async {
    await repository.initialize();
    sdk.emitProfile(
      const AdaptySdkProfile(customerUserId: 'user-1', hasPremium: true),
    );
    await Future<void>.delayed(Duration.zero);
    sdk.profileError = StateError('offline');

    await expectLater(repository.refreshProfile(), throwsStateError);

    expect(repository.currentAccess.isActive, isTrue);
    expect(repository.currentAccess.warningMessage, isNotNull);
  });

  test('a newer inactive profile expires previously active access', () async {
    await repository.initialize();
    sdk.emitProfile(
      const AdaptySdkProfile(customerUserId: 'user-1', hasPremium: true),
    );
    await Future<void>.delayed(Duration.zero);
    sdk.emitProfile(
      const AdaptySdkProfile(customerUserId: 'user-1', hasPremium: false),
    );
    await Future<void>.delayed(Duration.zero);

    expect(repository.currentAccess.status, PremiumAccessStatus.inactive);
  });

  test(
    'restore verifies active access and reports no-access neutrally',
    () async {
      await repository.initialize();
      sdk.restoreProfile = const AdaptySdkProfile(
        customerUserId: 'user-1',
        hasPremium: true,
      );
      expect((await repository.restorePurchases()).hasPremium, isTrue);

      sdk.restoreProfile = const AdaptySdkProfile(
        customerUserId: 'user-1',
        hasPremium: false,
      );
      expect((await repository.restorePurchases()).hasPremium, isFalse);
    },
  );

  test('restore failure is recoverable and emits a failure event', () async {
    await repository.initialize();
    sdk.restoreError = StateError('offline');
    final events = <PaywallEvent>[];
    final subscription = repository.paywallEvents.listen(events.add);
    addTearDown(subscription.cancel);

    await expectLater(
      repository.restorePurchases(),
      throwsA(isA<PremiumSubscriptionFailure>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events, contains(isA<PaywallOperationFailed>()));
  });

  test(
    'maps purchase, restore, dismissal, failure and profile events',
    () async {
      await repository.initialize();
      final events = <PaywallEvent>[];
      final subscription = repository.paywallEvents.listen(events.add);
      addTearDown(subscription.cancel);

      sdk
        ..emitEvent(const AdaptySdkPurchaseStarted())
        ..emitEvent(const AdaptySdkPurchasePending())
        ..emitEvent(const AdaptySdkPurchaseCancelled())
        ..emitEvent(const AdaptySdkRestoreStarted())
        ..emitEvent(
          const AdaptySdkRestoreSucceeded(
            AdaptySdkProfile(customerUserId: 'user-1', hasPremium: true),
          ),
        )
        ..emitEvent(const AdaptySdkViewDismissed())
        ..emitEvent(const AdaptySdkFailed('recoverable'));
      sdk.emitProfile(
        const AdaptySdkProfile(customerUserId: 'user-1', hasPremium: true),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        events,
        containsAll([
          isA<PaywallPurchaseStarted>(),
          isA<PaywallPurchasePending>(),
          isA<PaywallPurchaseCancelled>(),
          isA<PaywallRestoreStarted>(),
          isA<PaywallRestoreCompleted>(),
          isA<PaywallDismissed>(),
          isA<PaywallOperationFailed>(),
        ]),
      );
      expect(repository.currentAccess.isActive, isTrue);
    },
  );

  test('unsupported presentation and restore never call the SDK', () async {
    final unsupportedSdk = _FakeAdapty();
    final unsupported = AdaptyPremiumSubscriptionRepository(
      session,
      configuration,
      sdk: unsupportedSdk,
      platform: PurchasePlatform.ios,
    );
    addTearDown(unsupported.dispose);

    await expectLater(
      unsupported.presentPaywall(),
      throwsA(isA<PremiumSubscriptionFailure>()),
    );
    await expectLater(
      unsupported.restorePurchases(),
      throwsA(isA<PremiumSubscriptionFailure>()),
    );
    expect(unsupportedSdk.calls, isEmpty);
  });

  test('every presentation creates a facade presentation request', () async {
    await repository.initialize();
    await repository.preparePaywall();

    await repository.presentPaywall();
    await repository.presentPaywall();

    expect(sdk.calls.where((call) => call == 'present'), hasLength(2));
  });
}

AdaptySdkProduct _product({
  String productId = PremiumSubscriptionIds.product,
  String? basePlanId = PremiumSubscriptionIds.basePlan,
  String? localizedPrice = r'$1.99',
  String? localizedPeriod = 'month',
  bool hasOffer = false,
}) => AdaptySdkProduct(
  vendorProductId: productId,
  basePlanId: basePlanId,
  localizedPrice: localizedPrice,
  localizedPeriod: localizedPeriod,
  hasOffer: hasOffer,
);

final class _FakeSession implements AuthenticationSession {
  _FakeSession(this._current);

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  AppUser? get currentUser => _current;

  @override
  bool get isSignedIn => _current != null;

  void emit(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  Future<void> dispose() => _controller.close();
}

final class _FakeAdapty implements AdaptySdkFacade {
  final calls = <String>[];
  final _profiles = StreamController<AdaptySdkProfile>.broadcast();
  final _events = StreamController<AdaptySdkEvent>.broadcast();
  AdaptySdkFlow flow = const AdaptySdkFlow(
    handle: 'flow',
    hasViewConfiguration: true,
  );
  List<AdaptySdkProduct> products = [_product()];
  AdaptySdkProfile profile = const AdaptySdkProfile(
    customerUserId: 'user-1',
    hasPremium: false,
  );
  AdaptySdkProfile restoreProfile = const AdaptySdkProfile(
    customerUserId: 'user-1',
    hasPremium: false,
  );
  Object? profileError;
  Object? restoreError;
  Completer<AdaptySdkFlow>? flowCompletion;

  @override
  Stream<AdaptySdkEvent> get events => _events.stream;

  @override
  Stream<AdaptySdkProfile> get profileUpdates => _profiles.stream;

  @override
  Future<void> activate({
    required String apiKey,
    String? customerUserId,
  }) async {
    calls.add('activate:$customerUserId');
  }

  @override
  Future<AdaptySdkFlow> getFlow(String placementId) async {
    calls.add('flow:$placementId');
    return flowCompletion?.future ?? flow;
  }

  @override
  Future<List<AdaptySdkProduct>> getProducts(AdaptySdkFlow flow) async {
    calls.add('products');
    return products;
  }

  @override
  Future<AdaptySdkProfile> getProfile() async {
    calls.add('profile');
    if (profileError case final Object error) throw error;
    return profile;
  }

  @override
  Future<void> identify(String customerUserId) async {
    calls.add('identify:$customerUserId');
    profile = AdaptySdkProfile(
      customerUserId: customerUserId,
      hasPremium: false,
    );
  }

  @override
  Future<void> logout() async => calls.add('logout');

  @override
  Future<void> present(AdaptySdkFlow flow) async => calls.add('present');

  @override
  Future<AdaptySdkProfile> restorePurchases() async {
    calls.add('restore');
    if (restoreError case final Object error) throw error;
    return restoreProfile;
  }

  void emitEvent(AdaptySdkEvent event) => _events.add(event);

  void emitProfile(AdaptySdkProfile profile) => _profiles.add(profile);

  @override
  Future<void> dispose() async {
    await _profiles.close();
    await _events.close();
  }
}
