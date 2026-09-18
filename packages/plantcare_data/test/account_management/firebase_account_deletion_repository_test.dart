import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_data/src/account_management/account_authentication_gateway.dart';
import 'package:plantcare_data/src/account_management/account_firestore_gateway.dart';
import 'package:plantcare_data/src/account_management/firebase_account_deletion_repository.dart';
import 'package:plantcare_domain/account_management.dart';

void main() {
  late _Authentication authentication;
  late _Firestore firestore;
  late List<String> logs;
  late FirebaseAccountDeletionRepository repository;

  setUp(() {
    authentication = _Authentication();
    firestore = _Firestore();
    logs = [];
    repository = FirebaseAccountDeletionRepository.withGateway(
      authentication,
      firestore,
      (operation, category) => logs.add('$operation:$category'),
    );
  });

  test('reports password-only, Google-only, and linked provider sets', () {
    authentication.providers = {'password'};
    expect(repository.linkedReauthenticationMethods, {
      AccountReauthenticationMethod.password,
    });

    authentication.providers = {'google.com'};
    final googleRepository = FirebaseAccountDeletionRepository.withGateway(
      authentication,
      firestore,
    );
    expect(googleRepository.linkedReauthenticationMethods, {
      AccountReauthenticationMethod.google,
    });

    authentication.providers = {'password', 'google.com', 'phone'};
    final linkedRepository = FirebaseAccountDeletionRepository.withGateway(
      authentication,
      firestore,
    );
    expect(linkedRepository.linkedReauthenticationMethods, {
      AccountReauthenticationMethod.password,
      AccountReauthenticationMethod.google,
    });
  });

  test(
    'password and Google success use the captured authenticated UID',
    () async {
      await repository.refreshSession();
      await repository.reauthenticateWithPassword('not-logged-password');
      expect(await repository.reauthenticateWithGoogle(), true);
      expect(authentication.expectedUids, everyElement('uid-a'));
    },
  );

  test('Google cancellation is neutral', () async {
    authentication.googleResult = false;
    expect(await repository.reauthenticateWithGoogle(), false);
    expect(firestore.calls, isEmpty);
  });

  for (final entry in <String, AccountDeletionFailureType>{
    'wrong-password': AccountDeletionFailureType.invalidCredentials,
    'invalid-credential': AccountDeletionFailureType.invalidCredentials,
    'requires-recent-login': AccountDeletionFailureType.recentLoginRequired,
    'network-request-failed': AccountDeletionFailureType.network,
  }.entries) {
    test('maps password ${entry.key} safely', () async {
      authentication.passwordFailure = entry.key;
      await expectLater(
        repository.reauthenticateWithPassword('super-secret-password'),
        throwsA(
          isA<AccountDeletionFailure>().having(
            (failure) => failure.type,
            'type',
            entry.value,
          ),
        ),
      );
      expect(logs.single, 'password_reauthentication:${entry.key}');
    });
  }

  for (final code in [
    'popup-closed-by-user',
    'cancelled-popup-request',
    'web-context-cancelled',
    'user-cancelled',
  ]) {
    test('provider cancellation code $code remains cancellation', () async {
      expect(isGoogleReauthenticationCancellationCode(code), isTrue);
      authentication.googleResult = false;
      expect(await repository.reauthenticateWithGoogle(), false);
      expect(logs, isEmpty);
    });
  }

  test('popup blocking and network errors are not cancellation', () {
    expect(isGoogleReauthenticationCancellationCode('popup-blocked'), isFalse);
    expect(
      isGoogleReauthenticationCancellationCode('network-request-failed'),
      isFalse,
    );
  });

  test('maps popup blocked, network, and provider mismatch', () async {
    authentication.googleFailure = 'popup-blocked';
    await expectLater(
      repository.reauthenticateWithGoogle(),
      throwsA(isA<AccountDeletionFailure>()),
    );
    expect(logs.single, 'google_reauthentication:popup-blocked');

    authentication.googleFailure = 'network-request-failed';
    await expectLater(
      repository.reauthenticateWithGoogle(),
      throwsA(
        isA<AccountDeletionFailure>().having(
          (failure) => failure.type,
          'type',
          AccountDeletionFailureType.network,
        ),
      ),
    );

    authentication.providers = {'password'};
    await expectLater(
      repository.reauthenticateWithGoogle(),
      throwsA(
        isA<AccountDeletionFailure>().having(
          (failure) => failure.type,
          'type',
          AccountDeletionFailureType.unsupportedProvider,
        ),
      ),
    );
  });

  test('identity change stops every privileged destructive stage', () async {
    await repository.refreshSession();
    authentication.uid = 'uid-b';

    expect(() => repository.currentUserId, throwsA(_identityChanged));
    await expectLater(
      repository.recordProviderCleanupRequest(
        ProviderCleanupRequestSource.selfServiceMobile,
      ),
      throwsA(_identityChanged),
    );
    expect(firestore.calls, isEmpty);
  });

  test(
    'identity change after acknowledged gateway work is preserved',
    () async {
      firestore.afterCreate = () => authentication.uid = 'uid-b';
      await expectLater(
        repository.recordProviderCleanupRequest(
          ProviderCleanupRequestSource.selfServiceWeb,
        ),
        throwsA(_identityChanged),
      );
      expect(firestore.calls, ['create:uid-a:self_service_web']);
    },
  );

  test(
    'cleanup handoff uses exact UID/source and is idempotent in-run',
    () async {
      await repository.recordProviderCleanupRequest(
        ProviderCleanupRequestSource.selfServiceMobile,
      );
      await repository.recordProviderCleanupRequest(
        ProviderCleanupRequestSource.selfServiceMobile,
      );
      expect(firestore.calls, ['create:uid-a:self_service_mobile']);
      expect(firestore.reads, 0);
      expect(firestore.updates, 0);
      expect(firestore.deletes, 0);
    },
  );

  test('unconfirmed repeated create never claims the handoff', () async {
    firestore.createFailure = StateError('already exists with private data');
    await expectLater(
      repository.recordProviderCleanupRequest(
        ProviderCleanupRequestSource.selfServiceWeb,
      ),
      throwsA(
        isA<AccountDeletionFailure>().having(
          (failure) => failure.type,
          'type',
          AccountDeletionFailureType.providerCleanupRequest,
        ),
      ),
    );
    await expectLater(
      repository.deleteRemoteApplicationData(),
      throwsA(
        isA<AccountDeletionFailure>().having(
          (failure) => failure.type,
          'type',
          AccountDeletionFailureType.providerCleanupRequest,
        ),
      ),
    );
    expect(firestore.calls, ['create:uid-a:self_service_web']);
  });

  test(
    'Firestore and Auth failures map without exposing raw details',
    () async {
      const sensitiveValues = <String>[
        'super-secret-password',
        'access-token-value',
        'id-token-value',
        'person@example.com',
        'private plant document content',
        '/private/image/path.jpg',
        'image-base64-data',
        'firebase-api-key-and-project-config',
        'adapty-secret-key',
        'private prompt text',
      ];
      firestore.createFailure = StateError(sensitiveValues.join('|'));
      await expectLater(
        repository.recordProviderCleanupRequest(
          ProviderCleanupRequestSource.selfServiceWeb,
        ),
        throwsA(isA<AccountDeletionFailure>()),
      );
      authentication.deleteFailure = sensitiveValues.join('|');
      await expectLater(
        repository.deleteCurrentAuthenticationUser(),
        throwsA(isA<AccountDeletionFailure>()),
      );

      final output = logs.join('\n');
      for (final secret in sensitiveValues) {
        expect(output, isNot(contains(secret)));
      }
      expect(output, contains('provider_cleanup_request:StateError'));
      expect(output, contains('authentication_deletion:'));
    },
  );

  test(
    'remote failure precedes Auth deletion and Auth failure follows cleanup',
    () async {
      await repository.recordProviderCleanupRequest(
        ProviderCleanupRequestSource.selfServiceWeb,
      );
      firestore.remoteFailure = StateError('commit failed');
      await expectLater(
        repository.deleteRemoteApplicationData(),
        throwsA(isA<AccountDeletionFailure>()),
      );
      expect(authentication.deleteCalls, 0);

      firestore.remoteFailure = null;
      await repository.deleteRemoteApplicationData();
      await repository.verifyRemoteApplicationDataDeleted();
      authentication.deleteFailure = 'requires-recent-login';
      await expectLater(
        repository.deleteCurrentAuthenticationUser(),
        throwsA(
          isA<AccountDeletionFailure>().having(
            (failure) => failure.type,
            'type',
            AccountDeletionFailureType.recentLoginRequired,
          ),
        ),
      );
      expect(
        firestore.calls,
        containsAllInOrder(['delete:uid-a', 'verify:uid-a']),
      );
    },
  );
}

final _identityChanged = isA<AccountDeletionFailure>().having(
  (failure) => failure.type,
  'type',
  AccountDeletionFailureType.identityChanged,
);

final class _Authentication implements AccountAuthenticationGateway {
  String uid = 'uid-a';
  Set<String> providers = {'password', 'google.com'};
  String? passwordFailure;
  String? googleFailure;
  String? deleteFailure;
  bool googleResult = true;
  int deleteCalls = 0;
  final expectedUids = <String>[];

  @override
  AccountAuthenticationSnapshot? get currentSession =>
      AccountAuthenticationSnapshot(
        uid: uid,
        email: 'redacted@example.test',
        providerIds: providers,
      );

  void _expect(String expectedUid) {
    expectedUids.add(expectedUid);
    if (uid != expectedUid) {
      throw const AccountAuthenticationGatewayException('identity-changed');
    }
  }

  @override
  Future<void> refreshSession(String expectedUid) async => _expect(expectedUid);

  @override
  Future<void> reauthenticateWithPassword(
    String expectedUid,
    String password,
  ) async {
    _expect(expectedUid);
    if (passwordFailure case final code?) {
      throw AccountAuthenticationGatewayException(code);
    }
  }

  @override
  Future<bool> reauthenticateWithGoogle(String expectedUid) async {
    _expect(expectedUid);
    if (googleFailure case final code?) {
      throw AccountAuthenticationGatewayException(code);
    }
    return googleResult;
  }

  @override
  Future<void> deleteCurrentUser(String expectedUid) async {
    _expect(expectedUid);
    deleteCalls += 1;
    if (deleteFailure case final code?) {
      throw AccountAuthenticationGatewayException(code);
    }
  }

  @override
  Future<void> waitUntilSignedOut() async {}
}

final class _Firestore implements AccountFirestoreGateway {
  final calls = <String>[];
  int reads = 0;
  int updates = 0;
  int deletes = 0;
  Object? createFailure;
  Object? remoteFailure;
  void Function()? afterCreate;

  @override
  Future<void> createProviderCleanupRequest({
    required String uid,
    required String source,
  }) async {
    calls.add('create:$uid:$source');
    if (createFailure case final failure?) throw failure;
    afterCreate?.call();
  }

  @override
  Future<void> deleteAllApplicationData(String uid) async {
    calls.add('delete:$uid');
    if (remoteFailure case final failure?) throw failure;
  }

  @override
  Future<void> verifyApplicationDataDeleted(String uid) async {
    calls.add('verify:$uid');
  }
}
