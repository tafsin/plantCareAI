import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';

sealed class PremiumAccessEvent extends Equatable {
  const PremiumAccessEvent();

  @override
  List<Object?> get props => [];
}

final class PremiumAccessStarted extends PremiumAccessEvent {
  const PremiumAccessStarted();
}

final class PremiumAccessChanged extends PremiumAccessEvent {
  const PremiumAccessChanged(this.snapshot);

  final PremiumAccessSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot];
}

final class PremiumAccessState extends Equatable {
  const PremiumAccessState(this.snapshot);

  const PremiumAccessState.initial()
    : snapshot = const PremiumAccessSnapshot.signedOut();

  final PremiumAccessSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot];
}

final class PremiumAccessBloc
    extends Bloc<PremiumAccessEvent, PremiumAccessState> {
  PremiumAccessBloc(this._repository)
    : super(PremiumAccessState(_repository.currentAccess)) {
    on<PremiumAccessStarted>(_onStarted);
    on<PremiumAccessChanged>(
      (event, emit) => emit(PremiumAccessState(event.snapshot)),
    );
  }

  final PremiumSubscriptionRepository _repository;
  StreamSubscription<PremiumAccessSnapshot>? _subscription;

  Future<void> _onStarted(
    PremiumAccessStarted event,
    Emitter<PremiumAccessState> emit,
  ) async {
    if (_subscription != null) return;
    _subscription = _repository.accessChanges.listen(
      (snapshot) => add(PremiumAccessChanged(snapshot)),
    );
    add(PremiumAccessChanged(_repository.currentAccess));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
