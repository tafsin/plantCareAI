import '../entities/app_user.dart';
import 'authentication_session.dart';

abstract interface class AuthenticationRepository
    implements AuthenticationSession {
  Future<AppUser> register({required String email, required String password});

  Future<AppUser> signIn({required String email, required String password});

  /// Returns null when the user dismisses Google authentication.
  Future<AppUser?> continueWithGoogle();

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();
}
