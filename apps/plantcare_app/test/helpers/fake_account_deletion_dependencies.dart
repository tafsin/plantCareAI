import 'package:plantcare_domain/account_management.dart';
import 'package:plantcare_domain/reminders.dart';

final class FakeAccountDeletionRepository implements AccountDeletionRepository {
  @override
  String get currentUserId => 'user-1';

  @override
  Set<AccountReauthenticationMethod> get linkedReauthenticationMethods => {
    AccountReauthenticationMethod.password,
  };

  @override
  Future<void> deleteCurrentAuthenticationUser() async {}

  @override
  Future<void> deleteRemoteApplicationData() async {}

  @override
  Future<void> reauthenticateWithPassword(String password) async {}

  @override
  Future<bool> reauthenticateWithGoogle() async => true;

  @override
  Future<void> recordProviderCleanupRequest(
    ProviderCleanupRequestSource source,
  ) async {}

  @override
  Future<void> refreshSession() async {}

  @override
  Future<void> verifyRemoteApplicationDataDeleted() async {}

  @override
  Future<void> waitUntilSignedOut() async {}
}

final class FakeAccountDestinationLauncher
    implements AccountDestinationLauncher {
  @override
  bool get hasPrivacyPolicy => true;

  @override
  bool get hasSupportEmail => true;

  @override
  String? get supportEmail => 'support@example.test';

  @override
  bool get hasTermsOfService => true;

  @override
  Future<void> openGooglePlaySubscriptions() async {}

  @override
  Future<void> openPrivacyPolicy() async {}

  @override
  Future<void> openSupportRequest() async {}

  @override
  Future<void> openTermsOfService() async {}
}

final class FakeNotificationScheduler implements NotificationScheduler {
  @override
  bool get isSupported => false;

  @override
  Stream<String> get notificationTapPayloads => const Stream.empty();

  @override
  Future<void> cancel({
    required String userId,
    required String reminderId,
  }) async {}

  @override
  Future<NotificationPermission> checkPermission() async =>
      NotificationPermission.unavailable;

  @override
  Future<void> clearUser(String userId) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> reconcile({
    required String userId,
    required List<Reminder> reminders,
    required Map<String, String> plantNames,
    required DateTime now,
  }) async {}

  @override
  Future<NotificationPermission> requestPermission() async =>
      NotificationPermission.unavailable;

  @override
  Future<void> schedule({
    required String userId,
    required Reminder reminder,
    required String plantName,
  }) async {}
}
