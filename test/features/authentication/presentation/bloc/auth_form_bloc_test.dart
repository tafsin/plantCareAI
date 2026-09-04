import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/authentication/domain/errors/authentication_failure.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/password_reset_bloc.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/register_bloc.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/sign_in_bloc.dart';

import '../../../../helpers/fake_authentication_repository.dart';

void main() {
  group('SignInBloc', () {
    late FakeAuthenticationRepository repository;

    setUp(() => repository = FakeAuthenticationRepository());
    tearDown(() => repository.close());

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
