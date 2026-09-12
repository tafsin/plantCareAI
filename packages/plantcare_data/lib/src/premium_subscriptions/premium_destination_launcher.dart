import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:url_launcher/url_launcher.dart';

import 'adapty_premium_subscription_repository.dart'
    show currentPurchasePlatform;

abstract interface class ExternalUriLauncher {
  Future<bool> launch(Uri uri);
}

final class UrlLauncherExternalUriLauncher implements ExternalUriLauncher {
  const UrlLauncherExternalUriLauncher();

  @override
  Future<bool> launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

final class UrlPremiumDestinationLauncher
    implements PremiumDestinationLauncher {
  UrlPremiumDestinationLauncher(
    this._configuration, {
    ExternalUriLauncher? launcher,
    PurchasePlatform? platform,
  }) : _launcher = launcher ?? const UrlLauncherExternalUriLauncher(),
       _platform = platform ?? currentPurchasePlatformForLinks();

  final PremiumSubscriptionConfiguration _configuration;
  final ExternalUriLauncher _launcher;
  final PurchasePlatform _platform;

  @override
  bool get hasPrivacyPolicy => _configuration.privacyPolicyUrl != null;

  @override
  bool get hasTermsOfService => _configuration.termsOfServiceUrl != null;

  @override
  Future<void> openManageSubscription({String? productId}) async {
    if (_platform != PurchasePlatform.android) {
      throw const PremiumSubscriptionFailure(
        PremiumFailureType.unsupported,
        'Subscription management is available on Android.',
      );
    }
    final id = productId?.trim();
    final uri = id == null || id.isEmpty
        ? Uri.https('play.google.com', '/store/account/subscriptions')
        : Uri.https('play.google.com', '/store/account/subscriptions', {
            'sku': id,
            'package': PremiumSubscriptionIds.androidPackage,
          });
    await _open(uri, 'Google Play subscriptions could not be opened.');
  }

  @override
  Future<void> openPrivacyPolicy() =>
      _openConfigured(_configuration.privacyPolicyUrl, 'Privacy Policy');

  @override
  Future<void> openTermsOfService() =>
      _openConfigured(_configuration.termsOfServiceUrl, 'Terms');

  Future<void> _openConfigured(Uri? uri, String label) async {
    if (uri == null) {
      throw PremiumSubscriptionFailure(
        PremiumFailureType.configuration,
        '$label is not configured for this build.',
      );
    }
    await _open(uri, '$label could not be opened. Please try again.');
  }

  Future<void> _open(Uri uri, String message) async {
    if (!await _launcher.launch(uri)) {
      throw PremiumSubscriptionFailure(PremiumFailureType.launch, message);
    }
  }
}

PurchasePlatform currentPurchasePlatformForLinks() => currentPurchasePlatform();
