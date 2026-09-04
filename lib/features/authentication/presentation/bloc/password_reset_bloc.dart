import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_ai/features/authentication/presentation/validation/auth_input_validator.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_shared/errors.dart';

const passwordResetSuccessMessage =
    'If an account exists for that email, a reset link has been sent.';

sealed class PasswordResetEvent extends Equatable {
  const PasswordResetEvent();

  @override
  List<Object?> get props => [];
}

final class PasswordResetInputChanged extends PasswordResetEvent {
  const PasswordResetInputChanged();
}

final class PasswordResetSubmitted extends PasswordResetEvent {
  const PasswordResetSubmitted(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

sealed class PasswordResetState extends Equatable {
  const PasswordResetState();

  @override
  List<Object?> get props => [];
}

final class PasswordResetInitial extends PasswordResetState {
  const PasswordResetInitial();
}

final class PasswordResetSubmitting extends PasswordResetState {
  const PasswordResetSubmitting();
}

final class PasswordResetSuccess extends PasswordResetState {
  const PasswordResetSuccess();
}

final class PasswordResetFailure extends PasswordResetState {
  const PasswordResetFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class PasswordResetBloc
    extends Bloc<PasswordResetEvent, PasswordResetState> {
  PasswordResetBloc(this._repository) : super(const PasswordResetInitial()) {
    on<PasswordResetInputChanged>(_onInputChanged);
    on<PasswordResetSubmitted>(_onSubmitted);
  }

  final AuthenticationRepository _repository;
  var _submissionInProgress = false;

  void _onInputChanged(
    PasswordResetInputChanged event,
    Emitter<PasswordResetState> emit,
  ) {
    if (state is PasswordResetFailure) {
      emit(const PasswordResetInitial());
    }
  }

  Future<void> _onSubmitted(
    PasswordResetSubmitted event,
    Emitter<PasswordResetState> emit,
  ) async {
    if (_submissionInProgress) {
      return;
    }
    final emailError = AuthInputValidator.email(event.email);
    if (emailError != null) {
      emit(PasswordResetFailure(emailError));
      return;
    }

    _submissionInProgress = true;
    emit(const PasswordResetSubmitting());
    try {
      await _repository.sendPasswordResetEmail(email: event.email.trim());
      emit(const PasswordResetSuccess());
    } on AppError catch (error) {
      emit(PasswordResetFailure(error.message));
    } catch (_) {
      emit(
        const PasswordResetFailure(
          'Couldn\'t send the reset email. Please try again.',
        ),
      );
    } finally {
      _submissionInProgress = false;
    }
  }
}
