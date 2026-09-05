import 'package:plantcare_shared/errors.dart';

enum AuthenticationFailureType {
  invalidEmail,
  weakPassword,
  emailAlreadyInUse,
  invalidCredentials,
  userDisabled,
  tooManyRequests,
  network,
  unknown,
}

final class AuthenticationFailure extends AppError {
  const AuthenticationFailure(this.type, super.message);

  final AuthenticationFailureType type;

  @override
  List<Object?> get props => [type, message];
}
