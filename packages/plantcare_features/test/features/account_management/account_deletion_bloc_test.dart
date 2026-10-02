import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/account_management.dart';
import 'package:plantcare_domain/local_plant_images.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:plantcare_features/account_management.dart';

void main() {
  late _DeletionRepository repository;
  late _Images images;
  late _Notifications notifications;
  late _Premium premium;
  late _Launcher launcher;

  setUp(() {
    repository = _DeletionRepository();
    images = _Images();
    notifications = _Notifications();
    premium = _Premium();
    launcher = _Launcher();
  });

  AccountDeletionBloc buildBloc() => AccountDeletionBloc(
    repository,
    images,
    notifications,
    premium,
    launcher,
    ProviderCleanupRequestSource.selfServiceWeb,
  );

  blocTest<AccountDeletionBloc, AccountDeletionState>(
    'requires exact DELETE and warning acknowledgement',
    build: buildBloc,
    act: (bloc) => bloc.add(
      const AccountDeletionSubmitted(
        confirmation: 'delete',
        subscriptionAcknowledged: true,
        method: AccountReauthenticationMethod.password,
        password: 'secret',
      ),
    ),
    verify: (_) => expect(repository.calls, isEmpty),
  );

  for (final confirmation in ['', 'delete', 'Delete', ' DELETE', 'DELETE ']) {
    blocTest<AccountDeletionBloc, AccountDeletionState>(
      'rejects near-match confirmation ${confirmation.replaceAll(' ', '_')}',
      build: buildBloc,
      act: (bloc) => bloc.add(
        AccountDeletionSubmitted(
          confirmation: confirmation,
          subscriptionAcknowledged: true,
          method: AccountReauthenticationMethod.password,
          password: 'secret',
        ),
      ),
      verify: (_) => expect(repository.calls, isEmpty),
    );
  }

  blocTest<AccountDeletionBloc, AccountDeletionState>(
    'requires subscription acknowledgement even with exact confirmation',
    build: buildBloc,
    act: (bloc) => bloc.add(
      const AccountDeletionSubmitted(
        confirmation: 'DELETE',
        subscriptionAcknowledged: false,
        method: AccountReauthenticationMethod.password,
        password: 'secret',
      ),
    ),
    verify: (_) => expect(repository.calls, isEmpty),
  );

  blocTest<AccountDeletionBloc, AccountDeletionState>(
    'runs handoff, remote, local, and Auth-last sequence',
    build: buildBloc,
    act: (bloc) => bloc.add(
      const AccountDeletionSubmitted(
        confirmation: 'DELETE',
        subscriptionAcknowledged: true,
        method: AccountReauthenticationMethod.password,
        password: 'secret',
      ),
    ),
    wait: const Duration(milliseconds: 20),
    expect: () => [
      isA<AccountDeletionState>().having(
        (state) => state.stage,
        'stage',
        AccountDeletionStage.reauthenticating,
      ),
      isA<AccountDeletionState>().having(
        (state) => state.stage,
        'stage',
        AccountDeletionStage.recordingProviderCleanup,
      ),
      isA<AccountDeletionState>().having(
        (state) => state.stage,
        'stage',
        AccountDeletionStage.deletingRemoteData,
      ),
      isA<AccountDeletionState>().having(
        (state) => state.stage,
        'stage',
        AccountDeletionStage.clearingLocalData,
      ),
      isA<AccountDeletionState>().having(
        (state) => state.stage,
        'stage',
        AccountDeletionStage.deletingAuthentication,
      ),
      isA<AccountDeletionState>().having(
        (state) => state.stage,
        'stage',
        AccountDeletionStage.complete,
      ),
    ],
    verify: (_) {
      expect(repository.calls, [
        'refresh',
        'password',
        'handoff:self_service_web',
        'remote',
        'verify',
        'uid',
        'auth',
        'signedOut',
      ]);
      expect(images.deletedUsers, ['uid-1']);
      expect(notifications.clearedUsers, ['uid-1']);
    },
  );

  blocTest<AccountDeletionBloc, AccountDeletionState>(
    'handoff failure blocks all destructive work and exposes support',
    build: () {
      repository.handoffFails = true;
      return buildBloc();
    },
    act: (bloc) => bloc.add(
      const AccountDeletionSubmitted(
        confirmation: 'DELETE',
        subscriptionAcknowledged: true,
        method: AccountReauthenticationMethod.password,
        password: 'secret',
      ),
    ),
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(repository.calls, [
        'refresh',
        'password',
        'handoff:self_service_web',
      ]);
      expect(
        bloc.state.failureType,
        AccountDeletionFailureType.providerCleanupRequest,
      );
      expect(bloc.state.hasSupportEmail, true);
      expect(images.deletedUsers, isEmpty);
      expect(notifications.clearedUsers, isEmpty);
    },
  );

  blocTest<AccountDeletionBloc, AccountDeletionState>(
    'web preparation never performs a Premium lookup',
    build: buildBloc,
    act: (bloc) => bloc.add(const AccountDeletionPrepared()),
    wait: const Duration(milliseconds: 20),
    verify: (_) => expect(premium.refreshCount, 0),
  );

  blocTest<AccountDeletionBloc, AccountDeletionState>(
    'Google cancellation is neutral and blocks destructive work',
    build: () {
      repository.googleResult = false;
      return buildBloc();
    },
    act: (bloc) => bloc.add(
      const AccountDeletionSubmitted(
        confirmation: 'DELETE',
        subscriptionAcknowledged: true,
        method: AccountReauthenticationMethod.google,
      ),
    ),
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(repository.calls, ['refresh', 'google']);
      expect(bloc.state.failureType, AccountDeletionFailureType.cancelled);
      expect(images.deletedUsers, isEmpty);
      expect(notifications.clearedUsers, isEmpty);
    },
  );

  blocTest<AccountDeletionBloc, AccountDeletionState>(
    'remote verification failure preserves local data and authentication',
    build: () {
      repository.failureAt = 'verify';
      return buildBloc();
    },
    act: (bloc) => bloc.add(
      const AccountDeletionSubmitted(
        confirmation: 'DELETE',
        subscriptionAcknowledged: true,
        method: AccountReauthenticationMethod.password,
        password: 'secret',
      ),
    ),
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(repository.calls, [
        'refresh',
        'password',
        'handoff:self_service_web',
        'remote',
        'verify',
      ]);
      expect(
        bloc.state.failureType,
        AccountDeletionFailureType.remoteVerification,
      );
      expect(images.deletedUsers, isEmpty);
      expect(notifications.clearedUsers, isEmpty);
    },
  );

  blocTest<AccountDeletionBloc, AccountDeletionState>(
    'local cleanup failure preserves authentication and retries locally',
    build: () {
      images.failOnce = true;
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(
        const AccountDeletionSubmitted(
          confirmation: 'DELETE',
          subscriptionAcknowledged: true,
          method: AccountReauthenticationMethod.password,
          password: 'secret',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(
        const AccountDeletionRetried(
          method: AccountReauthenticationMethod.password,
          password: 'secret',
        ),
      );
    },
    wait: const Duration(milliseconds: 40),
    verify: (bloc) {
      expect(repository.calls.where((call) => call == 'remote').length, 1);
      expect(repository.calls.where((call) => call == 'auth').length, 1);
      expect(repository.calls.last, 'signedOut');
      expect(bloc.state.stage, AccountDeletionStage.complete);
    },
  );

  blocTest<AccountDeletionBloc, AccountDeletionState>(
    'rapid duplicate submissions start only one destructive workflow',
    build: () {
      repository.pauseRefresh = true;
      return buildBloc();
    },
    act: (bloc) {
      const event = AccountDeletionSubmitted(
        confirmation: 'DELETE',
        subscriptionAcknowledged: true,
        method: AccountReauthenticationMethod.password,
        password: 'secret',
      );
      bloc
        ..add(event)
        ..add(event);
    },
    wait: const Duration(milliseconds: 60),
    verify: (_) {
      expect(repository.calls.where((call) => call == 'refresh').length, 1);
      expect(repository.calls.where((call) => call == 'auth').length, 1);
    },
  );
}

final class _DeletionRepository implements AccountDeletionRepository {
  final calls = <String>[];
  bool handoffFails = false;
  bool googleResult = true;
  bool pauseRefresh = false;
  String? failureAt;

  @override
  String get currentUserId {
    calls.add('uid');
    return 'uid-1';
  }

  @override
  Set<AccountReauthenticationMethod> get linkedReauthenticationMethods => {
    AccountReauthenticationMethod.password,
  };

  @override
  Future<void> refreshSession() async {
    calls.add('refresh');
    if (pauseRefresh) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async =>
      calls.add('password');

  @override
  Future<bool> reauthenticateWithGoogle() async {
    calls.add('google');
    return googleResult;
  }

  @override
  Future<void> recordProviderCleanupRequest(
    ProviderCleanupRequestSource source,
  ) async {
    calls.add('handoff:${source.value}');
    if (handoffFails) {
      throw const AccountDeletionFailure(
        AccountDeletionFailureType.providerCleanupRequest,
        'Not recorded.',
      );
    }
  }

  @override
  Future<void> deleteRemoteApplicationData() async {
    calls.add('remote');
    if (failureAt == 'remote') {
      throw const AccountDeletionFailure(
        AccountDeletionFailureType.remoteDeletion,
        'Remote deletion failed.',
      );
    }
  }

  @override
  Future<void> verifyRemoteApplicationDataDeleted() async {
    calls.add('verify');
    if (failureAt == 'verify') {
      throw const AccountDeletionFailure(
        AccountDeletionFailureType.remoteVerification,
        'Remote verification failed.',
      );
    }
  }

  @override
  Future<void> deleteCurrentAuthenticationUser() async => calls.add('auth');

  @override
  Future<void> waitUntilSignedOut() async => calls.add('signedOut');
}

final class _Images implements LocalPlantImageRepository {
  final deletedUsers = <String>[];
  bool failOnce = false;

  @override
  LocalPlantImageStorageKind get storageKind =>
      LocalPlantImageStorageKind.sessionOnly;
  @override
  Future<void> deleteAllForUser(String userId) async {
    deletedUsers.add(userId);
    if (failOnce) {
      failOnce = false;
      throw StateError('local failure');
    }
  }

  @override
  Future<void> cleanup() async {}
  @override
  Future<void> delete(String imageId) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<void> deletePlantImages(String plantId) async {}
  @override
  Future<List<LocalPlantImage>> list({
    String? plantId,
    String? observationId,
    LocalPlantImagePurpose? purpose,
  }) async => [];
  @override
  Future<Uint8List?> read(String imageId) async => null;
  @override
  Future<LocalPlantImage> save({
    required LocalPlantImagePurpose purpose,
    required String plantId,
    required Uint8List bytes,
    required DateTime createdAt,
    String? observationId,
  }) => throw UnimplementedError();
  @override
  Future<int> storageUsedBytes() async => 0;
}

final class _Notifications implements NotificationScheduler {
  final clearedUsers = <String>[];
  @override
  bool get isSupported => false;
  @override
  Stream<String> get notificationTapPayloads => const Stream.empty();
  @override
  Future<void> clearUser(String userId) async => clearedUsers.add(userId);
  @override
  Future<void> cancel({
    required String userId,
    required String reminderId,
  }) async {}
  @override
  Future<NotificationPermission> checkPermission() async =>
      NotificationPermission.unavailable;
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

final class _Premium implements PremiumSubscriptionRepository {
  int refreshCount = 0;
  @override
  PurchasePlatform get platform => PurchasePlatform.web;
  @override
  PremiumAccessSnapshot get currentAccess =>
      const PremiumAccessSnapshot.signedOut();
  @override
  Stream<PremiumAccessSnapshot> get accessChanges => const Stream.empty();
  @override
  Stream<PaywallEvent> get paywallEvents => const Stream.empty();
  @override
  Future<void> refreshProfile() async => refreshCount += 1;
  @override
  Future<void> dispose() async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<PaywallPreparation> preparePaywall() async =>
      const PaywallPreparation(PaywallAvailability.unsupported);
  @override
  Future<PremiumPurchaseResult> purchase() async =>
      const PremiumPurchaseCancelled();
  @override
  Future<RestorePurchasesResult> restorePurchases() async =>
      const RestorePurchasesResult(hasPremium: false);
}

final class _Launcher implements AccountDestinationLauncher {
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
