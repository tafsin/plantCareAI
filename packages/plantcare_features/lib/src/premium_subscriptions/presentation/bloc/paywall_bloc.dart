import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';

sealed class PaywallBlocEvent extends Equatable {
  const PaywallBlocEvent();

  @override
  List<Object?> get props => [];
}

final class PaywallLoadRequested extends PaywallBlocEvent {
  const PaywallLoadRequested();
}

final class PaywallPresentRequested extends PaywallBlocEvent {
  const PaywallPresentRequested();
}

final class PaywallRestoreRequested extends PaywallBlocEvent {
  const PaywallRestoreRequested();
}

final class PaywallManageRequested extends PaywallBlocEvent {
  const PaywallManageRequested();
}

final class PaywallPrivacyRequested extends PaywallBlocEvent {
  const PaywallPrivacyRequested();
}

final class PaywallTermsRequested extends PaywallBlocEvent {
  const PaywallTermsRequested();
}

final class PaywallSdkEventReceived extends PaywallBlocEvent {
  const PaywallSdkEventReceived(this.event);

  final PaywallEvent event;

  @override
  List<Object?> get props => [event];
}

enum PaywallStatus {
  initial,
  loading,
  ready,
  paywallUnavailable,
  productUnavailable,
  presenting,
  purchasing,
  restoring,
  pending,
  premiumActive,
  failure,
  unsupported,
}

final class PaywallState extends Equatable {
  const PaywallState({
    required this.platform,
    required this.hasPrivacyPolicy,
    required this.hasTermsOfService,
    this.status = PaywallStatus.initial,
    this.offer,
    this.message,
    this.actionRevision = 0,
  });

  final PurchasePlatform platform;
  final bool hasPrivacyPolicy;
  final bool hasTermsOfService;
  final PaywallStatus status;
  final PremiumOffer? offer;
  final String? message;
  final int actionRevision;

  bool get isBusy => const {
    PaywallStatus.loading,
    PaywallStatus.presenting,
    PaywallStatus.purchasing,
    PaywallStatus.restoring,
  }.contains(status);

  bool get canPurchase =>
      platform == PurchasePlatform.android &&
      status == PaywallStatus.ready &&
      offer != null;

  PaywallState copyWith({
    PaywallStatus? status,
    PremiumOffer? offer,
    bool clearOffer = false,
    String? message,
    bool clearMessage = false,
    int? actionRevision,
  }) => PaywallState(
    platform: platform,
    hasPrivacyPolicy: hasPrivacyPolicy,
    hasTermsOfService: hasTermsOfService,
    status: status ?? this.status,
    offer: clearOffer ? null : offer ?? this.offer,
    message: clearMessage ? null : message ?? this.message,
    actionRevision: actionRevision ?? this.actionRevision,
  );

  @override
  List<Object?> get props => [
    platform,
    hasPrivacyPolicy,
    hasTermsOfService,
    status,
    offer,
    message,
    actionRevision,
  ];
}

final class PaywallBloc extends Bloc<PaywallBlocEvent, PaywallState> {
  PaywallBloc(this._repository, this._launcher)
    : super(
        PaywallState(
          platform: _repository.platform,
          hasPrivacyPolicy: _launcher.hasPrivacyPolicy,
          hasTermsOfService: _launcher.hasTermsOfService,
        ),
      ) {
    on<PaywallLoadRequested>(_load);
    on<PaywallPresentRequested>(_present);
    on<PaywallRestoreRequested>(_restore);
    on<PaywallManageRequested>(_manage);
    on<PaywallPrivacyRequested>(_privacy);
    on<PaywallTermsRequested>(_terms);
    on<PaywallSdkEventReceived>(_sdkEvent);
    _eventSubscription = _repository.paywallEvents.listen(
      (event) => add(PaywallSdkEventReceived(event)),
    );
  }

  final PremiumSubscriptionRepository _repository;
  final PremiumDestinationLauncher _launcher;
  late final StreamSubscription<PaywallEvent> _eventSubscription;

  Future<void> _load(
    PaywallLoadRequested event,
    Emitter<PaywallState> emit,
  ) async {
    if (state.isBusy) return;
    if (state.platform != PurchasePlatform.android) {
      emit(
        state.copyWith(status: PaywallStatus.unsupported, clearMessage: true),
      );
      return;
    }
    emit(state.copyWith(status: PaywallStatus.loading, clearMessage: true));
    final preparation = await _repository.preparePaywall();
    emit(switch (preparation.availability) {
      PaywallAvailability.ready => state.copyWith(
        status: PaywallStatus.ready,
        offer: preparation.offer,
        clearMessage: true,
      ),
      PaywallAvailability.productUnavailable => state.copyWith(
        status: PaywallStatus.productUnavailable,
        clearOffer: true,
        message: preparation.message,
      ),
      PaywallAvailability.unsupported => state.copyWith(
        status: PaywallStatus.unsupported,
        clearOffer: true,
      ),
      _ => state.copyWith(
        status: PaywallStatus.paywallUnavailable,
        clearOffer: true,
        message: preparation.message,
      ),
    });
  }

  Future<void> _present(
    PaywallPresentRequested event,
    Emitter<PaywallState> emit,
  ) async {
    if (!state.canPurchase || state.isBusy) return;
    emit(state.copyWith(status: PaywallStatus.presenting, clearMessage: true));
    try {
      await _repository.presentPaywall();
    } on PremiumSubscriptionFailure catch (error) {
      emit(_failure(error.message));
    } catch (_) {
      emit(_failure('The premium offer could not be displayed. Try again.'));
    }
  }

  Future<void> _restore(
    PaywallRestoreRequested event,
    Emitter<PaywallState> emit,
  ) async {
    if (state.platform != PurchasePlatform.android || state.isBusy) return;
    emit(state.copyWith(status: PaywallStatus.restoring, clearMessage: true));
    try {
      await _repository.restorePurchases();
    } on PremiumSubscriptionFailure catch (error) {
      emit(_failure(error.message));
    } catch (_) {
      emit(_failure('Purchases could not be restored. Try again.'));
    }
  }

  Future<void> _manage(
    PaywallManageRequested event,
    Emitter<PaywallState> emit,
  ) => _launch(
    emit,
    () => _launcher.openManageSubscription(productId: state.offer?.productId),
  );

  Future<void> _privacy(
    PaywallPrivacyRequested event,
    Emitter<PaywallState> emit,
  ) => _launch(emit, _launcher.openPrivacyPolicy);

  Future<void> _terms(
    PaywallTermsRequested event,
    Emitter<PaywallState> emit,
  ) => _launch(emit, _launcher.openTermsOfService);

  Future<void> _launch(
    Emitter<PaywallState> emit,
    Future<void> Function() action,
  ) async {
    if (state.isBusy) return;
    try {
      await action();
    } on PremiumSubscriptionFailure catch (error) {
      emit(_failure(error.message));
    } catch (_) {
      emit(_failure('The link could not be opened. Please try again.'));
    }
  }

  void _sdkEvent(PaywallSdkEventReceived wrapper, Emitter<PaywallState> emit) {
    switch (wrapper.event) {
      case PaywallPurchaseStarted():
        emit(state.copyWith(status: PaywallStatus.purchasing));
      case PaywallPurchasePending():
        emit(
          state.copyWith(
            status: PaywallStatus.pending,
            message: 'Your purchase is pending in Google Play.',
          ),
        );
      case PaywallPurchaseCancelled() || PaywallDismissed():
        if (state.status != PaywallStatus.premiumActive) {
          emit(state.copyWith(status: PaywallStatus.ready, clearMessage: true));
        }
      case PaywallPurchaseVerified():
        emit(
          state.copyWith(
            status: PaywallStatus.premiumActive,
            message: 'Premium is active.',
          ),
        );
      case PaywallRestoreStarted():
        emit(state.copyWith(status: PaywallStatus.restoring));
      case PaywallRestoreCompleted(:final hasPremium):
        emit(
          state.copyWith(
            status: hasPremium
                ? PaywallStatus.premiumActive
                : PaywallStatus.ready,
            message: hasPremium
                ? 'Premium access was restored.'
                : 'No active premium purchase was found.',
          ),
        );
      case PaywallOperationFailed(:final message):
        emit(_failure(message));
    }
  }

  PaywallState _failure(String message) => state.copyWith(
    status: state.status == PaywallStatus.premiumActive
        ? PaywallStatus.premiumActive
        : PaywallStatus.failure,
    message: message,
    actionRevision: state.actionRevision + 1,
  );

  @override
  Future<void> close() async {
    await _eventSubscription.cancel();
    return super.close();
  }
}
