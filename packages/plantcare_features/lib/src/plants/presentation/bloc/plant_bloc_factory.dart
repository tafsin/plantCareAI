import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_features/src/plants/presentation/bloc/plant_details_bloc.dart';
import 'package:plantcare_features/src/plants/presentation/bloc/plant_form_bloc.dart';
import 'package:plantcare_features/src/plants/presentation/bloc/plants_bloc.dart';

@lazySingleton
final class PlantBlocFactory {
  const PlantBlocFactory(this._repository);
  final PlantRepository _repository;

  PlantsBloc createPlantsBloc() => PlantsBloc(_repository);
  PlantDetailsBloc createPlantDetailsBloc() => PlantDetailsBloc(_repository);
  PlantFormBloc createPlantFormBloc() => PlantFormBloc(_repository);
}
