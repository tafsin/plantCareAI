import 'package:equatable/equatable.dart';

abstract class AppError extends Equatable implements Exception {
  const AppError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class UnexpectedAppError extends AppError {
  const UnexpectedAppError([
    super.message = 'Something went wrong. Please try again.',
  ]);
}

final class ValidationAppError extends AppError {
  const ValidationAppError(super.message);
}
