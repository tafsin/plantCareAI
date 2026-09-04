import 'package:plantcare_ai/features/authentication/domain/entities/app_user.dart';

abstract interface class AuthenticationSession {
  Stream<AppUser?> get authStateChanges;

  AppUser? get currentUser;

  bool get isSignedIn;
}
