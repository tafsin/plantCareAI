import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_features/src/authentication/presentation/validation/auth_input_validator.dart';
import 'package:plantcare_shared/errors.dart';

sealed class SignInEvent extends Equatable {
  const SignInEvent();

  @override
  List<Object?> get props => [];
}

final class SignInInputChanged extends SignInEvent {
  const SignInInputChanged();
}

final class SignInSubmitted extends SignInEvent {
  const SignInSubmitted({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class GoogleSignInRequested extends SignInEvent {
  const GoogleSignInRequested();
}

final class SignInCancelled extends SignInState {
  const SignInCancelled();
}

sealed class SignInState extends Equatable {
  const SignInState();

  @override
  List<Object?> get props => [];
}

final class SignInInitial extends SignInState {
  const SignInInitial();
}

final class SignInSubmitting extends SignInState {
  const SignInSubmitting({this.isGoogle = false});

  final bool isGoogle;

  @override
  List<Object?> get props => [isGoogle];
}

final class SignInSuccess extends SignInState {
  const SignInSuccess(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

final class SignInFailure extends SignInState {
  const SignInFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class SignInBloc extends Bloc<SignInEvent, SignInState> {
  SignInBloc(this._repository) : super(const SignInInitial()) {
    on<SignInInputChanged>(_onInputChanged);
    on<SignInSubmitted>(_onSubmitted);
    on<GoogleSignInRequested>(_onGoogleRequested);
  }

  final AuthenticationRepository _repository;
  var _submissionInProgress = false;

  void _onInputChanged(SignInInputChanged event, Emitter<SignInState> emit) {
    if (state is SignInFailure || state is SignInCancelled) {
      emit(const SignInInitial());
    }
  }

  Future<void> _onGoogleRequested(
    GoogleSignInRequested event,
    Emitter<SignInState> emit,
  ) async {
    if (_submissionInProgress) return;
    _submissionInProgress = true;
    emit(const SignInSubmitting(isGoogle: true));
    try {
      final user = await _repository.continueWithGoogle();
      emit(user == null ? const SignInCancelled() : SignInSuccess(user));
    } on AppError catch (error) {
      emit(SignInFailure(error.message));
    } catch (_) {
      emit(
        const SignInFailure('Couldn’t continue with Google. Please try again.'),
      );
    } finally {
      _submissionInProgress = false;
    }
  }

  Future<void> _onSubmitted(
    SignInSubmitted event,
    Emitter<SignInState> emit,
  ) async {
    if (_submissionInProgress) {
      return;
    }
    final emailError = AuthInputValidator.email(event.email);
    final passwordError = AuthInputValidator.signInPassword(event.password);
    if (emailError != null || passwordError != null) {
      emit(SignInFailure(emailError ?? passwordError!));
      return;
    }

    _submissionInProgress = true;
    emit(const SignInSubmitting());
    try {
      final user = await _repository.signIn(
        email: event.email.trim(),
        password: event.password,
      );
      emit(SignInSuccess(user));
    } on AppError catch (error) {
      emit(SignInFailure(error.message));
    } catch (_) {
      emit(const SignInFailure('Couldn\'t sign you in. Please try again.'));
    } finally {
      _submissionInProgress = false;
    }
  }
}
