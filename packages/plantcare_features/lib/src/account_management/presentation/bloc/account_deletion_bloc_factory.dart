import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/account_management.dart';
import 'package:plantcare_domain/local_plant_images.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:plantcare_domain/reminders.dart';

import 'account_deletion_bloc.dart';

@lazySingleton
final class AccountDeletionBlocFactory {
  const AccountDeletionBlocFactory(
    this._repository,
    this._localImages,
    this._notifications,
    this._premium,
    this._launcher,
  );

  final AccountDeletionRepository _repository;
  final LocalPlantImageRepository _localImages;
  final NotificationScheduler _notifications;
  final PremiumSubscriptionRepository _premium;
  final AccountDestinationLauncher _launcher;

  AccountDeletionBloc create(ProviderCleanupRequestSource source) =>
      AccountDeletionBloc(
        _repository,
        _localImages,
        _notifications,
        _premium,
        _launcher,
        source,
      );
}
