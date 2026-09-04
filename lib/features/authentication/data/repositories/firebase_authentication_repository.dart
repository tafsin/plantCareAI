import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/authentication/domain/entities/app_user.dart';
import 'package:plantcare_ai/features/authentication/domain/repositories/authentication_repository.dart';

@LazySingleton(as: AuthenticationRepository)
final class FirebaseAuthenticationRepository
    implements AuthenticationRepository {
  FirebaseAuthenticationRepository(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<AppUser?> get authStateChanges =>
      _firebaseAuth.authStateChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_firebaseAuth.currentUser);

  @override
  Future<AppUser> register({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _requiredUser(credential.user);
    } on FirebaseAuthException catch (error, stackTrace) {
      _logFirebaseError('register', error, stackTrace);
      throw mapFirebaseAuthException(error);
    } catch (error, stackTrace) {
      _logUnexpectedError('register', error, stackTrace);
      throw const AuthenticationFailure(
        AuthenticationFailureType.unknown,
        'Couldn\'t create your account. Please try again.',
      );
    }
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _requiredUser(credential.user);
    } on FirebaseAuthException catch (error, stackTrace) {
      _logFirebaseError('sign in', error, stackTrace);
      throw mapFirebaseAuthException(error);
    } catch (error, stackTrace) {
      _logUnexpectedError('sign in', error, stackTrace);
      throw const AuthenticationFailure(
        AuthenticationFailureType.unknown,
        'Couldn\'t sign you in. Please try again.',
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error, stackTrace) {
      _logFirebaseError('send password reset email', error, stackTrace);
      if (error.code == 'user-not-found') {
        return;
      }
      throw mapFirebaseAuthException(error);
    } catch (error, stackTrace) {
      _logUnexpectedError('send password reset email', error, stackTrace);
      throw const AuthenticationFailure(
        AuthenticationFailureType.unknown,
        'Couldn\'t send the reset email. Please try again.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (error, stackTrace) {
      _logFirebaseError('sign out', error, stackTrace);
      throw mapFirebaseAuthException(error);
    } catch (error, stackTrace) {
      _logUnexpectedError('sign out', error, stackTrace);
      throw const AuthenticationFailure(
        AuthenticationFailureType.unknown,
        'Couldn\'t sign out. Please try again.',
      );
    }
  }

  static AppUser? _toAppUser(User? user) =>
      user == null ? null : AppUser(uid: user.uid, email: user.email);

  static AppUser _requiredUser(User? user) {
    final appUser = _toAppUser(user);
    if (appUser == null) {
      throw const AuthenticationFailure(
        AuthenticationFailureType.unknown,
        'Authentication completed without a user.',
      );
    }
    return appUser;
  }

  static void _logFirebaseError(
    String operation,
    FirebaseAuthException error,
    StackTrace stackTrace,
  ) {
    developer.log(
      'Firebase Authentication failed during $operation: ${error.code}',
      name: 'plantcare_ai.authentication',
      error: error.code,
      stackTrace: stackTrace,
    );
  }

  static void _logUnexpectedError(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    developer.log(
      'Unexpected authentication failure during $operation',
      name: 'plantcare_ai.authentication',
      error: error.runtimeType,
      stackTrace: stackTrace,
    );
  }
}

AuthenticationFailure mapFirebaseAuthException(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-email' => const AuthenticationFailure(
      AuthenticationFailureType.invalidEmail,
      'Enter a valid email address.',
    ),
    'weak-password' => const AuthenticationFailure(
      AuthenticationFailureType.weakPassword,
      'Use at least 6 characters with a letter and a number.',
    ),
    'email-already-in-use' => const AuthenticationFailure(
      AuthenticationFailureType.emailAlreadyInUse,
      'An account already uses this email. Try signing in instead.',
    ),
    'invalid-credential' ||
    'user-not-found' ||
    'wrong-password' => const AuthenticationFailure(
      AuthenticationFailureType.invalidCredentials,
      'We couldn\'t sign you in. Check your email and password and try again.',
    ),
    'user-disabled' => const AuthenticationFailure(
      AuthenticationFailureType.userDisabled,
      'This account has been disabled. Contact support.',
    ),
    'too-many-requests' => const AuthenticationFailure(
      AuthenticationFailureType.tooManyRequests,
      'Too many attempts. Wait a moment and try again.',
    ),
    'network-request-failed' => const AuthenticationFailure(
      AuthenticationFailureType.network,
      'Check your connection and try again.',
    ),
    _ => const AuthenticationFailure(
      AuthenticationFailureType.unknown,
      'Something went wrong. Please try again.',
    ),
  };
}
