import 'package:plantcare_shared/environment.dart';
import 'package:test/test.dart';

void main() {
  test('environment contract remains framework neutral', () {
    const config = _TestEnvironmentConfig();

    expect(config.environment, AppEnvironment.staging);
    expect(config.isProduction, isFalse);
    expect(config.useFirebaseAuthEmulator, isTrue);
    expect(config.useAppCheckDebug, isFalse);
    expect(config.appCheckRecaptchaEnterpriseSiteKey, 'site-key');
  });
}

final class _TestEnvironmentConfig implements EnvironmentConfig {
  const _TestEnvironmentConfig();

  @override
  String? get appCheckRecaptchaEnterpriseSiteKey => 'site-key';

  @override
  AppEnvironment get environment => AppEnvironment.staging;

  @override
  bool get isProduction => false;

  @override
  bool get useAppCheckDebug => false;

  @override
  bool get useFirebaseAuthEmulator => true;
}
