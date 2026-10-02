import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_app/app/application/premium_subscription_lifecycle_service.dart';
import 'package:plantcare_domain/authentication.dart';

import '../helpers/fake_authentication_repository.dart';
import '../helpers/fake_premium_dependencies.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('refreshes the signed-in profile when the app resumes', () async {
    final auth = FakeAuthenticationRepository();
    final subscriptions = FakePremiumSubscriptionRepository();
    auth.emitAuthState(const AppUser(uid: 'user-a', email: null));
    final service = PremiumSubscriptionLifecycleService(auth, subscriptions);

    await service.start();
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(subscriptions.refreshCalls, 1);

    await service.dispose();
    await subscriptions.dispose();
    await auth.close();
  });

  test('does not refresh a signed-out session', () async {
    final auth = FakeAuthenticationRepository();
    final subscriptions = FakePremiumSubscriptionRepository();
    final service = PremiumSubscriptionLifecycleService(auth, subscriptions);

    await service.start();
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(subscriptions.refreshCalls, 0);

    await service.dispose();
    await subscriptions.dispose();
    await auth.close();
  });
}
