import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/app/config/compile_time_environment_config.dart';
import 'package:plantcare_shared/environment.dart';

void main() {
  test('compile-time configuration uses safe development defaults', () {
    const config = CompileTimeEnvironmentConfig();

    expect(config.environment, AppEnvironment.development);
    expect(config.isProduction, isFalse);
    expect(config.useFirebaseAuthEmulator, isFalse);
    expect(config.useAppCheckDebug, isFalse);
    expect(config.appCheckRecaptchaEnterpriseSiteKey, isNull);
  });
}
