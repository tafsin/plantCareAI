import 'dart:async';

import 'package:plantcare_domain/authentication.dart';

final class FakeAuthenticationRepository implements AuthenticationRepository {
  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast(sync: true);

  @override
  AppUser? currentUser;

  @override
  bool get isSignedIn => currentUser != null;

  AppUser signInUser = const AppUser(uid: 'signed-in', email: 'user@test.com');
  AppUser registeredUser = const AppUser(
    uid: 'registered',
    email: 'new@test.com',
  );
  Object? signInError;
  Object? registerError;
  Object? passwordResetError;
  Object? signOutError;
  var signInCalls = 0;
  var registerCalls = 0;
  var passwordResetCalls = 0;
  var signOutCalls = 0;
  var emitSessionOnSignIn = true;
  var emitSessionOnRegister = true;
  var emitSessionOnSignOut = true;

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  void emitAuthState(AppUser? user) {
    currentUser = user;
    _controller.add(user);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (signInError case final Object error) {
      throw error;
    }
    currentUser = signInUser;
    if (emitSessionOnSignIn) {
      _controller.add(signInUser);
    }
    return signInUser;
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
  }) async {
    registerCalls++;
    if (registerError case final Object error) {
      throw error;
    }
    currentUser = registeredUser;
    if (emitSessionOnRegister) {
      _controller.add(registeredUser);
    }
    return registeredUser;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    passwordResetCalls++;
    if (passwordResetError case final Object error) {
      throw error;
    }
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError case final Object error) {
      throw error;
    }
    currentUser = null;
    if (emitSessionOnSignOut) {
      _controller.add(null);
    }
  }

  Future<void> close() => _controller.close();
}
