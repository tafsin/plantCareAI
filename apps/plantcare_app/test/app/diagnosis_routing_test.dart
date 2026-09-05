import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_app/app/router/app_router.dart';
import 'package:plantcare_features/navigation.dart';

void main() {
  test('diagnosis routes are internal protected destinations', () {
    final paths = [
      AppRoutes.diagnoseObservation('plant 1', 'observation 1'),
      AppRoutes.diagnosisHistory('plant 1', 'observation 1'),
      AppRoutes.diagnosisDetails('plant 1', 'observation 1', 'diagnosis 1'),
    ];
    for (final path in paths) {
      expect(validatedProtectedDestination(path), path);
    }
  });
}
