import 'package:plantcare_ai/features/authentication/domain/entities/app_user.dart';
import 'package:plantcare_ai/features/authentication/domain/repositories/authentication_session.dart';

abstract interface class AuthenticationRepository
    implements AuthenticationSession {
  Future<AppUser> register({required String email, required String password});

  Future<AppUser> signIn({required String email, required String password});

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();
}
