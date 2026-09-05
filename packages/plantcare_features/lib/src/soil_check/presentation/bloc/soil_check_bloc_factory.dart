import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_domain/soil_check.dart';
import 'package:plantcare_features/src/soil_check/presentation/bloc/soil_check_bloc.dart';
import 'package:plantcare_features/src/soil_check/presentation/bloc/soil_check_details_bloc.dart';
import 'package:plantcare_features/src/soil_check/presentation/bloc/soil_check_history_bloc.dart';

@lazySingleton
final class SoilCheckBlocFactory {
  SoilCheckBlocFactory(this._plants, this._checks, this._knowledge)
    : _engine = DeterministicWateringEngine();
  final PlantRepository _plants;
  final SoilCheckRepository _checks;
  final KnowledgeRepository _knowledge;
  final DeterministicWateringEngine _engine;
  SoilCheckBloc createCheckBloc() => SoilCheckBloc(
    _plants,
    _checks,
    SoilEvidenceValidator(_knowledge),
    _engine,
  );
  SoilCheckHistoryBloc createHistoryBloc() => SoilCheckHistoryBloc(_checks);
  SoilCheckDetailsBloc createDetailsBloc() =>
      SoilCheckDetailsBloc(_checks, SoilEvidenceValidator(_knowledge));
}
