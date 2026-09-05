import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/authentication.dart';

/// Keeps native Google SDK credentials inside the data layer.
abstract interface class NativeGoogleIdentity {
  Future<String?> authenticate();
}

@LazySingleton(as: NativeGoogleIdentity)
final class SdkNativeGoogleIdentity implements NativeGoogleIdentity {
  Future<void>? _initialization;

  @override
  Future<String?> authenticate() async {
    try {
      // OAuth identifiers come from platform configuration, never invented here.
      await (_initialization ??= GoogleSignIn.instance.initialize());
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const AuthenticationFailure(
          AuthenticationFailureType.unknown,
          'Google could not verify your sign-in. Please try again.',
        );
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const AuthenticationFailure(
        AuthenticationFailureType.unknown,
        'Couldn’t connect to Google. Check your connection and try again, or continue with email.',
      );
    }
  }
}
