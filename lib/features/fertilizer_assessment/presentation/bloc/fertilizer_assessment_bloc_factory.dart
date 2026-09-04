import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/features/care_history/domain/repositories/care_log_repository.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/repositories/fertilizer_assessment_repository.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/services/fertilizer_evidence_validator.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/services/fertilizer_policy.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/bloc/fertilizer_assessment_bloc.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/bloc/fertilizer_assessment_details_bloc.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/bloc/fertilizer_assessment_history_bloc.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/repositories/knowledge_repository.dart';
import 'package:plantcare_ai/features/plants/domain/repositories/plant_repository.dart';

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
