import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_data/src/authentication/repositories/firebase_authentication_repository.dart';
import 'package:plantcare_domain/authentication.dart';

void main() {
  test('Google cancellation codes are neutral outcomes', () {
    for (final code in [
      'popup-closed-by-user',
      'cancelled-popup-request',
      'web-context-cancelled',
      'user-cancelled',
    ]) {
      expect(isGoogleCancellation(code), isTrue);
    }
    expect(isGoogleCancellation('network-request-failed'), isFalse);
    expect(isGoogleCancellation('popup-blocked'), isFalse);
  });

  test('maps Firebase auth codes without leaking raw details', () {
    final cases = <String, AuthenticationFailureType>{
      'popup-blocked': AuthenticationFailureType.popupBlocked,
      'account-exists-with-different-credential':
          AuthenticationFailureType.accountConflict,
      'credential-already-in-use': AuthenticationFailureType.accountConflict,
      'invalid-email': AuthenticationFailureType.invalidEmail,
      'weak-password': AuthenticationFailureType.weakPassword,
      'email-already-in-use': AuthenticationFailureType.emailAlreadyInUse,
      'invalid-credential': AuthenticationFailureType.invalidCredentials,
      'user-not-found': AuthenticationFailureType.invalidCredentials,
      'wrong-password': AuthenticationFailureType.invalidCredentials,
      'user-disabled': AuthenticationFailureType.userDisabled,
      'too-many-requests': AuthenticationFailureType.tooManyRequests,
      'network-request-failed': AuthenticationFailureType.network,
      'new-server-code': AuthenticationFailureType.unknown,
    };

    for (final entry in cases.entries) {
      final failure = mapFirebaseAuthException(
        FirebaseAuthException(code: entry.key, message: 'raw Firebase detail'),
      );
      expect(failure.type, entry.value);
      expect(failure.message, isNot(contains('raw Firebase detail')));
      expect(failure.message, isNot(contains(entry.key)));
    }
  });
}
