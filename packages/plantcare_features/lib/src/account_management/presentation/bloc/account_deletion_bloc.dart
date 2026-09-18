import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/account_management.dart';
import 'package:plantcare_domain/local_plant_images.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:plantcare_shared/errors.dart';

sealed class AccountDeletionEvent extends Equatable {
  const AccountDeletionEvent();

  @override
  List<Object?> get props => [];
}

final class AccountDeletionPrepared extends AccountDeletionEvent {
  const AccountDeletionPrepared();
}

final class AccountDeletionSubmitted extends AccountDeletionEvent {
  const AccountDeletionSubmitted({
    required this.confirmation,
    required this.subscriptionAcknowledged,
    required this.method,
    this.password,
  });

  final String confirmation;
  final bool subscriptionAcknowledged;
  final AccountReauthenticationMethod method;
  final String? password;

  @override
  List<Object?> get props => [
    confirmation,
    subscriptionAcknowledged,
    method,
    password,
  ];
}

final class AccountDeletionRetried extends AccountDeletionEvent {
  const AccountDeletionRetried({required this.method, this.password});

  final AccountReauthenticationMethod method;
  final String? password;

  @override
  List<Object?> get props => [method, password];
}

enum AccountDeletionDestination { privacy, terms, subscriptions, support }

final class AccountDeletionDestinationRequested extends AccountDeletionEvent {
  const AccountDeletionDestinationRequested(this.destination);

  final AccountDeletionDestination destination;

  @override
  List<Object?> get props => [destination];
}

final class AccountDeletionState extends Equatable {
  const AccountDeletionState({
    this.stage = AccountDeletionStage.idle,
    this.methods = const {},
    this.premiumIsActive = false,
    this.premiumStatusKnown = false,
    this.message,
    this.failureType,
    this.hasSupportEmail = false,
    this.supportEmail,
    this.hasPrivacyPolicy = false,
    this.hasTermsOfService = false,
  });

  final AccountDeletionStage stage;
  final Set<AccountReauthenticationMethod> methods;
  final bool premiumIsActive;
  final bool premiumStatusKnown;
  final String? message;
  final AccountDeletionFailureType? failureType;
  final bool hasSupportEmail;
  final String? supportEmail;
  final bool hasPrivacyPolicy;
  final bool hasTermsOfService;

  bool get isBusy => const {
    AccountDeletionStage.reauthenticating,
    AccountDeletionStage.recordingProviderCleanup,
    AccountDeletionStage.deletingRemoteData,
    AccountDeletionStage.clearingLocalData,
    AccountDeletionStage.deletingAuthentication,
  }.contains(stage);

  AccountDeletionState copyWith({
    AccountDeletionStage? stage,
    Set<AccountReauthenticationMethod>? methods,
    bool? premiumIsActive,
    bool? premiumStatusKnown,
    String? message,
    bool clearMessage = false,
    AccountDeletionFailureType? failureType,
    bool clearFailure = false,
    bool? hasSupportEmail,
    String? supportEmail,
    bool? hasPrivacyPolicy,
    bool? hasTermsOfService,
  }) => AccountDeletionState(
    stage: stage ?? this.stage,
    methods: methods ?? this.methods,
    premiumIsActive: premiumIsActive ?? this.premiumIsActive,
    premiumStatusKnown: premiumStatusKnown ?? this.premiumStatusKnown,
    message: clearMessage ? null : message ?? this.message,
    failureType: clearFailure ? null : failureType ?? this.failureType,
    hasSupportEmail: hasSupportEmail ?? this.hasSupportEmail,
    supportEmail: supportEmail ?? this.supportEmail,
    hasPrivacyPolicy: hasPrivacyPolicy ?? this.hasPrivacyPolicy,
    hasTermsOfService: hasTermsOfService ?? this.hasTermsOfService,
  );

  @override
  List<Object?> get props => [
    stage,
    methods,
    premiumIsActive,
    premiumStatusKnown,
    message,
    failureType,
    hasSupportEmail,
    supportEmail,
    hasPrivacyPolicy,
    hasTermsOfService,
  ];
}

final class AccountDeletionBloc
    extends Bloc<AccountDeletionEvent, AccountDeletionState> {
  AccountDeletionBloc(
    this._repository,
    this._localImages,
    this._notifications,
    this._premium,
    AccountDestinationLauncher launcher,
    this._source,
  ) : _launcher = launcher,
      super(
        AccountDeletionState(
          hasSupportEmail: launcher.hasSupportEmail,
          supportEmail: launcher.supportEmail,
          hasPrivacyPolicy: launcher.hasPrivacyPolicy,
          hasTermsOfService: launcher.hasTermsOfService,
        ),
      ) {
    on<AccountDeletionPrepared>(_onPrepared);
    on<AccountDeletionSubmitted>(_onSubmitted);
    on<AccountDeletionRetried>(_onRetried);
    on<AccountDeletionDestinationRequested>(_onDestinationRequested);
  }

  final AccountDeletionRepository _repository;
  final LocalPlantImageRepository _localImages;
  final NotificationScheduler _notifications;
  final PremiumSubscriptionRepository _premium;
  final AccountDestinationLauncher _launcher;
  final ProviderCleanupRequestSource _source;
  bool _running = false;
  var _remoteVerified = false;
  var _localCleared = false;

  Future<void> _onPrepared(
    AccountDeletionPrepared event,
    Emitter<AccountDeletionState> emit,
  ) async {
    try {
      final methods = _repository.linkedReauthenticationMethods;
      emit(
        state.copyWith(
          stage: AccountDeletionStage.awaitingConfirmation,
          methods: methods,
          clearMessage: true,
          clearFailure: true,
        ),
      );
      if (_premium.platform == PurchasePlatform.android) {
        try {
          await _premium.refreshProfile().timeout(const Duration(seconds: 4));
          emit(
            state.copyWith(
              premiumStatusKnown: true,
              premiumIsActive: _premium.currentAccess.isActive,
            ),
          );
        } catch (_) {
          emit(
            state.copyWith(premiumStatusKnown: false, premiumIsActive: false),
          );
        }
      }
    } on AppError catch (error) {
      emit(
        state.copyWith(
          stage: AccountDeletionStage.incomplete,
          message: error.message,
        ),
      );
    }
  }

  Future<void> _onSubmitted(
    AccountDeletionSubmitted event,
    Emitter<AccountDeletionState> emit,
  ) async {
    if (_running) return;
    if (event.confirmation != 'DELETE' || !event.subscriptionAcknowledged) {
      emit(
        state.copyWith(
          stage: AccountDeletionStage.awaitingConfirmation,
          message:
              'Acknowledge the subscription warning and type exactly DELETE.',
        ),
      );
      return;
    }
    await _run(
      emit,
      method: event.method,
      password: event.password,
      reauthenticate: true,
    );
  }

  Future<void> _onRetried(
    AccountDeletionRetried event,
    Emitter<AccountDeletionState> emit,
  ) => _run(
    emit,
    method: event.method,
    password: event.password,
    reauthenticate:
        state.failureType == AccountDeletionFailureType.recentLoginRequired ||
        !_remoteVerified,
  );

  Future<void> _run(
    Emitter<AccountDeletionState> emit, {
    required AccountReauthenticationMethod method,
    required String? password,
    required bool reauthenticate,
  }) async {
    if (_running) return;
    _running = true;
    try {
      if (reauthenticate) {
        emit(
          state.copyWith(
            stage: AccountDeletionStage.reauthenticating,
            clearMessage: true,
            clearFailure: true,
          ),
        );
        await _repository.refreshSession();
        if (method == AccountReauthenticationMethod.password) {
          if (password == null || password.isEmpty) {
            throw const AccountDeletionFailure(
              AccountDeletionFailureType.invalidCredentials,
              'Enter your current password to continue.',
            );
          }
          await _repository.reauthenticateWithPassword(password);
        } else if (!await _repository.reauthenticateWithGoogle()) {
          throw const AccountDeletionFailure(
            AccountDeletionFailureType.cancelled,
            'Google verification was cancelled. No data was deleted.',
          );
        }
      }

      if (!_remoteVerified) {
        emit(
          state.copyWith(stage: AccountDeletionStage.recordingProviderCleanup),
        );
        await _repository.recordProviderCleanupRequest(_source);
        emit(state.copyWith(stage: AccountDeletionStage.deletingRemoteData));
        await _repository.deleteRemoteApplicationData();
        await _repository.verifyRemoteApplicationDataDeleted();
        _remoteVerified = true;
      }

      if (!_localCleared) {
        emit(state.copyWith(stage: AccountDeletionStage.clearingLocalData));
        try {
          final uid = _repository.currentUserId;
          await _localImages.deleteAllForUser(uid);
          await _notifications.clearUser(uid);
        } on AccountDeletionFailure {
          rethrow;
        } catch (_) {
          throw const AccountDeletionFailure(
            AccountDeletionFailureType.localCleanup,
            'Account data on this device could not be cleared. Please retry.',
          );
        }
        _localCleared = true;
      }

      emit(state.copyWith(stage: AccountDeletionStage.deletingAuthentication));
      await _repository.deleteCurrentAuthenticationUser();
      await _repository.waitUntilSignedOut();
      emit(
        state.copyWith(
          stage: AccountDeletionStage.complete,
          message:
              'Your PlantCare AI account and application data were deleted.',
          clearFailure: true,
        ),
      );
    } on AccountDeletionFailure catch (error) {
      emit(
        state.copyWith(
          stage: AccountDeletionStage.incomplete,
          message: error.message,
          failureType: error.type,
        ),
      );
    } on AppError catch (error) {
      emit(
        state.copyWith(
          stage: AccountDeletionStage.incomplete,
          message: error.message,
          failureType: AccountDeletionFailureType.unknown,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          stage: AccountDeletionStage.incomplete,
          message: 'Account deletion could not finish. Please retry.',
          failureType: AccountDeletionFailureType.unknown,
        ),
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _onDestinationRequested(
    AccountDeletionDestinationRequested event,
    Emitter<AccountDeletionState> emit,
  ) async {
    try {
      await switch (event.destination) {
        AccountDeletionDestination.privacy => _launcher.openPrivacyPolicy(),
        AccountDeletionDestination.terms => _launcher.openTermsOfService(),
        AccountDeletionDestination.subscriptions =>
          _launcher.openGooglePlaySubscriptions(),
        AccountDeletionDestination.support => _launcher.openSupportRequest(),
      };
    } on AppError catch (error) {
      emit(
        state.copyWith(
          message: error.message,
          failureType: AccountDeletionFailureType.launch,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          message: 'That link could not be opened. Please try again.',
          failureType: AccountDeletionFailureType.launch,
        ),
      );
    }
  }
}
