import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../authentication/services/native_google_identity.dart';

@visibleForTesting
bool isGoogleReauthenticationCancellationCode(String code) => const <String>{
  'popup-closed-by-user',
  'cancelled-popup-request',
  'web-context-cancelled',
  'user-cancelled',
}.contains(code);

final class AccountAuthenticationSnapshot {
  const AccountAuthenticationSnapshot({
    required this.uid,
    required this.email,
    required this.providerIds,
  });

  final String uid;
  final String? email;
  final Set<String> providerIds;
}

final class AccountAuthenticationGatewayException implements Exception {
  const AccountAuthenticationGatewayException(this.code);

  final String code;
}

abstract interface class AccountAuthenticationGateway {
  AccountAuthenticationSnapshot? get currentSession;

  Future<void> refreshSession(String expectedUid);

  Future<void> reauthenticateWithPassword(String expectedUid, String password);

  /// Returns false when the user cancels the provider interaction.
  Future<bool> reauthenticateWithGoogle(String expectedUid);

  Future<void> deleteCurrentUser(String expectedUid);

  Future<void> waitUntilSignedOut();
}

final class FirebaseAccountAuthenticationGateway
    implements AccountAuthenticationGateway {
  FirebaseAccountAuthenticationGateway(this._auth, this._googleIdentity);

  final FirebaseAuth _auth;
  final NativeGoogleIdentity _googleIdentity;

  @override
  AccountAuthenticationSnapshot? get currentSession {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AccountAuthenticationSnapshot(
      uid: user.uid,
      email: user.email,
      providerIds: user.providerData
          .map((provider) => provider.providerId)
          .toSet(),
    );
  }

  User _user(String expectedUid) {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountAuthenticationGatewayException('unauthenticated');
    }
    if (user.uid != expectedUid) {
      throw const AccountAuthenticationGatewayException('identity-changed');
    }
    return user;
  }

  @override
  Future<void> refreshSession(String expectedUid) async {
    try {
      await _user(expectedUid).getIdToken(true);
      _user(expectedUid);
    } on AccountAuthenticationGatewayException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AccountAuthenticationGatewayException(error.code);
    }
  }

  @override
  Future<void> reauthenticateWithPassword(
    String expectedUid,
    String password,
  ) async {
    final user = _user(expectedUid);
    final email = user.email;
    if (email == null ||
        !user.providerData.any(
          (provider) => provider.providerId == 'password',
        )) {
      throw const AccountAuthenticationGatewayException('unsupported-provider');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      _user(expectedUid);
    } on AccountAuthenticationGatewayException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AccountAuthenticationGatewayException(error.code);
    }
  }

  @override
  Future<bool> reauthenticateWithGoogle(String expectedUid) async {
    final user = _user(expectedUid);
    if (!user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    )) {
      throw const AccountAuthenticationGatewayException('unsupported-provider');
    }
    try {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(
          GoogleAuthProvider()
            ..setCustomParameters({'prompt': 'select_account'}),
        );
      } else {
        final idToken = await _googleIdentity.authenticate();
        if (idToken == null) return false;
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }
      _user(expectedUid);
      return true;
    } on AccountAuthenticationGatewayException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      if (isGoogleReauthenticationCancellationCode(error.code)) return false;
      throw AccountAuthenticationGatewayException(error.code);
    } catch (error) {
      throw AccountAuthenticationGatewayException(error.runtimeType.toString());
    }
  }

  @override
  Future<void> deleteCurrentUser(String expectedUid) async {
    try {
      await _user(expectedUid).delete();
    } on AccountAuthenticationGatewayException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AccountAuthenticationGatewayException(error.code);
    }
  }

  @override
  Future<void> waitUntilSignedOut() async {
    if (_auth.currentUser == null) return;
    try {
      await _auth
          .authStateChanges()
          .firstWhere((user) => user == null)
          .timeout(const Duration(seconds: 10));
    } on FirebaseAuthException catch (error) {
      throw AccountAuthenticationGatewayException(error.code);
    } catch (error) {
      throw AccountAuthenticationGatewayException(error.runtimeType.toString());
    }
  }
}
