import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_data/src/authentication/repositories/firebase_authentication_repository.dart';
import 'package:plantcare_data/src/authentication/services/native_google_identity.dart';
import 'package:plantcare_domain/authentication.dart';

void main() {
  test(
    'native Google credential returns the Firebase account identity',
    () async {
      final auth = FakeFirebaseAuth();
      final repository = FirebaseAuthenticationRepository(
        auth,
        FakeGoogleIdentity(),
      );
      final user = await repository.continueWithGoogle();
      expect(user?.uid, 'existing-firebase-uid');
      expect(auth.credential?.providerId, 'google.com');
      expect((auth.credential as OAuthCredential).idToken, 'test-token');
      expect(auth.calls, 1);
    },
  );

  test('native cancellation never starts Firebase authentication', () async {
    final auth = FakeFirebaseAuth();
    final repository = FirebaseAuthenticationRepository(
      auth,
      FakeGoogleIdentity()..token = null,
    );
    expect(await repository.continueWithGoogle(), isNull);
    expect(auth.calls, 0);
  });

  for (final code in [
    'network-request-failed',
    'account-exists-with-different-credential',
  ]) {
    test('$code remains a safe failure, never merges accounts', () async {
      final auth = FakeFirebaseAuth()
        ..error = FirebaseAuthException(
          code: code,
          message: 'sensitive-detail',
        );
      final repository = FirebaseAuthenticationRepository(
        auth,
        FakeGoogleIdentity(),
      );
      await expectLater(
        repository.continueWithGoogle(),
        throwsA(
          isA<AuthenticationFailure>().having(
            (e) => e.message,
            'safe message',
            isNot(contains('sensitive-detail')),
          ),
        ),
      );
      expect(auth.calls, 1);
    });
  }
}

class FakeGoogleIdentity implements NativeGoogleIdentity {
  String? token = 'test-token';
  @override
  Future<String?> authenticate() async => token;
}

class FakeFirebaseAuth implements FirebaseAuth {
  AuthCredential? credential;
  FirebaseAuthException? error;
  int calls = 0;
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    calls++;
    this.credential = credential;
    if (error case final error?) throw error;
    return FakeUserCredential();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserCredential implements UserCredential {
  @override
  User get user => FakeUser();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUser implements User {
  @override
  String get uid => 'existing-firebase-uid';
  @override
  String get email => 'user@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
