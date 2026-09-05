import 'package:flutter/foundation.dart';
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
}
