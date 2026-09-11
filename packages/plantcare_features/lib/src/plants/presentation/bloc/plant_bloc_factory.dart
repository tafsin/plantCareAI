import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/local_plant_images.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_features/src/plants/presentation/bloc/plant_details_bloc.dart';
import 'package:plantcare_features/src/plants/presentation/bloc/plant_form_bloc.dart';
import 'package:plantcare_features/src/plants/presentation/bloc/plants_bloc.dart';

@lazySingleton
final class PlantBlocFactory {
  const PlantBlocFactory(this._repository, this._localImageRepository);
  final PlantRepository _repository;
  final LocalPlantImageRepository _localImageRepository;

  PlantsBloc createPlantsBloc() =>
      PlantsBloc(_repository, _localImageRepository);
  PlantDetailsBloc createPlantDetailsBloc() => PlantDetailsBloc(_repository);
  PlantFormBloc createPlantFormBloc() => PlantFormBloc(_repository);
}
