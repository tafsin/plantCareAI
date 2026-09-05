import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_features/src/authentication/presentation/bloc/sign_in_bloc.dart';
import 'package:plantcare_features/src/authentication/presentation/pages/sign_in_page.dart';

import '../../../../helpers/fake_authentication_repository.dart';

void main() {
  Future<FakeAuthenticationRepository> mount(
    WidgetTester tester, {
    bool email = false,
  }) async {
    final repository = FakeAuthenticationRepository();
    final bloc = SignInBloc(repository);
    addTearDown(() async {
      await bloc.close();
      await repository.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: SignInPage(showEmail: email),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  for (final size in [
    const Size(390, 844),
    const Size(1280, 900),
    const Size(320, 568),
  ]) {
    testWidgets('Google first and email form accessible at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester);
      expect(find.byType(TextFormField), findsNothing);
      expect(
        tester.getTopLeft(find.text('Continue with Google')).dy,
        lessThan(tester.getTopLeft(find.text('or')).dy),
      );
      expect(
        tester.getTopLeft(find.text('or')).dy,
        lessThan(tester.getTopLeft(find.text('Continue with email')).dy),
      );
      await tester.ensureVisible(find.text('Continue with email'));
      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.ensureVisible(find.byKey(const ValueKey('sign-in-submit')));
      await tester.tap(find.byKey(const ValueKey('sign-in-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('email fields retain values and password visibility', (
    tester,
  ) async {
    await mount(tester, email: true);
    await tester.enterText(
      find.byKey(const ValueKey('sign-in-password')),
      'plant123',
    );
    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('sign-in-password')),
              matching: find.byType(TextField),
            ),
          )
          .obscureText,
      isFalse,
    );
    expect(find.text('plant123'), findsOneWidget);
  });

  testWidgets(
    'Google loading disables both methods and cancellation restores them',
    (tester) async {
      final repository = await mount(tester);
      final pending = Completer<void>();
      repository.googlePending = pending.future;
      repository.googleCancelled = true;
      await tester.tap(find.byKey(const ValueKey('continue-with-google')));
      await tester.pump();
      expect(find.text('Connecting to Google…'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('continue-with-google')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('continue-with-email')),
            )
            .onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth-error')), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('continue-with-email')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  for (final type in [
    AuthenticationFailureType.popupBlocked,
    AuthenticationFailureType.accountConflict,
    AuthenticationFailureType.network,
  ]) {
    testWidgets('$type is visible before opening email and can retry', (
      tester,
    ) async {
      final repository = await mount(tester);
      repository.googleError = AuthenticationFailure(
        type,
        'Recovery instructions',
      );
      await tester.tap(find.byKey(const ValueKey('continue-with-google')));
      await tester.pumpAndSettle();
      expect(find.text('Recovery instructions'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      repository.googleError = null;
      repository.googleCancelled = true;
      await tester.tap(find.byKey(const ValueKey('continue-with-google')));
      await tester.pumpAndSettle();
      expect(repository.googleCalls, 2);
      expect(find.byKey(const ValueKey('auth-error')), findsNothing);
    });
  }
}
