import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/app/bootstrap/app_initializer.dart';
import 'package:plantcare_ai/app/dependency_injection/injection.dart';

void main() {
  tearDown(() async {
    await getIt.reset();
  });

  test('resolves the app initializer before Firebase is initialized', () {
    configureDependencies();

    expect(() => getIt<AppInitializer>(), returnsNormally);
  });
}
