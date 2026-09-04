enum AppEnvironment { development, staging, production }

abstract interface class EnvironmentConfig {
  AppEnvironment get environment;

  bool get isProduction;

  bool get useFirebaseAuthEmulator;

  bool get useAppCheckDebug;

  String? get appCheckRecaptchaEnterpriseSiteKey;
}
