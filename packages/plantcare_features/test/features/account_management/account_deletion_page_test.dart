import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/account_management.dart';
import 'package:plantcare_domain/local_plant_images.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:plantcare_features/account_management.dart';

void main() {
  late _Repository repository;
  late _Images images;
  late _Notifications notifications;
  late _Premium premium;
  late _Launcher launcher;

  setUp(() {
    repository = _Repository();
    images = _Images();
    notifications = _Notifications();
    premium = _Premium();
    launcher = _Launcher();
  });

  AccountDeletionBloc bloc({
    ProviderCleanupRequestSource source =
        ProviderCleanupRequestSource.selfServiceMobile,
  }) => AccountDeletionBloc(
    repository,
    images,
    notifications,
    premium,
    launcher,
    source,
  );

  Future<void> reveal(
    WidgetTester tester,
    Finder target, {
    bool public = false,
  }) async {
    final surface = find.byKey(
      ValueKey(
        public ? 'public-account-deletion-scroll' : 'account-deletion-page',
      ),
    );
    for (
      var attempt = 0;
      target.evaluate().isEmpty && attempt < 10;
      attempt += 1
    ) {
      await tester.drag(surface, const Offset(0, -400));
      await tester.pump();
    }
    expect(target, findsWidgets);
    await tester.ensureVisible(target.first);
    await tester.pump();
  }

  Future<void> pumpDeletion(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    bool public = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: BlocProvider.value(
            value: bloc(
              source: public
                  ? ProviderCleanupRequestSource.selfServiceWeb
                  : ProviderCleanupRequestSource.selfServiceMobile,
            ),
            child: public
                ? const PublicAccountDeletionPage(
                    isAuthenticated: true,
                    signIn: Text('Sign-in surface'),
                    deletion: AccountDeletionPage(showPublicHeading: true),
                  )
                : const Scaffold(body: AccountDeletionPage()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> confirmDeletion(WidgetTester tester) async {
    await reveal(
      tester,
      find.byKey(const ValueKey('subscription-warning-acknowledgement')),
    );
    await tester.tap(
      find.byKey(const ValueKey('subscription-warning-acknowledgement')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('deletion-confirmation-field')),
      'DELETE',
    );
    await reveal(tester, find.byKey(const ValueKey('deletion-password-field')));
    await tester.enterText(
      find.byKey(const ValueKey('deletion-password-field')),
      'never-logged-password',
    );
    await tester.tap(find.byKey(const ValueKey('delete-account-button')));
    await tester.pump();
  }

  testWidgets('signed-out public page is accessible and support is visible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc(source: ProviderCleanupRequestSource.selfServiceWeb),
          child: const PublicAccountDeletionPage(
            isAuthenticated: false,
            signIn: Text('Email and Google sign-in'),
            deletion: Text('Authenticated deletion'),
          ),
        ),
      ),
    );

    expect(find.text('PlantCare AI account deletion'), findsOneWidget);
    await reveal(
      tester,
      find.byKey(const ValueKey('public-deletion-sign-in')),
      public: true,
    );
    expect(
      find.byKey(const ValueKey('public-deletion-sign-in')),
      findsOneWidget,
    );
    expect(find.text('support@example.test'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Account deletion support email address: support@example.test',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('30 calendar days'), findsWidgets);
    expect(find.textContaining('up to 90 days'), findsOneWidget);
    expect(find.textContaining('Google Play and Adapty'), findsOneWidget);

    await tester.tap(find.text('Start a support request'));
    await tester.pump();
    expect(launcher.destinations, ['support']);
    await tester.tap(find.byKey(const ValueKey('public-deletion-sign-in')));
    await tester.pump();
    expect(find.text('Email and Google sign-in'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('missing support configuration is explicit and safe', (
    tester,
  ) async {
    launcher.support = null;
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc(source: ProviderCleanupRequestSource.selfServiceWeb),
          child: const PublicAccountDeletionPage(
            isAuthenticated: false,
            signIn: Text('Sign in'),
            deletion: Text('Deletion'),
          ),
        ),
      ),
    );

    await reveal(
      tester,
      find.text('Support email is not configured'),
      public: true,
    );
    expect(find.text('Support email is not configured'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('account-deletion-support-address')),
      findsNothing,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('authenticated mobile shows missing support and legal controls', (
    tester,
  ) async {
    launcher.support = null;
    await pumpDeletion(tester);
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.textContaining('support email is not configured'),
    );
    expect(
      find.textContaining('support email is not configured'),
      findsOneWidget,
    );
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    await tester.tap(find.text('Privacy Policy'));
    await tester.tap(find.text('Terms of Service'));
    await tester.pump();
    expect(launcher.destinations, ['privacy', 'terms']);
  });

  testWidgets('public page narrow golden remains readable', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc(source: ProviderCleanupRequestSource.selfServiceWeb),
          child: const PublicAccountDeletionPage(
            isAuthenticated: false,
            signIn: Text('Sign in'),
            deletion: Text('Deletion'),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(PublicAccountDeletionPage),
      matchesGoldenFile('goldens/public_account_deletion_narrow.png'),
    );
  });

  for (final configuration in <(String, Size, double)>[
    ('narrow', const Size(390, 844), 1),
    ('wide', const Size(1200, 900), 1),
    ('large text', const Size(390, 844), 2),
  ]) {
    testWidgets('${configuration.$1} deletion layout has no overflow', (
      tester,
    ) async {
      await pumpDeletion(
        tester,
        size: configuration.$2,
        textScale: configuration.$3,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await reveal(tester, find.text('Subscription reminder'));
      expect(find.text('Subscription reminder'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('delete-account-button')));
      expect(find.text('Permanently delete account and data'), findsOneWidget);
    });
  }

  testWidgets('confirmation is exact, destructive, keyboard/focus accessible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpDeletion(tester);
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('delete-account-button')));

    final deleteButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('delete-account-button')),
    );
    expect(deleteButton.onPressed, isNull);

    await reveal(
      tester,
      find.byKey(const ValueKey('deletion-confirmation-field')),
    );
    await tester.tap(find.byKey(const ValueKey('deletion-confirmation-field')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(
      find.byKey(const ValueKey('deletion-confirmation-field')),
      'delete',
    );
    await tester.tap(
      find.byKey(const ValueKey('subscription-warning-acknowledgement')),
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('delete-account-button')),
          )
          .onPressed,
      isNull,
    );

    expect(
      find.bySemanticsLabel('Permanently delete account and data'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('active and unknown Premium warnings never block deletion', (
    tester,
  ) async {
    premium
      ..platformValue = PurchasePlatform.android
      ..active = true;
    await pumpDeletion(tester);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Active Premium subscription'));
    expect(find.text('Active Premium subscription'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    premium
      ..active = false
      ..refreshFailure = StateError('Adapty private failure');
    await pumpDeletion(tester);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Subscription reminder'));
    expect(find.text('Subscription reminder'), findsOneWidget);
    expect(find.textContaining('Adapty private failure'), findsNothing);
  });

  testWidgets('Google cancellation and wrong password are retryable', (
    tester,
  ) async {
    repository
      ..methods = {AccountReauthenticationMethod.google}
      ..googleResult = false;
    await pumpDeletion(tester);
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.byKey(const ValueKey('subscription-warning-acknowledgement')),
    );
    await tester.tap(
      find.byKey(const ValueKey('subscription-warning-acknowledgement')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('deletion-confirmation-field')),
      'DELETE',
    );
    await reveal(tester, find.byKey(const ValueKey('delete-account-button')));
    await tester.tap(find.byKey(const ValueKey('delete-account-button')));
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.textContaining('Google verification was cancelled'),
    );
    expect(
      find.textContaining('Google verification was cancelled'),
      findsOneWidget,
    );
    expect(repository.remoteCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    repository = _Repository()
      ..passwordFailure = const AccountDeletionFailure(
        AccountDeletionFailureType.invalidCredentials,
        'Those credentials could not verify this account.',
      );
    await pumpDeletion(tester);
    await tester.pumpAndSettle();
    await confirmDeletion(tester);
    await tester.pumpAndSettle();
    await reveal(tester, find.textContaining('could not verify'));
    expect(find.textContaining('could not verify'), findsOneWidget);
    expect(repository.remoteCalls, 0);
  });

  testWidgets('web shows handoff progress, failure, support, and retry', (
    tester,
  ) async {
    repository.handoffGate = Completer<void>();
    await pumpDeletion(tester, public: true);
    await tester.pumpAndSettle();
    await confirmDeletion(tester);
    expect(find.text('Recording provider cleanup request…'), findsOneWidget);
    expect(repository.remoteCalls, 0);

    repository.handoffGate!.completeError(
      const AccountDeletionFailure(
        AccountDeletionFailureType.providerCleanupRequest,
        'The provider cleanup request could not be recorded.',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Adapty cleanup was not queued. No account data was deleted.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('retry-account-deletion')),
      findsOneWidget,
    );
    expect(find.text('support@example.test'), findsOneWidget);
    expect(repository.remoteCalls, 0);

    repository.handoffGate = null;
    await tester.tap(find.byKey(const ValueKey('retry-account-deletion')));
    await tester.pumpAndSettle();
    expect(repository.sources, [
      ProviderCleanupRequestSource.selfServiceWeb,
      ProviderCleanupRequestSource.selfServiceWeb,
    ]);
    expect(repository.remoteCalls, 1);
    expect(find.text('Account deletion complete'), findsOneWidget);
  });

  testWidgets(
    'mobile handoff failure blocks deletion and exposes retry/support',
    (tester) async {
      repository.handoffFailure = const AccountDeletionFailure(
        AccountDeletionFailureType.providerCleanupRequest,
        'The provider cleanup request could not be recorded.',
      );
      await pumpDeletion(tester);
      await tester.pumpAndSettle();
      await confirmDeletion(tester);
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.textContaining('Adapty cleanup was not queued'),
      );
      expect(repository.sources, [
        ProviderCleanupRequestSource.selfServiceMobile,
      ]);
      expect(repository.remoteCalls, 0);
      expect(
        find.byKey(const ValueKey('retry-account-deletion')),
        findsOneWidget,
      );
      expect(find.text('support@example.test'), findsOneWidget);
    },
  );

  testWidgets(
    'renders every destructive phase and completes after Auth sign-out',
    (tester) async {
      repository
        ..handoffGate = Completer<void>()
        ..remoteGate = Completer<void>()
        ..authGate = Completer<void>();
      images.gate = Completer<void>();
      await pumpDeletion(tester);
      await tester.pumpAndSettle();
      await confirmDeletion(tester);
      expect(find.text('Recording provider cleanup request…'), findsOneWidget);

      repository.handoffGate!.complete();
      await tester.pump();
      expect(find.text('Deleting and verifying account data…'), findsOneWidget);

      repository.remoteGate!.complete();
      await tester.pump();
      expect(
        find.text('Clearing account data from this device…'),
        findsOneWidget,
      );

      images.gate!.complete();
      await tester.pump();
      expect(find.text('Deleting your sign-in identity…'), findsOneWidget);

      repository.authGate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Your PlantCare AI account and application data were deleted.',
        ),
        findsOneWidget,
      );
      expect(
        repository.calls,
        containsAllInOrder([
          'handoff',
          'remote',
          'verify',
          'auth',
          'signedOut',
        ]),
      );
      expect(images.users, ['uid-a']);
      expect(notifications.users, ['uid-a']);
    },
  );

  testWidgets('partial remote and Auth failures expose honest retry', (
    tester,
  ) async {
    repository.remoteFailure = const AccountDeletionFailure(
      AccountDeletionFailureType.remoteDeletion,
      'Some account data could not be deleted. Sign in and retry to finish.',
    );
    await pumpDeletion(tester);
    await tester.pumpAndSettle();
    await confirmDeletion(tester);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('retry-account-deletion')),
      findsOneWidget,
    );
    expect(repository.authCalls, 0);

    repository.remoteFailure = null;
    repository.authFailure = const AccountDeletionFailure(
      AccountDeletionFailureType.authenticationDeletion,
      'The account identity could not be deleted. Sign in again and retry.',
    );
    await tester.tap(find.byKey(const ValueKey('retry-account-deletion')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('identity could not be deleted'),
      findsOneWidget,
    );
    expect(find.text('Account deletion complete'), findsNothing);

    repository.authFailure = null;
    await tester.tap(find.byKey(const ValueKey('retry-account-deletion')));
    await tester.pumpAndSettle();
    expect(repository.remoteCalls, 2);
    expect(
      find.textContaining('application data were deleted'),
      findsOneWidget,
    );
  });
}

final class _Repository implements AccountDeletionRepository {
  Set<AccountReauthenticationMethod> methods = {
    AccountReauthenticationMethod.password,
  };
  bool googleResult = true;
  AccountDeletionFailure? passwordFailure;
  AccountDeletionFailure? handoffFailure;
  AccountDeletionFailure? remoteFailure;
  AccountDeletionFailure? authFailure;
  Completer<void>? handoffGate;
  Completer<void>? remoteGate;
  Completer<void>? authGate;
  final calls = <String>[];
  final sources = <ProviderCleanupRequestSource>[];
  int remoteCalls = 0;
  int authCalls = 0;

  @override
  String get currentUserId => 'uid-a';
  @override
  Set<AccountReauthenticationMethod> get linkedReauthenticationMethods =>
      methods;
  @override
  Future<void> refreshSession() async => calls.add('refresh');
  @override
  Future<void> reauthenticateWithPassword(String password) async {
    calls.add('password');
    if (passwordFailure case final failure?) throw failure;
  }

  @override
  Future<bool> reauthenticateWithGoogle() async {
    calls.add('google');
    return googleResult;
  }

  @override
  Future<void> recordProviderCleanupRequest(
    ProviderCleanupRequestSource source,
  ) async {
    calls.add('handoff');
    sources.add(source);
    if (handoffFailure case final failure?) throw failure;
    await handoffGate?.future;
  }

  @override
  Future<void> deleteRemoteApplicationData() async {
    calls.add('remote');
    remoteCalls += 1;
    if (remoteFailure case final failure?) throw failure;
    await remoteGate?.future;
  }

  @override
  Future<void> verifyRemoteApplicationDataDeleted() async =>
      calls.add('verify');
  @override
  Future<void> deleteCurrentAuthenticationUser() async {
    calls.add('auth');
    authCalls += 1;
    if (authFailure case final failure?) throw failure;
    await authGate?.future;
  }

  @override
  Future<void> waitUntilSignedOut() async => calls.add('signedOut');
}

final class _Launcher implements AccountDestinationLauncher {
  String? support = 'support@example.test';
  final destinations = <String>[];
  @override
  bool get hasPrivacyPolicy => true;
  @override
  bool get hasSupportEmail => support != null;
  @override
  String? get supportEmail => support;
  @override
  bool get hasTermsOfService => true;
  @override
  Future<void> openGooglePlaySubscriptions() async =>
      destinations.add('subscriptions');
  @override
  Future<void> openPrivacyPolicy() async => destinations.add('privacy');
  @override
  Future<void> openSupportRequest() async => destinations.add('support');
  @override
  Future<void> openTermsOfService() async => destinations.add('terms');
}

final class _Images implements LocalPlantImageRepository {
  Completer<void>? gate;
  final users = <String>[];
  @override
  LocalPlantImageStorageKind get storageKind =>
      LocalPlantImageStorageKind.sessionOnly;
  @override
  Future<void> deleteAllForUser(String userId) async {
    users.add(userId);
    await gate?.future;
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
  final users = <String>[];
  @override
  bool get isSupported => false;
  @override
  Stream<String> get notificationTapPayloads => const Stream.empty();
  @override
  Future<void> clearUser(String userId) async => users.add(userId);
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
  PurchasePlatform platformValue = PurchasePlatform.web;
  bool active = false;
  Object? refreshFailure;
  @override
  PurchasePlatform get platform => platformValue;
  @override
  PremiumAccessSnapshot get currentAccess => active
      ? const PremiumAccessSnapshot(
          userId: 'uid-a',
          status: PremiumAccessStatus.active,
        )
      : const PremiumAccessSnapshot.signedOut();
  @override
  Stream<PremiumAccessSnapshot> get accessChanges => const Stream.empty();
  @override
  Stream<PaywallEvent> get paywallEvents => const Stream.empty();
  @override
  Future<void> refreshProfile() async {
    if (refreshFailure case final failure?) throw failure;
  }

  @override
  Future<void> dispose() async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<PaywallPreparation> preparePaywall() async =>
      const PaywallPreparation(PaywallAvailability.unsupported);
  @override
  Future<void> presentPaywall() async {}
  @override
  Future<RestorePurchasesResult> restorePurchases() async =>
      const RestorePurchasesResult(hasPremium: false);
}
