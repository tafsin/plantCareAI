import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/account_management.dart';

import '../authentication/services/native_google_identity.dart';
import 'account_authentication_gateway.dart';
import 'account_firestore_gateway.dart';

typedef AccountDeletionSafeLog = void Function(
  String operation,
  String category,
);

@LazySingleton(as: AccountDeletionRepository)
final class FirebaseAccountDeletionRepository
    implements AccountDeletionRepository {
  FirebaseAccountDeletionRepository(
    FirebaseAuth auth,
    FirebaseFirestore firestore,
    NativeGoogleIdentity googleIdentity,
  ) : this.withGateway(
        FirebaseAccountAuthenticationGateway(auth, googleIdentity),
        FirebaseAccountFirestoreGateway(firestore),
      );

  @visibleForTesting
  FirebaseAccountDeletionRepository.withGateway(
    this._authentication,
    this._gateway, [
    AccountDeletionSafeLog? log,
  ]) : _log = log ?? _safeDeveloperLog;

  final AccountAuthenticationGateway _authentication;
  final AccountFirestoreGateway _gateway;
  final AccountDeletionSafeLog _log;
  String? _capturedUid;
  String? _recordedCleanupUid;

  AccountAuthenticationSnapshot get _session {
    final session = _authentication.currentSession;
    if (session == null) {
      throw const AccountDeletionFailure(
        AccountDeletionFailureType.unauthenticated,
        'Sign in again to continue deleting your account.',
      );
    }
    final captured = _capturedUid;
    if (captured != null && captured != session.uid) {
      throw const AccountDeletionFailure(
        AccountDeletionFailureType.identityChanged,
        'Your signed-in account changed. Restart account deletion.',
      );
    }
    _capturedUid ??= session.uid;
    return session;
  }

  @override
  String get currentUserId => _session.uid;

  @override
  Set<AccountReauthenticationMethod> get linkedReauthenticationMethods =>
      _session.providerIds
          .where((id) => id == 'password' || id == 'google.com')
          .map(
            (id) => id == 'password'
                ? AccountReauthenticationMethod.password
                : AccountReauthenticationMethod.google,
          )
          .toSet();

  @override
  Future<void> refreshSession() async {
    try {
      await _authentication.refreshSession(_session.uid);
      _session;
    } on AccountAuthenticationGatewayException catch (error) {
      _log('refresh_session', _safeCode(error));
      throw _failure(error, AccountDeletionFailureType.network);
    }
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final session = _session;
    if (session.email == null ||
        !linkedReauthenticationMethods.contains(
          AccountReauthenticationMethod.password,
        )) {
      throw const AccountDeletionFailure(
        AccountDeletionFailureType.unsupportedProvider,
        'Password reauthentication is not available for this account.',
      );
    }
    try {
      await _authentication.reauthenticateWithPassword(session.uid, password);
      _session;
    } on AccountAuthenticationGatewayException catch (error) {
      _log('password_reauthentication', _safeCode(error));
      throw _failure(error, AccountDeletionFailureType.invalidCredentials);
    }
  }

  @override
  Future<bool> reauthenticateWithGoogle() async {
    final session = _session;
    if (!linkedReauthenticationMethods.contains(
      AccountReauthenticationMethod.google,
    )) {
      throw const AccountDeletionFailure(
        AccountDeletionFailureType.unsupportedProvider,
        'Google reauthentication is not available for this account.',
      );
    }
    try {
      final result = await _authentication.reauthenticateWithGoogle(
        session.uid,
      );
      _session;
      return result;
    } on AccountAuthenticationGatewayException catch (error) {
      _log('google_reauthentication', _safeCode(error));
      throw _failure(error, AccountDeletionFailureType.invalidCredentials);
    }
  }

  @override
  Future<void> recordProviderCleanupRequest(
    ProviderCleanupRequestSource source,
  ) async {
    final uid = _session.uid;
    if (_recordedCleanupUid == uid) return;
    try {
      await _gateway.createProviderCleanupRequest(
        uid: uid,
        source: source.value,
      );
      _session;
      _recordedCleanupUid = uid;
    } on AccountDeletionFailure {
      rethrow;
    } catch (error) {
      _log('provider_cleanup_request', _safeCode(error));
      throw const AccountDeletionFailure(
        AccountDeletionFailureType.providerCleanupRequest,
        'The provider cleanup request could not be recorded. No account data was deleted.',
      );
    }
  }

  @override
  Future<void> deleteRemoteApplicationData() async {
    final uid = _session.uid;
    if (_recordedCleanupUid != uid) {
      throw const AccountDeletionFailure(
        AccountDeletionFailureType.providerCleanupRequest,
        'Record the provider cleanup request before deleting account data.',
      );
    }
    try {
      await _gateway.deleteAllApplicationData(uid);
      _session;
    } on AccountDeletionFailure {
      rethrow;
    } catch (error) {
      _log('remote_account_data_deletion', _safeCode(error));
      throw const AccountDeletionFailure(
        AccountDeletionFailureType.remoteDeletion,
        'Some account data could not be deleted. Sign in and retry to finish.',
      );
    }
  }

  @override
  Future<void> verifyRemoteApplicationDataDeleted() async {
    try {
      await _gateway.verifyApplicationDataDeleted(_session.uid);
      _session;
    } on AccountDeletionFailure {
      rethrow;
    } catch (error) {
      _log('remote_deletion_verification', _safeCode(error));
      throw const AccountDeletionFailure(
        AccountDeletionFailureType.remoteVerification,
        'Account data deletion could not be verified. Please retry.',
      );
    }
  }

  @override
  Future<void> deleteCurrentAuthenticationUser() async {
    try {
      await _authentication.deleteCurrentUser(_session.uid);
    } on AccountAuthenticationGatewayException catch (error) {
      _log('authentication_deletion', _safeCode(error));
      throw _failure(error, AccountDeletionFailureType.authenticationDeletion);
    }
  }

  @override
  Future<void> waitUntilSignedOut() async {
    try {
      await _authentication.waitUntilSignedOut();
    } catch (error) {
      _log('signed_out_confirmation', _safeCode(error));
      throw const AccountDeletionFailure(
        AccountDeletionFailureType.authenticationDeletion,
        'The account identity deletion could not be confirmed. Please retry.',
      );
    }
  }

  static AccountDeletionFailure _failure(
    AccountAuthenticationGatewayException error,
    AccountDeletionFailureType fallback,
  ) => switch (error.code) {
    'wrong-password' || 'invalid-credential' => const AccountDeletionFailure(
      AccountDeletionFailureType.invalidCredentials,
      'Those credentials could not verify this account.',
    ),
    'requires-recent-login' => const AccountDeletionFailure(
      AccountDeletionFailureType.recentLoginRequired,
      'Verify your sign-in again before deleting the account.',
    ),
    'network-request-failed' => const AccountDeletionFailure(
      AccountDeletionFailureType.network,
      'Check your connection and try again.',
    ),
    'identity-changed' => const AccountDeletionFailure(
      AccountDeletionFailureType.identityChanged,
      'Your signed-in account changed. Restart account deletion.',
    ),
    'unauthenticated' => const AccountDeletionFailure(
      AccountDeletionFailureType.unauthenticated,
      'Sign in again to continue deleting your account.',
    ),
    'unsupported-provider' => const AccountDeletionFailure(
      AccountDeletionFailureType.unsupportedProvider,
      'That sign-in method is not linked to this account.',
    ),
    _ => AccountDeletionFailure(
      fallback,
      fallback == AccountDeletionFailureType.authenticationDeletion
          ? 'The account identity could not be deleted. Sign in again and retry.'
          : 'Account verification could not be completed. Please try again.',
    ),
  };

  static const _safeCategories = <String>{
    'aborted',
    'already-exists',
    'cancelled-popup-request',
    'deadline-exceeded',
    'identity-changed',
    'invalid-credential',
    'network-request-failed',
    'permission-denied',
    'popup-blocked',
    'popup-closed-by-user',
    'requires-recent-login',
    'unauthenticated',
    'unavailable',
    'unsupported-provider',
    'user-cancelled',
    'web-context-cancelled',
    'wrong-password',
  };

  static String _safeCode(Object error) {
    final candidate = switch (error) {
      FirebaseException(:final code) => code,
      AccountAuthenticationGatewayException(:final code) => code,
      _ => null,
    };
    return candidate != null && _safeCategories.contains(candidate)
        ? candidate
        : error.runtimeType.toString();
  }

  static void _safeDeveloperLog(String operation, String category) {
    developer.log(
      'Account deletion failed during $operation: $category',
      name: 'plantcare_ai.account_deletion',
    );
  }
}
