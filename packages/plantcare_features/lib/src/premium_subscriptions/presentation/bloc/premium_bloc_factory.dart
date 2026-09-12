import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';

import 'paywall_bloc.dart';
import 'premium_access_bloc.dart';

@lazySingleton
final class PremiumBlocFactory {
  const PremiumBlocFactory(this._repository, this._launcher);

  final PremiumSubscriptionRepository _repository;
  final PremiumDestinationLauncher _launcher;

  PremiumAccessBloc createAccessBloc() =>
      PremiumAccessBloc(_repository)..add(const PremiumAccessStarted());

  PaywallBloc createPaywallBloc() =>
      PaywallBloc(_repository, _launcher)..add(const PaywallLoadRequested());
}
