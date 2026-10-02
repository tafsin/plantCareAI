import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:plantcare_features/premium_subscriptions.dart';

import '../../helpers/fake_premium_dependencies.dart';

void main() {
  group('PremiumAccessBloc', () {
    late FakePremiumSubscriptionRepository repository;

    blocTest<PremiumAccessBloc, PremiumAccessState>(
      'follows inactive, active, warning, expiration and account changes',
      build: () {
        repository = FakePremiumSubscriptionRepository();
        return PremiumAccessBloc(repository)..add(const PremiumAccessStarted());
      },
      act: (bloc) async {
        repository.emitAccess(
          const PremiumAccessSnapshot(
            userId: 'user-1',
            status: PremiumAccessStatus.inactive,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        repository.emitAccess(
          const PremiumAccessSnapshot(
            userId: 'user-1',
            status: PremiumAccessStatus.active,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        repository.emitAccess(
          const PremiumAccessSnapshot(
            userId: 'user-1',
            status: PremiumAccessStatus.active,
            warningMessage: 'offline',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        repository.emitAccess(
          const PremiumAccessSnapshot(
            userId: 'user-1',
            status: PremiumAccessStatus.inactive,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        repository.emitAccess(const PremiumAccessSnapshot.signedOut());
        await Future<void>.delayed(Duration.zero);
        repository.emitAccess(
          const PremiumAccessSnapshot(
            userId: 'user-2',
            status: PremiumAccessStatus.checking,
          ),
        );
      },
      expect: () => [
        isA<PremiumAccessState>().having(
          (state) => state.snapshot.status,
          'inactive',
          PremiumAccessStatus.inactive,
        ),
        isA<PremiumAccessState>().having(
          (state) => state.snapshot.isActive,
          'active',
          isTrue,
        ),
        isA<PremiumAccessState>().having(
          (state) => state.snapshot.warningMessage,
          'warning',
          'offline',
        ),
        isA<PremiumAccessState>().having(
          (state) => state.snapshot.isActive,
          'expired',
          isFalse,
        ),
        isA<PremiumAccessState>().having(
          (state) => state.snapshot.userId,
          'signed out',
          isNull,
        ),
        isA<PremiumAccessState>().having(
          (state) => state.snapshot.userId,
          'new user',
          'user-2',
        ),
      ],
    );
  });

  group('PaywallBloc', () {
    late FakePremiumSubscriptionRepository repository;
    late FakePremiumDestinationLauncher launcher;

    setUp(() {
      repository = FakePremiumSubscriptionRepository();
      launcher = FakePremiumDestinationLauncher();
    });

    blocTest<PaywallBloc, PaywallState>(
      'loads localized offer and purchases once per event',
      build: () => PaywallBloc(repository, launcher),
      act: (bloc) async {
        bloc.add(const PaywallLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PaywallPurchaseRequested());
      },
      expect: () => [
        isA<PaywallState>().having(
          (state) => state.status,
          'loading',
          PaywallStatus.loading,
        ),
        isA<PaywallState>()
            .having((state) => state.status, 'ready', PaywallStatus.ready)
            .having(
              (state) => state.offer?.localizedPrice,
              'localized price',
              r'$1.99',
            ),
        isA<PaywallState>().having(
          (state) => state.status,
          'purchasing',
          PaywallStatus.purchasing,
        ),
        isA<PaywallState>().having(
          (state) => state.status,
          'active',
          PaywallStatus.premiumActive,
        ),
      ],
      verify: (_) => expect(repository.purchaseCalls, 1),
    );

    for (final entry in {
      PaywallAvailability.paywallUnavailable: PaywallStatus.paywallUnavailable,
      PaywallAvailability.productUnavailable: PaywallStatus.productUnavailable,
    }.entries) {
      blocTest<PaywallBloc, PaywallState>(
        'maps ${entry.key.name} distinctly',
        setUp: () => repository.preparation = PaywallPreparation(
          entry.key,
          message: 'Unavailable',
        ),
        build: () => PaywallBloc(repository, launcher),
        act: (bloc) => bloc.add(const PaywallLoadRequested()),
        expect: () => [
          isA<PaywallState>().having(
            (state) => state.status,
            'loading',
            PaywallStatus.loading,
          ),
          isA<PaywallState>().having(
            (state) => state.status,
            'result',
            entry.value,
          ),
        ],
      );
    }

    for (final entry in <PremiumPurchaseResult, PaywallStatus>{
      const PremiumPurchasePending(): PaywallStatus.pending,
      const PremiumPurchaseCancelled(): PaywallStatus.ready,
    }.entries) {
      blocTest<PaywallBloc, PaywallState>(
        'maps ${entry.key.runtimeType} without a technical error',
        setUp: () => repository.purchaseResult = entry.key,
        build: () => PaywallBloc(repository, launcher),
        seed: () => PaywallState(
          platform: PurchasePlatform.android,
          hasPrivacyPolicy: true,
          hasTermsOfService: true,
          status: PaywallStatus.ready,
          offer: repository.preparation.offer,
        ),
        act: (bloc) {
          bloc.add(const PaywallPurchaseRequested());
          bloc.add(const PaywallPurchaseRequested());
        },
        expect: () => [
          isA<PaywallState>().having(
            (state) => state.status,
            'purchasing',
            PaywallStatus.purchasing,
          ),
          isA<PaywallState>().having(
            (state) => state.status,
            'result',
            entry.value,
          ),
        ],
        verify: (_) => expect(repository.purchaseCalls, 1),
      );
    }

    blocTest<PaywallBloc, PaywallState>(
      'purchase failure is recoverable',
      setUp: () => repository.purchaseError = const PremiumSubscriptionFailure(
        PremiumFailureType.purchaseFailed,
        'Purchase failed.',
      ),
      build: () => PaywallBloc(repository, launcher),
      seed: () => PaywallState(
        platform: PurchasePlatform.android,
        hasPrivacyPolicy: true,
        hasTermsOfService: true,
        status: PaywallStatus.ready,
        offer: repository.preparation.offer,
      ),
      act: (bloc) => bloc.add(const PaywallPurchaseRequested()),
      expect: () => [
        isA<PaywallState>().having(
          (state) => state.status,
          'purchasing',
          PaywallStatus.purchasing,
        ),
        isA<PaywallState>()
            .having((state) => state.status, 'failure', PaywallStatus.failure)
            .having((state) => state.message, 'message', 'Purchase failed.'),
      ],
    );

    blocTest<PaywallBloc, PaywallState>(
      'restores active access and launches all destinations',
      setUp: () => repository.restoreResult = const RestorePurchasesResult(
        hasPremium: true,
      ),
      build: () => PaywallBloc(repository, launcher),
      act: (bloc) async {
        bloc.add(const PaywallRestoreRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const PaywallManageRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PaywallPrivacyRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PaywallTermsRequested());
      },
      verify: (_) {
        expect(repository.restoreCalls, 1);
        expect(
          launcher.calls,
          containsAll(['manage:null', 'privacy', 'terms']),
        );
      },
    );

    blocTest<PaywallBloc, PaywallState>(
      'reports no active restore neutrally and suppresses duplicate restore',
      build: () => PaywallBloc(repository, launcher),
      act: (bloc) {
        bloc.add(const PaywallRestoreRequested());
        bloc.add(const PaywallRestoreRequested());
      },
      verify: (_) => expect(repository.restoreCalls, 1),
      expect: () => [
        isA<PaywallState>().having(
          (state) => state.status,
          'restoring',
          PaywallStatus.restoring,
        ),
        isA<PaywallState>()
            .having((state) => state.status, 'ready', PaywallStatus.ready)
            .having(
              (state) => state.message,
              'neutral result',
              'No active premium purchase was found.',
            ),
      ],
    );

    blocTest<PaywallBloc, PaywallState>(
      'link failure is recoverable and a subsequent load retries',
      setUp: () => launcher.error = const PremiumSubscriptionFailure(
        PremiumFailureType.launch,
        'Could not open link.',
      ),
      build: () => PaywallBloc(repository, launcher),
      act: (bloc) async {
        bloc.add(const PaywallPrivacyRequested());
        await Future<void>.delayed(Duration.zero);
        launcher.error = null;
        bloc.add(const PaywallLoadRequested());
      },
      expect: () => [
        isA<PaywallState>()
            .having((state) => state.status, 'failure', PaywallStatus.failure)
            .having(
              (state) => state.message,
              'message',
              'Could not open link.',
            ),
        isA<PaywallState>().having(
          (state) => state.status,
          'loading',
          PaywallStatus.loading,
        ),
        isA<PaywallState>().having(
          (state) => state.status,
          'ready',
          PaywallStatus.ready,
        ),
      ],
      verify: (_) => expect(repository.prepareCalls, 1),
    );

    blocTest<PaywallBloc, PaywallState>(
      'unsupported platform never loads or restores',
      setUp: () => repository = FakePremiumSubscriptionRepository(
        platform: PurchasePlatform.web,
      ),
      build: () => PaywallBloc(repository, launcher),
      act: (bloc) {
        bloc.add(const PaywallLoadRequested());
        bloc.add(const PaywallRestoreRequested());
      },
      expect: () => [
        isA<PaywallState>().having(
          (state) => state.status,
          'unsupported',
          PaywallStatus.unsupported,
        ),
      ],
      verify: (_) {
        expect(repository.prepareCalls, 0);
        expect(repository.restoreCalls, 0);
      },
    );
  });
}
