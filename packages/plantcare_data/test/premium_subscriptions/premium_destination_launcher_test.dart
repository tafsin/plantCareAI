import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_data/src/premium_subscriptions/premium_destination_launcher.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';

void main() {
  final config = PremiumSubscriptionConfiguration(
    publicSdkKey: null,
    privacyPolicyUrl: Uri.parse('https://plantcare.example/privacy'),
    termsOfServiceUrl: Uri.parse('https://plantcare.example/terms'),
  );

  test(
    'opens product-specific and fallback Google Play destinations',
    () async {
      final external = _FakeLauncher();
      final launcher = UrlPremiumDestinationLauncher(
        config,
        launcher: external,
        platform: PurchasePlatform.android,
      );

      await launcher.openManageSubscription(productId: 'plantcare_premium');
      expect(external.lastUri?.queryParameters, {
        'sku': 'plantcare_premium',
        'package': 'com.tasnimalam.plantcare_ai',
      });

      await launcher.openManageSubscription();
      expect(external.lastUri?.query, isEmpty);
    },
  );

  test('opens configured HTTPS legal destinations', () async {
    final external = _FakeLauncher();
    final launcher = UrlPremiumDestinationLauncher(
      config,
      launcher: external,
      platform: PurchasePlatform.android,
    );

    await launcher.openPrivacyPolicy();
    expect(external.lastUri, config.privacyPolicyUrl);
    await launcher.openTermsOfService();
    expect(external.lastUri, config.termsOfServiceUrl);
  });

  test(
    'reports missing URL, launch failure, and unsupported management',
    () async {
      final external = _FakeLauncher()..result = false;
      final launcher = UrlPremiumDestinationLauncher(
        const PremiumSubscriptionConfiguration(
          publicSdkKey: null,
          privacyPolicyUrl: null,
          termsOfServiceUrl: null,
        ),
        launcher: external,
        platform: PurchasePlatform.web,
      );

      await expectLater(
        launcher.openPrivacyPolicy(),
        throwsA(isA<PremiumSubscriptionFailure>()),
      );
      await expectLater(
        launcher.openManageSubscription(),
        throwsA(isA<PremiumSubscriptionFailure>()),
      );

      final android = UrlPremiumDestinationLauncher(
        config,
        launcher: external,
        platform: PurchasePlatform.android,
      );
      await expectLater(
        android.openTermsOfService(),
        throwsA(isA<PremiumSubscriptionFailure>()),
      );
    },
  );
}

final class _FakeLauncher implements ExternalUriLauncher {
  bool result = true;
  Uri? lastUri;

  @override
  Future<bool> launch(Uri uri) async {
    lastUri = uri;
    return result;
  }
}
