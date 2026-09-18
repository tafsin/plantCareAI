import 'package:equatable/equatable.dart';
import 'package:plantcare_shared/errors.dart';

enum AccountReauthenticationMethod { password, google }

enum ProviderCleanupRequestSource {
  selfServiceMobile('self_service_mobile'),
  selfServiceWeb('self_service_web');

  const ProviderCleanupRequestSource(this.value);

  final String value;
}

enum AccountDeletionStage {
  idle,
  awaitingConfirmation,
  reauthenticationRequired,
  reauthenticating,
  recordingProviderCleanup,
  deletingRemoteData,
  clearingLocalData,
  deletingAuthentication,
  incomplete,
  complete,
}

enum AccountDeletionFailureType {
  unauthenticated,
  identityChanged,
  unsupportedProvider,
  cancelled,
  invalidCredentials,
  recentLoginRequired,
  network,
  providerCleanupRequest,
  remoteDeletion,
  remoteVerification,
  localCleanup,
  authenticationDeletion,
  configuration,
  launch,
  unknown,
}

enum AccountDeletionRetryCategory {
  none,
  retryStage,
  reauthenticate,
  restartWorkflow,
}

extension AccountDeletionFailureRetry on AccountDeletionFailureType {
  AccountDeletionRetryCategory get retryCategory => switch (this) {
    AccountDeletionFailureType.cancelled => AccountDeletionRetryCategory.none,
    AccountDeletionFailureType.identityChanged ||
    AccountDeletionFailureType.unauthenticated =>
      AccountDeletionRetryCategory.restartWorkflow,
    AccountDeletionFailureType.invalidCredentials ||
    AccountDeletionFailureType.recentLoginRequired ||
    AccountDeletionFailureType.unsupportedProvider =>
      AccountDeletionRetryCategory.reauthenticate,
    AccountDeletionFailureType.network ||
    AccountDeletionFailureType.providerCleanupRequest ||
    AccountDeletionFailureType.remoteDeletion ||
    AccountDeletionFailureType.remoteVerification ||
    AccountDeletionFailureType.localCleanup ||
    AccountDeletionFailureType.authenticationDeletion ||
    AccountDeletionFailureType.configuration ||
    AccountDeletionFailureType.launch ||
    AccountDeletionFailureType.unknown =>
      AccountDeletionRetryCategory.retryStage,
  };
}

final class AccountDeletionFailure extends AppError {
  const AccountDeletionFailure(this.type, super.message);

  final AccountDeletionFailureType type;

  @override
  List<Object?> get props => [type, message];
}

final class ProviderCleanupRequest extends Equatable {
  const ProviderCleanupRequest({required this.source});

  static const schemaVersion = 1;
  static const providerCleanup = ['adapty'];

  final ProviderCleanupRequestSource source;

  @override
  List<Object?> get props => [source];
}

final class AccountDeletionConfiguration extends Equatable {
  const AccountDeletionConfiguration({
    required this.privacyPolicyUrl,
    required this.termsOfServiceUrl,
    required this.supportEmail,
  });

  static const supportSubject = 'PlantCare AI account deletion request';
  static const supportBody = '''I am requesting deletion of my PlantCare AI account and associated data.

Account email:
Additional information:

I understand that I must not include my password, authentication token, payment details, or other credentials.''';
  static final googlePlaySubscriptionsUrl = Uri.parse(
    'https://play.google.com/store/account/subscriptions',
  );

  final Uri? privacyPolicyUrl;
  final Uri? termsOfServiceUrl;
  final String? supportEmail;

  bool get hasSupportEmail => supportEmail != null;

  Uri? get supportMailto => switch (supportEmail) {
    final email? => Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': supportSubject, 'body': supportBody},
    ),
    null => null,
  };

  @override
  List<Object?> get props => [
    privacyPolicyUrl,
    termsOfServiceUrl,
    supportEmail,
  ];
}

abstract interface class AccountDeletionRepository {
  String get currentUserId;

  Set<AccountReauthenticationMethod> get linkedReauthenticationMethods;

  Future<void> refreshSession();

  Future<void> reauthenticateWithPassword(String password);

  /// Returns false when the user cancels Google authentication.
  Future<bool> reauthenticateWithGoogle();

  Future<void> recordProviderCleanupRequest(
    ProviderCleanupRequestSource source,
  );

  Future<void> deleteRemoteApplicationData();

  Future<void> verifyRemoteApplicationDataDeleted();

  Future<void> deleteCurrentAuthenticationUser();

  Future<void> waitUntilSignedOut();
}

abstract interface class AccountDestinationLauncher {
  bool get hasPrivacyPolicy;

  bool get hasTermsOfService;

  bool get hasSupportEmail;

  String? get supportEmail;

  Future<void> openPrivacyPolicy();

  Future<void> openTermsOfService();

  Future<void> openGooglePlaySubscriptions();

  Future<void> openSupportRequest();
}

String? validateSupportEmail(String value) {
  final email = value.trim();
  if (email.isEmpty ||
      email != value ||
      email.contains(RegExp(r'[\r\n,;?&#]')) ||
      email.length > 254) {
    return null;
  }
  final match = RegExp(
    r'^[A-Za-z0-9.!#$%&\x27*+/=?^_`{|}~-]+@'
    r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );
  return match.hasMatch(email) ? email : null;
}
