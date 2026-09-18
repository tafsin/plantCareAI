import 'package:plantcare_domain/account_management.dart';
import 'package:test/test.dart';

void main() {
  test('cleanup request and failures retain value equality', () {
    expect(
      const ProviderCleanupRequest(
        source: ProviderCleanupRequestSource.selfServiceWeb,
      ),
      const ProviderCleanupRequest(
        source: ProviderCleanupRequestSource.selfServiceWeb,
      ),
    );
    expect(ProviderCleanupRequestSource.values.map((source) => source.value), [
      'self_service_mobile',
      'self_service_web',
    ]);
    expect(ProviderCleanupRequest.schemaVersion, 1);
    expect(ProviderCleanupRequest.providerCleanup, ['adapty']);
    expect(AccountReauthenticationMethod.values.toSet(), {
      AccountReauthenticationMethod.password,
      AccountReauthenticationMethod.google,
    });
    expect(
      AccountDeletionFailureType.values,
      containsAll([
        AccountDeletionFailureType.identityChanged,
        AccountDeletionFailureType.providerCleanupRequest,
        AccountDeletionFailureType.remoteDeletion,
        AccountDeletionFailureType.remoteVerification,
        AccountDeletionFailureType.localCleanup,
        AccountDeletionFailureType.authenticationDeletion,
      ]),
    );
    expect(
      const AccountDeletionFailure(
        AccountDeletionFailureType.identityChanged,
        'Account changed.',
      ),
      const AccountDeletionFailure(
        AccountDeletionFailureType.identityChanged,
        'Account changed.',
      ),
    );
  });

  test('failure retry categories make identity changes restart safely', () {
    expect(
      AccountDeletionFailureType.identityChanged.retryCategory,
      AccountDeletionRetryCategory.restartWorkflow,
    );
    expect(
      AccountDeletionFailureType.unauthenticated.retryCategory,
      AccountDeletionRetryCategory.restartWorkflow,
    );
    expect(
      AccountDeletionFailureType.recentLoginRequired.retryCategory,
      AccountDeletionRetryCategory.reauthenticate,
    );
    expect(
      AccountDeletionFailureType.remoteDeletion.retryCategory,
      AccountDeletionRetryCategory.retryStage,
    );
    expect(
      AccountDeletionFailureType.cancelled.retryCategory,
      AccountDeletionRetryCategory.none,
    );
    expect(
      AccountDeletionFailureType.values.map((value) => value.retryCategory),
      hasLength(AccountDeletionFailureType.values.length),
    );
  });

  test('support email validation accepts one mailbox only', () {
    expect(validateSupportEmail('support@example.com'), 'support@example.com');
    for (final value in [
      '',
      ' support@example.com',
      'support@example.com ',
      'support@example',
      'a@example.com,b@example.com',
      'a@example.com?subject=x',
      'a@example.com#fragment',
      'a@example.com&bcc=x',
      'a@example.com;b@example.com',
      'a@example.com\nBcc:x@example.com',
      'a@example.com\rBcc:x@example.com',
    ]) {
      expect(validateSupportEmail(value), isNull, reason: value);
    }
  });

  test('support mailto uses fixed encoded copy', () {
    const configuration = AccountDeletionConfiguration(
      privacyPolicyUrl: null,
      termsOfServiceUrl: null,
      supportEmail: 'support@example.com',
    );
    final mailto = configuration.supportMailto!;
    expect(mailto.scheme, 'mailto');
    expect(mailto.path, 'support@example.com');
    expect(
      mailto.queryParameters['subject'],
      AccountDeletionConfiguration.supportSubject,
    );
    expect(
      mailto.queryParameters['body'],
      contains('must not include my password'),
    );
    expect(
      mailto.toString(),
      contains('subject=PlantCare+AI+account+deletion+request'),
    );
    expect(mailto.toString(), contains('body=I+am+requesting+deletion'));
    expect(mailto.toString(), isNot(contains('\n')));
    expect(mailto.toString(), isNot(contains(' ')));
  });
}
