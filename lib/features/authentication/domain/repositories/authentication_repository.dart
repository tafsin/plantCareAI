import 'package:plantcare_ai/features/authentication/domain/entities/app_user.dart';

abstract interface class AuthenticationRepository {
  Stream<AppUser?> get authStateChanges;

  AppUser? get currentUser;

  Future<AppUser> register({required String email, required String password});

  Future<AppUser> signIn({required String email, required String password});

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();
}
