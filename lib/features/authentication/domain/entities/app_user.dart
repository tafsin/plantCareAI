import 'package:equatable/equatable.dart';

final class AppUser extends Equatable {
  const AppUser({required this.uid, required this.email});

  final String uid;
  final String? email;

  @override
  List<Object?> get props => [uid, email];
}
