import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_app/app/config/compile_time_environment_config.dart';
import 'package:plantcare_shared/environment.dart';

void main() {
  test('compile-time configuration uses safe development defaults', () {
    const config = CompileTimeEnvironmentConfig();

    expect(config.environment, AppEnvironment.development);
    expect(config.isProduction, isFalse);
    expect(config.useFirebaseAuthEmulator, isFalse);
    expect(config.useAppCheckDebug, isFalse);
    expect(config.appCheckRecaptchaEnterpriseSiteKey, isNull);
    expect(config.premiumSubscription.canActivate, isFalse);
    expect(config.premiumSubscription.privacyPolicyUrl, isNull);
    expect(config.premiumSubscription.termsOfServiceUrl, isNull);
  });

  test('legal destinations accept only absolute HTTPS URLs', () {
    expect(parseHttpsUrl('https://plantcare.example/privacy')?.scheme, 'https');
    expect(parseHttpsUrl('http://plantcare.example/privacy'), isNull);
    expect(parseHttpsUrl('/privacy'), isNull);
    expect(parseHttpsUrl(''), isNull);
  });
}
