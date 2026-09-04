import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';
import 'package:plantcare_ai/features/reminders/domain/entities/reminder.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const plants = '/plants';
  static const newPlant = '/plants/new';
  static const reminders = '/reminders';
  static const privacySafety = '/privacy-safety';
  static const signIn = '/sign-in';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  static const authenticationLocations = {signIn, register, forgotPassword};

  static String plantDetails(String plantId) =>
      '/plants/${Uri.encodeComponent(plantId)}';

  static String editPlant(String plantId) => '${plantDetails(plantId)}/edit';

  static String newReminder(
    String plantId, {
    ReminderSource source = ReminderSource.userCreated,
    String? referenceId,
    DateTime? suggestedAt,
  }) => Uri(
    path: '${plantDetails(plantId)}/reminders/new',
    queryParameters: {
      if (source != ReminderSource.userCreated) 'source': source.value,
      'referenceId': ?referenceId,
      if (suggestedAt != null)
        'suggestedAt': suggestedAt.toUtc().toIso8601String(),
    },
  ).toString();

  static String plantReminders(String plantId) =>
      '${plantDetails(plantId)}/reminders';

  static String reminderDetails(String plantId, String reminderId) =>
      '${plantReminders(plantId)}/${Uri.encodeComponent(reminderId)}';

  static String newSoilCheck(String plantId) =>
      '${plantDetails(plantId)}/soil-checks/new';

  static String soilCheckHistory(String plantId) =>
      '${plantDetails(plantId)}/soil-checks';

  static String soilCheckDetails(String plantId, String soilCheckId) =>
      '${soilCheckHistory(plantId)}/${Uri.encodeComponent(soilCheckId)}';

  static String newFertilizerAssessment(String plantId) =>
      '${plantDetails(plantId)}/fertilizer-assessments/new';

  static String fertilizerAssessmentHistory(String plantId) =>
      '${plantDetails(plantId)}/fertilizer-assessments';

  static String fertilizerAssessmentDetails(
    String plantId,
    String assessmentId,
  ) =>
      '${fertilizerAssessmentHistory(plantId)}/${Uri.encodeComponent(assessmentId)}';

  static String careHistory(String plantId) => '${plantDetails(plantId)}/care';

  static String newCareLog(String plantId, CareLogType type) => Uri(
    path: '${careHistory(plantId)}/new',
    queryParameters: {'type': type.name},
  ).toString();

  static String careLogDetails(String plantId, String careLogId) =>
      '${careHistory(plantId)}/${Uri.encodeComponent(careLogId)}';

  static String observePlant(String plantId) =>
      '${plantDetails(plantId)}/observe';

  static String observationHistory(String plantId) =>
      '${plantDetails(plantId)}/observations';

  static String observationDetails(String plantId, String observationId) =>
      '${observationHistory(plantId)}/${Uri.encodeComponent(observationId)}';

  static String diagnoseObservation(String plantId, String observationId) =>
      '${observationDetails(plantId, observationId)}/diagnose';

  static String diagnosisHistory(String plantId, String observationId) =>
      '${observationDetails(plantId, observationId)}/diagnoses';

  static String diagnosisDetails(
    String plantId,
    String observationId,
    String diagnosisId,
  ) =>
      '${diagnosisHistory(plantId, observationId)}/${Uri.encodeComponent(diagnosisId)}';

  static String signInLocation(String? redirect) =>
      _authLocation(signIn, redirect);

  static String registerLocation(String? redirect) =>
      _authLocation(register, redirect);

  static String forgotPasswordLocation(String? redirect) =>
      _authLocation(forgotPassword, redirect);

  static String _authLocation(String path, String? redirect) => Uri(
    path: path,
    queryParameters: redirect == null ? null : {'redirect': redirect},
  ).toString();
}
