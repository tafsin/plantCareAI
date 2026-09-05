import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_app/app/bootstrap/firebase_app_check_activator.dart';
import 'package:plantcare_shared/environment.dart';

void main() {
  test('debug provider is used only when explicitly enabled', () async {
    final modes = <AppCheckActivationMode>[];
    final disabled = FirebaseAppCheckActivator(
      const _Config(),
      activateProviders: (mode, _) async => modes.add(mode),
    );
    final enabled = FirebaseAppCheckActivator(
      const _Config(useAppCheckDebug: true),
      activateProviders: (mode, _) async => modes.add(mode),
    );

    await disabled.activate(isReleaseMode: false, isWeb: true);
    await enabled.activate(isReleaseMode: false, isWeb: true);

    expect(modes, [AppCheckActivationMode.debug]);
  });

  test('release mode rejects a debug provider', () async {
    final activator = FirebaseAppCheckActivator(
      const _Config(useAppCheckDebug: true),
      activateProviders: (_, _) async {},
    );

    await expectLater(
      activator.activate(isReleaseMode: true, isWeb: false),
      throwsA(
        isA<AppConfigurationException>().having(
          (error) => error.message,
          'message',
          contains('not allowed'),
        ),
      ),
    );
  });

  test('web production requires a reCAPTCHA Enterprise site key', () async {
    final activator = FirebaseAppCheckActivator(
      const _Config(environment: AppEnvironment.production),
      activateProviders: (_, _) async {},
    );

    await expectLater(
      activator.activate(isReleaseMode: true, isWeb: true),
      throwsA(
        isA<AppConfigurationException>().having(
          (error) => error.message,
          'message',
          contains('APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY'),
        ),
      ),
    );
  });

  test('production selects platform production providers', () async {
    final calls = <(AppCheckActivationMode, String?)>[];
    final activator = FirebaseAppCheckActivator(
      const _Config(
        environment: AppEnvironment.production,
        siteKey: 'configured-site-key',
      ),
      activateProviders: (mode, key) async => calls.add((mode, key)),
    );

    await activator.activate(isReleaseMode: true, isWeb: true);

    expect(calls, [(AppCheckActivationMode.production, 'configured-site-key')]);
  });

  test('provider startup failures are replaced with safe details', () async {
    final activator = FirebaseAppCheckActivator(
      const _Config(useAppCheckDebug: true),
      activateProviders: (_, _) async =>
          throw StateError('sensitive provider details'),
    );

    await expectLater(
      activator.activate(isReleaseMode: false, isWeb: true),
      throwsA(
        isA<AppConfigurationException>()
            .having(
              (error) => error.message,
              'message',
              contains('could not start'),
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('sensitive')),
            ),
      ),
    );
  });
}

final class _Config implements EnvironmentConfig {
  const _Config({
    this.environment = AppEnvironment.development,
    this.useAppCheckDebug = false,
    this.siteKey,
  });

  @override
  final AppEnvironment environment;

  @override
  bool get isProduction => environment == AppEnvironment.production;

  @override
  bool get useFirebaseAuthEmulator => false;

  @override
  final bool useAppCheckDebug;

  final String? siteKey;

  @override
  String? get appCheckRecaptchaEnterpriseSiteKey => siteKey;
}
