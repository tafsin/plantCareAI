import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_features/src/authentication/presentation/bloc/password_reset_bloc.dart';
import 'package:plantcare_features/src/authentication/presentation/bloc/register_bloc.dart';
import 'package:plantcare_features/src/authentication/presentation/bloc/sign_in_bloc.dart';

import '../../../../helpers/fake_authentication_repository.dart';

void main() {
  group('SignInBloc', () {
    late FakeAuthenticationRepository repository;

    setUp(() => repository = FakeAuthenticationRepository());
    tearDown(() => repository.close());

    blocTest<SignInBloc, SignInState>(
      'Google succeeds without email validation or separate registration',
      build: () => SignInBloc(repository),
      act: (bloc) => bloc.add(const GoogleSignInRequested()),
      expect: () => [
        const SignInSubmitting(isGoogle: true),
        SignInSuccess(repository.signInUser),
      ],
      verify: (_) {
        expect(repository.googleCalls, 1);
        expect(repository.registerCalls, 0);
        expect(repository.signInCalls, 0);
      },
    );

    blocTest<SignInBloc, SignInState>(
      'cancel is neutral and a subsequent attempt can succeed',
      setUp: () => repository.googleCancelled = true,
      build: () => SignInBloc(repository),
      act: (bloc) async {
        bloc.add(const GoogleSignInRequested());
        await bloc.stream.firstWhere((state) => state is SignInCancelled);
        repository.googleCancelled = false;
        bloc.add(const GoogleSignInRequested());
      },
      expect: () => [
        const SignInSubmitting(isGoogle: true),
        const SignInCancelled(),
        const SignInSubmitting(isGoogle: true),
        SignInSuccess(repository.signInUser),
      ],
    );

    for (final type in [
      AuthenticationFailureType.popupBlocked,
      AuthenticationFailureType.accountConflict,
      AuthenticationFailureType.network,
    ]) {
      blocTest<SignInBloc, SignInState>(
        'Google surfaces $type and permits retry',
        setUp: () => repository.googleError = AuthenticationFailure(
          type,
          'Safe recovery instructions',
        ),
        build: () => SignInBloc(repository),
        act: (bloc) async {
          bloc.add(const GoogleSignInRequested());
          await bloc.stream.firstWhere((state) => state is SignInFailure);
          repository.googleError = null;
          bloc.add(const GoogleSignInRequested());
        },
        expect: () => [
          const SignInSubmitting(isGoogle: true),
          const SignInFailure('Safe recovery instructions'),
          const SignInSubmitting(isGoogle: true),
          SignInSuccess(repository.signInUser),
        ],
      );
    }

    test('pending Google authentication rejects concurrent email and Google submissions', () async {
      final pending = Completer<void>();
      repository.googlePending = pending.future;
      final bloc = SignInBloc(repository);
      bloc.add(const GoogleSignInRequested());
      await bloc.stream.firstWhere((state) => state is SignInSubmitting);
      bloc.add(const GoogleSignInRequested());
      bloc.add(
        const SignInSubmitted(email: 'user@test.com', password: 'plant123'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repository.googleCalls, 1);
      expect(repository.signInCalls, 0);
      pending.complete();
      await bloc.stream.firstWhere((state) => state is SignInSuccess);
      await bloc.close();
    });

    blocTest<SignInBloc, SignInState>(
      'emits success after valid credentials are accepted',
      build: () => SignInBloc(repository),
      act: (bloc) => bloc.add(
        const SignInSubmitted(email: 'user@test.com', password: 'plant123'),
      ),
      expect: () => [
        const SignInSubmitting(),
        SignInSuccess(repository.signInUser),
      ],
      verify: (_) => expect(repository.signInCalls, 1),
    );

    blocTest<SignInBloc, SignInState>(
      'emits a mapped user-facing failure',
      setUp: () {
        repository.signInError = const AuthenticationFailure(
          AuthenticationFailureType.invalidCredentials,
          'We couldn\'t sign you in. Check your email and password and try again.',
        );
      },
      build: () => SignInBloc(repository),
      act: (bloc) => bloc.add(
        const SignInSubmitted(email: 'user@test.com', password: 'wrong123'),
      ),
      expect: () => const [
        SignInSubmitting(),
        SignInFailure(
          'We couldn\'t sign you in. Check your email and password and try again.',
        ),
      ],
    );
  });

  group('RegisterBloc', () {
    late FakeAuthenticationRepository repository;

    setUp(() => repository = FakeAuthenticationRepository());
    tearDown(() => repository.close());

    blocTest<RegisterBloc, RegisterState>(
      'rejects a password confirmation mismatch before calling repository',
      build: () => RegisterBloc(repository),
      act: (bloc) => bloc.add(
        const RegisterSubmitted(
          email: 'new@test.com',
          password: 'plant123',
          confirmPassword: 'plant124',
        ),
      ),
      expect: () => const [RegisterFailure('Passwords do not match.')],
      verify: (_) => expect(repository.registerCalls, 0),
    );

    blocTest<RegisterBloc, RegisterState>(
      'emits success after registration',
      build: () => RegisterBloc(repository),
      act: (bloc) => bloc.add(
        const RegisterSubmitted(
          email: 'new@test.com',
          password: 'plant123',
          confirmPassword: 'plant123',
        ),
      ),
      expect: () => [
        const RegisterSubmitting(),
        RegisterSuccess(repository.registeredUser),
      ],
      verify: (_) => expect(repository.registerCalls, 1),
    );
  });

  group('PasswordResetBloc', () {
    late FakeAuthenticationRepository repository;

    setUp(() => repository = FakeAuthenticationRepository());
    tearDown(() => repository.close());

    blocTest<PasswordResetBloc, PasswordResetState>(
      'emits success without exposing account existence',
      build: () => PasswordResetBloc(repository),
      act: (bloc) => bloc.add(const PasswordResetSubmitted('user@test.com')),
      expect: () => const [PasswordResetSubmitting(), PasswordResetSuccess()],
      verify: (_) {
        expect(repository.passwordResetCalls, 1);
        expect(
          passwordResetSuccessMessage,
          'If an account exists for that email, a reset link has been sent.',
        );
      },
    );
  });
}
