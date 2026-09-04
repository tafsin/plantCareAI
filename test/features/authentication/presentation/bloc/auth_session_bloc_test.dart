import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/authentication/domain/entities/app_user.dart';
import 'package:plantcare_ai/features/authentication/domain/errors/authentication_failure.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/auth_session_bloc.dart';

import '../../../../helpers/fake_authentication_repository.dart';

void main() {
  const user = AppUser(uid: 'user-1', email: 'user@test.com');

  test('starts in the checking state', () {
    final repository = FakeAuthenticationRepository();
    final bloc = AuthSessionBloc(repository);
    addTearDown(() async {
      await bloc.close();
      await repository.close();
    });

    expect(bloc.state, const AuthSessionChecking());
  });

  test('transitions to authenticated from the auth stream', () async {
    final repository = FakeAuthenticationRepository();
    final bloc = AuthSessionBloc(repository);
    addTearDown(() async {
      await bloc.close();
      await repository.close();
    });
    await Future<void>.delayed(Duration.zero);

    repository.emitAuthState(user);
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, const AuthSessionAuthenticated(user: user));
  });

  test('tracks authenticated, logout, and unauthenticated states', () async {
    final repository = FakeAuthenticationRepository();
    final bloc = AuthSessionBloc(repository);
    addTearDown(() async {
      await bloc.close();
      await repository.close();
    });
    await Future<void>.delayed(Duration.zero);

    repository.emitAuthState(user);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, const AuthSessionAuthenticated(user: user));

    bloc.add(const AuthSessionLogoutRequested());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(repository.signOutCalls, 1);
    expect(bloc.state, const AuthSessionUnauthenticated());
  });

  test('keeps the authenticated session when logout fails', () async {
    final repository = FakeAuthenticationRepository()
      ..signOutError = const AuthenticationFailure(
        AuthenticationFailureType.network,
        'Check your connection and try again.',
      );
    final bloc = AuthSessionBloc(repository);
    addTearDown(() async {
      await bloc.close();
      await repository.close();
    });
    await Future<void>.delayed(Duration.zero);
    repository.emitAuthState(user);
    await Future<void>.delayed(Duration.zero);

    bloc.add(const AuthSessionLogoutRequested());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      bloc.state,
      const AuthSessionAuthenticated(user: user, logoutFailureCount: 1),
    );
  });
}
