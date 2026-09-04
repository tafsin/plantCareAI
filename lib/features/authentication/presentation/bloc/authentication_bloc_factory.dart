import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/password_reset_bloc.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/register_bloc.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/sign_in_bloc.dart';

@lazySingleton
final class AuthenticationBlocFactory {
  const AuthenticationBlocFactory(this._repository);

  final AuthenticationRepository _repository;

  SignInBloc createSignInBloc() => SignInBloc(_repository);

  RegisterBloc createRegisterBloc() => RegisterBloc(_repository);

  PasswordResetBloc createPasswordResetBloc() => PasswordResetBloc(_repository);
}
