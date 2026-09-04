import 'dart:async';
import 'dart:developer' as developer;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/features/authentication/domain/entities/app_user.dart';
import 'package:plantcare_ai/features/authentication/domain/repositories/authentication_repository.dart';

sealed class AuthSessionEvent extends Equatable {
  const AuthSessionEvent();

  @override
  List<Object?> get props => [];
}

final class AuthSessionStarted extends AuthSessionEvent {
  const AuthSessionStarted();
}

final class AuthSessionUserChanged extends AuthSessionEvent {
  const AuthSessionUserChanged(this.user);

  final AppUser? user;

  @override
  List<Object?> get props => [user];
}

final class AuthSessionLogoutRequested extends AuthSessionEvent {
  const AuthSessionLogoutRequested();
}

sealed class AuthSessionState extends Equatable {
  const AuthSessionState();

  @override
  List<Object?> get props => [];
}

final class AuthSessionChecking extends AuthSessionState {
  const AuthSessionChecking();
}

final class AuthSessionUnauthenticated extends AuthSessionState {
  const AuthSessionUnauthenticated();
}

final class AuthSessionAuthenticated extends AuthSessionState {
  const AuthSessionAuthenticated({
    required this.user,
    this.isLoggingOut = false,
    this.logoutFailureCount = 0,
  });

  final AppUser user;
  final bool isLoggingOut;
  final int logoutFailureCount;

  AuthSessionAuthenticated copyWith({
    bool? isLoggingOut,
    int? logoutFailureCount,
  }) {
    return AuthSessionAuthenticated(
      user: user,
      isLoggingOut: isLoggingOut ?? this.isLoggingOut,
      logoutFailureCount: logoutFailureCount ?? this.logoutFailureCount,
    );
  }

  @override
  List<Object?> get props => [user, isLoggingOut, logoutFailureCount];
}

@lazySingleton
final class AuthSessionBloc extends Bloc<AuthSessionEvent, AuthSessionState>
    implements Listenable {
  AuthSessionBloc(this._repository) : super(const AuthSessionChecking()) {
    on<AuthSessionStarted>(_onStarted);
    on<AuthSessionUserChanged>(_onUserChanged);
    on<AuthSessionLogoutRequested>(_onLogoutRequested);
    add(const AuthSessionStarted());
  }

  final AuthenticationRepository _repository;
  StreamSubscription<AppUser?>? _authStateSubscription;
  var _logoutInProgress = false;
  final ObserverList<VoidCallback> _listeners = ObserverList<VoidCallback>();

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notifyRoutingListeners() {
    for (final listener in _listeners.toList(growable: false)) {
      listener();
    }
  }

  Future<void> _onStarted(
    AuthSessionStarted event,
    Emitter<AuthSessionState> emit,
  ) async {
    if (_authStateSubscription != null) {
      return;
    }
    _authStateSubscription = _repository.authStateChanges.listen(
      (user) => add(AuthSessionUserChanged(user)),
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Authentication state stream failed',
          name: 'plantcare_ai.authentication',
          error: error.runtimeType,
          stackTrace: stackTrace,
        );
        add(const AuthSessionUserChanged(null));
      },
    );
  }

  void _onUserChanged(
    AuthSessionUserChanged event,
    Emitter<AuthSessionState> emit,
  ) {
    _logoutInProgress = false;
    final user = event.user;
    emit(
      user == null
          ? const AuthSessionUnauthenticated()
          : AuthSessionAuthenticated(user: user),
    );
    _notifyRoutingListeners();
  }

  Future<void> _onLogoutRequested(
    AuthSessionLogoutRequested event,
    Emitter<AuthSessionState> emit,
  ) async {
    final currentState = state;
    if (_logoutInProgress || currentState is! AuthSessionAuthenticated) {
      return;
    }

    _logoutInProgress = true;
    emit(currentState.copyWith(isLoggingOut: true));
    _notifyRoutingListeners();
    try {
      await _repository.signOut();
    } catch (error, stackTrace) {
      developer.log(
        'Logout failed',
        name: 'plantcare_ai.authentication',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
      _logoutInProgress = false;
      emit(
        currentState.copyWith(
          isLoggingOut: false,
          logoutFailureCount: currentState.logoutFailureCount + 1,
        ),
      );
      _notifyRoutingListeners();
    }
  }

  @override
  Future<void> close() async {
    _listeners.clear();
    await _authStateSubscription?.cancel();
    return super.close();
  }
}
