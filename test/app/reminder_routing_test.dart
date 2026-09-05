import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:plantcare_features/navigation.dart';

void main() {
  test('reminder dashboard, forms, and details are protected destinations', () {
    expect(
      validatedProtectedDestination(AppRoutes.reminders),
      AppRoutes.reminders,
    );
    expect(
      validatedProtectedDestination(AppRoutes.plantReminders('plant-1')),
      AppRoutes.plantReminders('plant-1'),
    );
    expect(
      validatedProtectedDestination(
        AppRoutes.reminderDetails('plant-1', 'reminder-1'),
      ),
      AppRoutes.reminderDetails('plant-1', 'reminder-1'),
    );
    final suggestion = AppRoutes.newReminder(
      'plant-1',
      source: ReminderSource.soilCheckSuggestion,
      referenceId: 'soil-1',
      suggestedAt: DateTime.utc(2030),
    );
    expect(validatedProtectedDestination(suggestion), suggestion);
  });

  test('rejects malformed reminder suggestion redirects', () {
    expect(
      validatedProtectedDestination(
        '/plants/plant-1/reminders/new?source=soil_check_suggestion',
      ),
      isNull,
    );
    expect(
      validatedProtectedDestination(
        '/plants/plant-1/reminders/new?source=ai&referenceId=x&suggestedAt=2030-01-01T00%3A00%3A00Z',
      ),
      isNull,
    );
  });
}
