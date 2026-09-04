import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:plantcare_ai/core/utils/environment_config.dart';

enum AppCheckActivationMode { disabled, debug, production }

final class AppConfigurationException implements Exception {
  const AppConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigurationException: $message';
}

typedef ActivateAppCheckProviders = Future<void> Function(
  AppCheckActivationMode mode,
  String? recaptchaEnterpriseSiteKey,
);

final class FirebaseAppCheckActivator {
  FirebaseAppCheckActivator(
    this._environmentConfig, {
    ActivateAppCheckProviders? activateProviders,
  }) : _activateProviders = activateProviders ?? _activateFirebaseAppCheck;

  final EnvironmentConfig _environmentConfig;
  final ActivateAppCheckProviders _activateProviders;

  Future<void> activate({
    bool isReleaseMode = kReleaseMode,
    bool isWeb = kIsWeb,
  }) async {
    final mode = _activationMode(isReleaseMode: isReleaseMode);
    if (mode == AppCheckActivationMode.disabled) return;

    final siteKey = _environmentConfig.appCheckRecaptchaEnterpriseSiteKey;
    if (mode == AppCheckActivationMode.production && isWeb && siteKey == null) {
      throw const AppConfigurationException(
        'Production App Check on web requires '
        'APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY.',
      );
    }
    try {
      await _activateProviders(mode, siteKey);
    } on AppConfigurationException {
      rethrow;
    } catch (_) {
      throw const AppConfigurationException(
        'Firebase App Check could not start. Check the platform '
        'configuration and try again.',
      );
    }
  }

  AppCheckActivationMode _activationMode({required bool isReleaseMode}) {
    if (_environmentConfig.useAppCheckDebug) {
      if (isReleaseMode) {
        throw const AppConfigurationException(
          'USE_APP_CHECK_DEBUG=true is not allowed in a release build.',
        );
      }
      return AppCheckActivationMode.debug;
    }
    return _environmentConfig.isProduction
        ? AppCheckActivationMode.production
        : AppCheckActivationMode.disabled;
  }

  static Future<void> _activateFirebaseAppCheck(
    AppCheckActivationMode mode,
    String? siteKey,
  ) async {
    switch (mode) {
      case AppCheckActivationMode.disabled:
        return;
      case AppCheckActivationMode.debug:
        await FirebaseAppCheck.instance.activate(
          providerWeb: WebDebugProvider(),
          providerAndroid: const AndroidDebugProvider(),
          providerApple: const AppleDebugProvider(),
        );
        return;
      case AppCheckActivationMode.production:
        await FirebaseAppCheck.instance.activate(
          providerWeb: kIsWeb ? ReCaptchaEnterpriseProvider(siteKey!) : null,
          providerAndroid: const AndroidPlayIntegrityProvider(),
          providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
        return;
    }
  }
}
