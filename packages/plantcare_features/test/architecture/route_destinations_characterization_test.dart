import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/care_history.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:plantcare_features/src/navigation/app_routes.dart';

void main() {
  test('static destinations remain stable', () {
    expect(AppRoutes.home, '/');
    expect(AppRoutes.plants, '/plants');
    expect(AppRoutes.newPlant, '/plants/new');
    expect(AppRoutes.reminders, '/reminders');
    expect(AppRoutes.privacySafety, '/privacy-safety');
    expect(AppRoutes.signIn, '/sign-in');
    expect(AppRoutes.register, '/register');
    expect(AppRoutes.forgotPassword, '/forgot-password');
  });

  test('parameterized destinations encode path and query values', () {
    expect(AppRoutes.plantDetails('plant / 1'), '/plants/plant%20%2F%201');
    expect(AppRoutes.editPlant('plant / 1'), '/plants/plant%20%2F%201/edit');
    expect(
      AppRoutes.newCareLog('plant / 1', CareLogType.fertilizing),
      '/plants/plant%20%2F%201/care/new?type=fertilizing',
    );
    expect(
      AppRoutes.observationDetails('plant / 1', 'observation / 1'),
      '/plants/plant%20%2F%201/observations/observation%20%2F%201',
    );
    expect(
      AppRoutes.diagnosisDetails('plant', 'observation', 'diagnosis / 1'),
      '/plants/plant/observations/observation/diagnoses/diagnosis%20%2F%201',
    );
    expect(
      AppRoutes.newReminder(
        'plant',
        source: ReminderSource.soilCheckSuggestion,
        referenceId: 'soil / 1',
        suggestedAt: DateTime.utc(2030, 1, 2, 3, 4, 5),
      ),
      '/plants/plant/reminders/new?source=soil_check_suggestion&referenceId=soil+%2F+1&suggestedAt=2030-01-02T03%3A04%3A05.000Z',
    );
  });
}
