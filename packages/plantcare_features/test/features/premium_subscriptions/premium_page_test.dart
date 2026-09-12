import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:plantcare_features/premium_subscriptions.dart';

import '../../helpers/fake_premium_dependencies.dart';

void main() {
  testWidgets('shows all informational plan benefits and localized offer', (
    tester,
  ) async {
    final harness = await _pump(tester, platform: PurchasePlatform.android);
    await tester.pumpAndSettle();

    for (final label in [
      'Free',
      'Up to 3 saved plants',
      'AI and care features included',
      'Premium',
      'Unlimited saved plants',
      'Everything in Free',
      r'$1.99 / month',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    for (final inaccurateClaim in [
      'AI identification and diagnosis',
      'Advanced care guidance',
      'Complete history',
    ]) {
      expect(find.text(inaccurateClaim), findsNothing);
    }
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'View Premium'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('View Premium'));
    await tester.pump();
    expect(harness.repository.presentCalls, 1);
  });

  testWidgets('web explains mobile availability and disables store actions', (
    tester,
  ) async {
    await _pump(tester, platform: PurchasePlatform.web, width: 1200);
    await tester.pumpAndSettle();

    expect(
      find.text('Mobile purchasing is not currently available on web.'),
      findsOneWidget,
    );
    expect(find.text('View Premium'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('restore-purchases')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('iOS disables purchasing and describes Android support', (
    tester,
  ) async {
    await _pump(tester, platform: PurchasePlatform.ios);
    await tester.pumpAndSettle();

    expect(
      find.text('Premium purchasing is currently available on Android.'),
      findsOneWidget,
    );
    expect(find.text('View Premium'), findsNothing);
  });

  testWidgets('missing legal configuration disables legal actions', (
    tester,
  ) async {
    final repository = FakePremiumSubscriptionRepository();
    final launcher = FakePremiumDestinationLauncher(
      hasPrivacyPolicy: false,
      hasTermsOfService: false,
    );
    await _pump(
      tester,
      platform: PurchasePlatform.android,
      repository: repository,
      launcher: launcher,
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('privacy-policy')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('terms-of-service')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('loading exposes progress and unavailable state retries', (
    tester,
  ) async {
    final repository = FakePremiumSubscriptionRepository();
    repository.preparation = const PaywallPreparation(
      PaywallAvailability.productUnavailable,
      message: 'Product unavailable',
    );
    await _pump(
      tester,
      platform: PurchasePlatform.android,
      repository: repository,
    );
    await tester.pumpAndSettle();

    expect(find.text('Product unavailable'), findsOneWidget);
    expect(find.byKey(const ValueKey('premium-retry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('premium-retry')));
    await tester.pumpAndSettle();
    expect(repository.prepareCalls, 2);
  });

  testWidgets(
    'purchase events show pending, neutral cancellation and success',
    (tester) async {
      final harness = await _pump(tester, platform: PurchasePlatform.android);
      await tester.pumpAndSettle();

      harness.repository.emitEvent(const PaywallPurchaseStarted());
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('premium-progress')), findsOneWidget);

      harness.repository.emitEvent(const PaywallPurchasePending());
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Your purchase is pending in Google Play.'),
        findsOneWidget,
      );

      harness.repository.emitEvent(const PaywallPurchaseCancelled());
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('premium-status-message')),
        findsNothing,
      );

      harness.repository.emitAccess(
        const PremiumAccessSnapshot(
          userId: 'user-1',
          status: PremiumAccessStatus.active,
        ),
      );
      harness.repository.emitEvent(const PaywallPurchaseVerified());
      await tester.pump();
      expect(find.text('Premium is active'), findsWidgets);

      harness.repository.emitEvent(
        const PaywallOperationFailed('refresh failed'),
      );
      harness.repository.emitEvent(const PaywallDismissed());
      await tester.pump();
      expect(find.text('Premium is active'), findsWidgets);
    },
  );

  testWidgets('legal and management controls dispatch through the BLoC', (
    tester,
  ) async {
    final harness = await _pump(tester, platform: PurchasePlatform.android);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manage-subscription')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('privacy-policy')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('terms-of-service')));
    await tester.pumpAndSettle();

    expect(
      harness.launcher.calls,
      containsAll(['manage:plantcare_premium', 'privacy', 'terms']),
    );
  });

  testWidgets('narrow layout with large text remains scrollable', (
    tester,
  ) async {
    await _pump(
      tester,
      platform: PurchasePlatform.android,
      width: 320,
      textScaler: const TextScaler.linear(2),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Free plan'), findsOneWidget);
    expect(find.bySemanticsLabel('Premium plan'), findsOneWidget);
  });

  testWidgets('keyboard traversal reaches purchase and support actions', (
    tester,
  ) async {
    await _pump(tester, platform: PurchasePlatform.android, width: 1200);
    await tester.pumpAndSettle();

    for (final key in const [
      ValueKey('present-premium-flow'),
      ValueKey('restore-purchases'),
      ValueKey('manage-subscription'),
    ]) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester.getSemantics(find.byKey(key)).flagsCollection.isFocused,
        Tristate.isTrue,
        reason: '$key should be next in traversal order',
      );
    }
  });
}

Future<
  ({
    FakePremiumSubscriptionRepository repository,
    FakePremiumDestinationLauncher launcher,
  })
>
_pump(
  WidgetTester tester, {
  required PurchasePlatform platform,
  FakePremiumSubscriptionRepository? repository,
  FakePremiumDestinationLauncher? launcher,
  double width = 390,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final subscription =
      repository ??
      FakePremiumSubscriptionRepository(
        platform: platform,
        currentAccess: const PremiumAccessSnapshot(
          userId: 'user-1',
          status: PremiumAccessStatus.inactive,
        ),
      );
  final destinationLauncher = launcher ?? FakePremiumDestinationLauncher();
  final accessBloc = PremiumAccessBloc(subscription)
    ..add(const PremiumAccessStarted());
  final paywallBloc = PaywallBloc(subscription, destinationLauncher)
    ..add(const PaywallLoadRequested());
  addTearDown(() async {
    await accessBloc.close();
    await paywallBloc.close();
    await subscription.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: accessBloc),
            BlocProvider.value(value: paywallBloc),
          ],
          child: const Scaffold(body: PremiumPage()),
        ),
      ),
    ),
  );
  return (repository: subscription, launcher: destinationLauncher);
}
