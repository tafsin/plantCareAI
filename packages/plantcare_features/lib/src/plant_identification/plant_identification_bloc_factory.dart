import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/local_plant_images.dart';
import 'package:plantcare_domain/plant_identification.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';
import 'package:plantcare_features/src/plant_identification/plant_identification_bloc.dart';

@lazySingleton
final class PlantIdentificationBlocFactory {
  const PlantIdentificationBlocFactory(
    this._picker,
    this._processor,
    this._service,
    this._repository,
    this._localImageRepository, [
    this._premiumRepository,
  ]);
  final PlantImagePicker _picker;
  final PlantImageProcessor _processor;
  final PlantIdentificationService _service;
  final PlantRepository _repository;
  final LocalPlantImageRepository _localImageRepository;
  final PremiumSubscriptionRepository? _premiumRepository;
  PlantIdentificationBloc create() => PlantIdentificationBloc(
    _picker,
    _processor,
    _service,
    _repository,
    _localImageRepository,
    premiumAccess: () =>
        _premiumRepository?.currentAccess ??
        const PremiumAccessSnapshot.signedOut(),
  );
}
