import 'package:flutter/foundation.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:plantcare_shared/environment.dart';

final class CompileTimeEnvironmentConfig implements EnvironmentConfig {
  const CompileTimeEnvironmentConfig();

  static const _environmentName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const _useFirebaseAuthEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
  );
  static const _useAppCheckDebug = bool.fromEnvironment('USE_APP_CHECK_DEBUG');
  static const _appCheckRecaptchaEnterpriseSiteKey = String.fromEnvironment(
    'APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY',
  );
  static const _adaptyPublicSdkKey = String.fromEnvironment(
    'ADAPTY_PUBLIC_SDK_KEY',
  );
  static const _privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const _termsOfServiceUrl = String.fromEnvironment(
    'TERMS_OF_SERVICE_URL',
  );

  @override
  AppEnvironment get environment => switch (_environmentName) {
    'production' => AppEnvironment.production,
    'staging' => AppEnvironment.staging,
    _ => AppEnvironment.development,
  };

  @override
  bool get isProduction => environment == AppEnvironment.production;

  @override
  bool get useFirebaseAuthEmulator =>
      _useFirebaseAuthEmulator && !isProduction && !kReleaseMode;

  @override
  bool get useAppCheckDebug => _useAppCheckDebug;

  @override
  String? get appCheckRecaptchaEnterpriseSiteKey {
    final value = _appCheckRecaptchaEnterpriseSiteKey.trim();
    return value.isEmpty ? null : value;
  }

  PremiumSubscriptionConfiguration get premiumSubscription =>
      PremiumSubscriptionConfiguration(
        publicSdkKey: _nonEmpty(_adaptyPublicSdkKey),
        privacyPolicyUrl: parseHttpsUrl(_privacyPolicyUrl),
        termsOfServiceUrl: parseHttpsUrl(_termsOfServiceUrl),
      );

  static String? _nonEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

Uri? parseHttpsUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}
