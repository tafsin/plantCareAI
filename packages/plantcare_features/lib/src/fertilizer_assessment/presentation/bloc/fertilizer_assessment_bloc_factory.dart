import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/care_history.dart';
import 'package:plantcare_domain/fertilizer_assessment.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_features/src/fertilizer_assessment/presentation/bloc/fertilizer_assessment_bloc.dart';
import 'package:plantcare_features/src/fertilizer_assessment/presentation/bloc/fertilizer_assessment_details_bloc.dart';
import 'package:plantcare_features/src/fertilizer_assessment/presentation/bloc/fertilizer_assessment_history_bloc.dart';

@lazySingleton
final class FertilizerAssessmentBlocFactory {
  FertilizerAssessmentBlocFactory(
    this._plants,
    this._careLogs,
    this._assessments,
    this._knowledge,
  ) : _engine = DeterministicFertilizerEngine();

  final PlantRepository _plants;
  final CareLogRepository _careLogs;
  final FertilizerAssessmentRepository _assessments;
  final KnowledgeRepository _knowledge;
  final DeterministicFertilizerEngine _engine;

  FertilizerAssessmentBloc createAssessmentBloc() => FertilizerAssessmentBloc(
    _plants,
    _careLogs,
    _assessments,
    FertilizerEvidenceValidator(_knowledge),
    _engine,
  );

  FertilizerAssessmentHistoryBloc createHistoryBloc() =>
      FertilizerAssessmentHistoryBloc(_assessments);

  FertilizerAssessmentDetailsBloc createDetailsBloc() =>
      FertilizerAssessmentDetailsBloc(
        _assessments,
        FertilizerEvidenceValidator(_knowledge),
      );
}
