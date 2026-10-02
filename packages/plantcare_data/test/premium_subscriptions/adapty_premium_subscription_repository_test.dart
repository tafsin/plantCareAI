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
  final now = DateTime.utc(2026, 10);
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
      now: () => now,
    );
  });

  tearDown(() async {
    await repository.dispose();
    await session.dispose();
  });

  test(
    'activates before profile and custom paywall product retrieval',
    () async {
      await repository.initialize();
      final result = await repository.preparePaywall();

      expect(result.availability, PaywallAvailability.ready);
      expect(result.offer?.localizedTitle, 'PlantCare Premium Monthly');
      expect(result.offer?.localizedPrice, r'$1.99');
      expect(result.offer?.billingPeriod, 'month');
      expect(sdk.calls, [
        'activate:user-1',
        'profile',
        'flow:plantcare_main_paywall',
        'products',
      ]);
    },
  );

  test('custom paywall does not require builder view configuration', () async {
    await repository.initialize();

    expect(
      (await repository.preparePaywall()).availability,
      PaywallAvailability.ready,
    );
    expect(sdk.calls, isNot(contains('present')));
  });

  test('selects expected product by identifiers instead of position', () async {
    sdk.products = [
      _product(productId: 'other'),
      _product(),
      _product(basePlanId: 'annual'),
    ];
    await repository.initialize();
    final result = await repository.preparePaywall();
    await repository.purchase();

    expect(result.offer?.productId, PremiumSubscriptionIds.product);
    expect(sdk.purchasedHandle, 'expected-handle');
  });

  test('rejects wrong plan, offer, missing title, price, and period', () async {
    await repository.initialize();
    final invalid = [
      _product(productId: 'other'),
      _product(basePlanId: 'annual'),
      _product(hasOffer: true),
      _product(localizedTitle: null),
      _product(localizedPrice: null),
      _product(localizedPeriod: null),
    ];

    for (final product in invalid) {
      sdk.products = [product];
      final result = await repository.preparePaywall();
      expect(result.availability, PaywallAvailability.productUnavailable);
      expect(result.failureType, PremiumFailureType.productUnavailable);
    }
  });

  test('network and placement failures remain typed', () async {
    await repository.initialize();
    sdk.flowError = const AdaptySdkFailure(AdaptySdkFailureType.network);
    var result = await repository.preparePaywall();
    expect(result.failureType, PremiumFailureType.network);

    sdk.flowError = const AdaptySdkFailure(AdaptySdkFailureType.other);
    result = await repository.preparePaywall();
    expect(result.failureType, PremiumFailureType.paywallUnavailable);
  });

  for (final platform in [PurchasePlatform.web, PurchasePlatform.ios]) {
    test('$platform never invokes the Adapty SDK', () async {
      final unsupportedSdk = _FakeAdapty();
      final unsupported = AdaptyPremiumSubscriptionRepository(
        session,
        configuration,
        sdk: unsupportedSdk,
        platform: platform,
      );
      addTearDown(unsupported.dispose);

      await unsupported.initialize();
      expect(
        (await unsupported.preparePaywall()).availability,
        PaywallAvailability.unsupported,
      );
      await expectLater(
        unsupported.purchase(),
        throwsA(
          isA<PremiumSubscriptionFailure>().having(
            (error) => error.type,
            'type',
            PremiumFailureType.unsupported,
          ),
        ),
      );
      await expectLater(
        unsupported.restorePurchases(),
        throwsA(isA<PremiumSubscriptionFailure>()),
      );
      expect(unsupportedSdk.calls, isEmpty);
    });
  }

  test('missing public key is non-fatal and typed as configuration', () async {
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
    final result = await missing.preparePaywall();
    expect(result.availability, PaywallAvailability.configurationUnavailable);
    expect(result.failureType, PremiumFailureType.configuration);
    expect(missingSdk.calls, isEmpty);
  });

  test('account changes serialize logout, identify, and refresh', () async {
    await repository.initialize();
    await repository.preparePaywall();
    session.emit(const AppUser(uid: 'user-2', email: null));
    await Future<void>.delayed(Duration.zero);
    await repository.preparePaywall();

    expect(
      sdk.calls,
      containsAllInOrder(['logout', 'identify:user-2', 'profile']),
    );
    expect(repository.currentAccess.userId, 'user-2');
  });

  test('sign-out clears access and retained product', () async {
    await repository.initialize();
    await repository.preparePaywall();
    session.emit(null);
    await Future<void>.delayed(Duration.zero);

    expect(repository.currentAccess, const PremiumAccessSnapshot.signedOut());
    await expectLater(
      repository.purchase(),
      throwsA(isA<PremiumSubscriptionFailure>()),
    );
    expect(sdk.calls.where((call) => call == 'purchase'), isEmpty);
  });

  test('discards product retrieval when Firebase UID changes', () async {
    await repository.initialize();
    final flowCompletion = Completer<AdaptySdkFlow>();
    sdk.flowCompletion = flowCompletion;
    final preparation = repository.preparePaywall();
    await Future<void>.delayed(Duration.zero);

    session.emit(const AppUser(uid: 'user-2', email: null));
    await Future<void>.delayed(Duration.zero);
    flowCompletion.complete(sdk.flow);

    expect((await preparation).failureType, PremiumFailureType.notReady);
    expect(sdk.calls.where((call) => call == 'products'), isEmpty);
  });

  test('purchase verifies active unexpired returned profile', () async {
    await repository.initialize();
    await repository.preparePaywall();
    sdk.purchaseResult = AdaptySdkPurchaseSuccess(
      _profile(active: true, expiresAt: now.add(const Duration(days: 30))),
    );

    expect(await repository.purchase(), const PremiumPurchaseVerified());
    expect(repository.currentAccess.isActive, isTrue);
  });

  test(
    'inactive purchase result checks current profile exactly once',
    () async {
      await repository.initialize();
      await repository.preparePaywall();
      sdk.purchaseResult = AdaptySdkPurchaseSuccess(_profile(active: false));
      sdk.profile = _profile(
        active: true,
        expiresAt: now.add(const Duration(days: 1)),
      );
      final profileCallsBefore = sdk.calls
          .where((call) => call == 'profile')
          .length;

      expect(await repository.purchase(), const PremiumPurchaseVerified());
      expect(
        sdk.calls.where((call) => call == 'profile').length,
        profileCallsBefore + 1,
      );
    },
  );

  test('unverified purchase throws invalid entitlement', () async {
    await repository.initialize();
    await repository.preparePaywall();
    sdk.purchaseResult = AdaptySdkPurchaseSuccess(_profile(active: false));
    sdk.profile = _profile(active: false);

    await expectLater(
      repository.purchase(),
      throwsA(
        isA<PremiumSubscriptionFailure>().having(
          (error) => error.type,
          'type',
          PremiumFailureType.invalidEntitlement,
        ),
      ),
    );
    expect(repository.currentAccess.isActive, isFalse);
  });

  test('maps pending, cancellation, network, and purchase failure', () async {
    await repository.initialize();
    await repository.preparePaywall();
    sdk.purchaseResult = const AdaptySdkPurchasePending();
    expect(await repository.purchase(), const PremiumPurchasePending());

    sdk.purchaseResult = const AdaptySdkPurchaseCancelled();
    expect(await repository.purchase(), const PremiumPurchaseCancelled());

    sdk.purchaseError = const AdaptySdkFailure(AdaptySdkFailureType.network);
    await expectLater(
      repository.purchase(),
      throwsA(
        isA<PremiumSubscriptionFailure>().having(
          (error) => error.type,
          'type',
          PremiumFailureType.network,
        ),
      ),
    );

    sdk.purchaseError = const AdaptySdkFailure(AdaptySdkFailureType.other);
    await expectLater(
      repository.purchase(),
      throwsA(
        isA<PremiumSubscriptionFailure>().having(
          (error) => error.type,
          'type',
          PremiumFailureType.purchaseFailed,
        ),
      ),
    );
  });

  test('active with no expiration is premium', () async {
    await repository.initialize();
    sdk.emitProfile(_profile(active: true));
    await Future<void>.delayed(Duration.zero);

    expect(repository.currentAccess.isActive, isTrue);
  });

  test('expired active flag does not grant premium', () async {
    await repository.initialize();
    sdk.emitProfile(
      _profile(
        active: true,
        expiresAt: now.subtract(const Duration(seconds: 1)),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(repository.currentAccess.isActive, isFalse);
  });

  test('refresh failure preserves verified premium with warning', () async {
    await repository.initialize();
    sdk.emitProfile(_profile(active: true));
    await Future<void>.delayed(Duration.zero);
    sdk.profileError = const AdaptySdkFailure(AdaptySdkFailureType.network);

    await expectLater(
      repository.refreshProfile(),
      throwsA(isA<AdaptySdkFailure>()),
    );
    expect(repository.currentAccess.isActive, isTrue);
    expect(repository.currentAccess.warningMessage, isNotNull);
  });

  test(
    'restore verifies active access and reports no-access neutrally',
    () async {
      await repository.initialize();
      sdk.restoreProfile = _profile(active: true);
      expect((await repository.restorePurchases()).hasPremium, isTrue);

      sdk.restoreProfile = _profile(active: false);
      expect((await repository.restorePurchases()).hasPremium, isFalse);
    },
  );

  test('restore failure is typed and recoverable', () async {
    await repository.initialize();
    sdk.restoreError = const AdaptySdkFailure(AdaptySdkFailureType.other);

    await expectLater(
      repository.restorePurchases(),
      throwsA(
        isA<PremiumSubscriptionFailure>().having(
          (error) => error.type,
          'type',
          PremiumFailureType.restorationFailed,
        ),
      ),
    );
  });
}

AdaptySdkProfile _profile({
  bool active = false,
  DateTime? expiresAt,
  String customerUserId = 'user-1',
}) => AdaptySdkProfile(
  customerUserId: customerUserId,
  isPremiumActive: active,
  premiumExpiresAt: expiresAt,
);

AdaptySdkProduct _product({
  String productId = PremiumSubscriptionIds.product,
  String? basePlanId = PremiumSubscriptionIds.basePlan,
  String? localizedTitle = 'PlantCare Premium Monthly',
  String? localizedPrice = r'$1.99',
  String? localizedPeriod = 'month',
  bool hasOffer = false,
  Object handle = 'expected-handle',
}) => AdaptySdkProduct(
  handle: handle,
  vendorProductId: productId,
  basePlanId: basePlanId,
  localizedTitle: localizedTitle,
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
  AdaptySdkFlow flow = const AdaptySdkFlow(handle: 'flow');
  List<AdaptySdkProduct> products = [_product()];
  AdaptySdkProfile profile = _profile();
  AdaptySdkProfile restoreProfile = _profile();
  AdaptySdkPurchaseResult purchaseResult = AdaptySdkPurchaseSuccess(
    _profile(active: true),
  );
  Object? flowError;
  Object? profileError;
  Object? purchaseError;
  Object? restoreError;
  Object? purchasedHandle;
  Completer<AdaptySdkFlow>? flowCompletion;

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
  Future<void> identify(String customerUserId) async {
    calls.add('identify:$customerUserId');
    profile = _profile(customerUserId: customerUserId);
    restoreProfile = _profile(customerUserId: customerUserId);
  }

  @override
  Future<void> logout() async => calls.add('logout');

  @override
  Future<AdaptySdkProfile> getProfile() async {
    calls.add('profile');
    if (profileError case final Object error) throw error;
    return profile;
  }

  @override
  Future<AdaptySdkFlow> getFlow(String placementId) async {
    calls.add('flow:$placementId');
    if (flowError case final Object error) throw error;
    return flowCompletion?.future ?? flow;
  }

  @override
  Future<List<AdaptySdkProduct>> getProducts(AdaptySdkFlow flow) async {
    calls.add('products');
    return products;
  }

  @override
  Future<AdaptySdkPurchaseResult> makePurchase(AdaptySdkProduct product) async {
    calls.add('purchase');
    purchasedHandle = product.handle;
    if (purchaseError case final Object error) throw error;
    return purchaseResult;
  }

  @override
  Future<AdaptySdkProfile> restorePurchases() async {
    calls.add('restore');
    if (restoreError case final Object error) throw error;
    return restoreProfile;
  }

  void emitProfile(AdaptySdkProfile value) => _profiles.add(value);

  @override
  Future<void> dispose() => _profiles.close();
}
