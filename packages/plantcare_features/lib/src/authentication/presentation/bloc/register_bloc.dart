import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_features/src/authentication/presentation/validation/auth_input_validator.dart';
import 'package:plantcare_shared/errors.dart';

sealed class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => [];
}

final class RegisterInputChanged extends RegisterEvent {
  const RegisterInputChanged();
}

final class RegisterSubmitted extends RegisterEvent {
  const RegisterSubmitted({
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  final String email;
  final String password;
  final String confirmPassword;

  @override
  List<Object?> get props => [email, password, confirmPassword];
}

sealed class RegisterState extends Equatable {
  const RegisterState();

  @override
  List<Object?> get props => [];
}

final class RegisterInitial extends RegisterState {
  const RegisterInitial();
}

final class RegisterSubmitting extends RegisterState {
  const RegisterSubmitting();
}

final class RegisterSuccess extends RegisterState {
  const RegisterSuccess(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

final class RegisterFailure extends RegisterState {
  const RegisterFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc(this._repository) : super(const RegisterInitial()) {
    on<RegisterInputChanged>(_onInputChanged);
    on<RegisterSubmitted>(_onSubmitted);
  }

  final AuthenticationRepository _repository;
  var _submissionInProgress = false;

  void _onInputChanged(
    RegisterInputChanged event,
    Emitter<RegisterState> emit,
  ) {
    if (state is RegisterFailure) {
      emit(const RegisterInitial());
    }
  }

  Future<void> _onSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    if (_submissionInProgress) {
      return;
    }
    final validationError =
        AuthInputValidator.email(event.email) ??
        AuthInputValidator.registrationPassword(event.password) ??
        AuthInputValidator.confirmation(event.confirmPassword, event.password);
    if (validationError != null) {
      emit(RegisterFailure(validationError));
      return;
    }

    _submissionInProgress = true;
    emit(const RegisterSubmitting());
    try {
      final user = await _repository.register(
        email: event.email.trim(),
        password: event.password,
      );
      emit(RegisterSuccess(user));
    } on AppError catch (error) {
      emit(RegisterFailure(error.message));
    } catch (_) {
      emit(
        const RegisterFailure(
          'Couldn\'t create your account. Please try again.',
        ),
      );
    } finally {
      _submissionInProgress = false;
    }
  }
}
