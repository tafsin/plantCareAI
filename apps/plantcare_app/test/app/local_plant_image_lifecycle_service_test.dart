import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_app/app/application/local_plant_image_lifecycle_service.dart';
import 'package:plantcare_domain/authentication.dart';

import '../helpers/fake_authentication_repository.dart';
import '../helpers/fake_local_plant_image_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cleans local images on startup, sign-in, and resume', () async {
    final auth = FakeAuthenticationRepository();
    final images = FakeLocalPlantImageRepository();
    auth.emitAuthState(const AppUser(uid: 'user-a', email: null));
    final service = LocalPlantImageLifecycleService(auth, images);

    await service.start().timeout(const Duration(seconds: 1));
    expect(images.cleanupCalls, 1);

    auth.emitAuthState(const AppUser(uid: 'user-b', email: null));
    await Future<void>.delayed(Duration.zero);
    expect(images.cleanupCalls, 2);

    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(images.cleanupCalls, 3);

    await service.dispose().timeout(const Duration(seconds: 1));
    await auth.close().timeout(const Duration(seconds: 1));
  });
}
