import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/authentication/domain/errors/authentication_failure.dart';
import 'package:plantcare_ai/features/care_history/domain/errors/care_log_failure.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/errors/fertilizer_assessment_failure.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/errors/knowledge_retrieval_failure.dart';
import 'package:plantcare_ai/features/plant_diagnosis/domain/errors/plant_diagnosis_failure.dart';
import 'package:plantcare_ai/features/plant_observation/domain/errors/plant_observation_failure.dart';
import 'package:plantcare_ai/features/plants/domain/errors/plant_failure.dart';
import 'package:plantcare_ai/features/soil_check/domain/errors/soil_check_failure.dart';
import 'package:plantcare_shared/errors.dart';

void main() {
  test('generic application errors retain value equality', () {
    expect(const UnexpectedAppError(), const UnexpectedAppError());
    expect(
      const ValidationAppError('invalid'),
      const ValidationAppError('invalid'),
    );
    expect(
      const ValidationAppError('first'),
      isNot(const ValidationAppError('second')),
    );
  });

  test('every feature failure retains type-and-message equality', () {
    final pairs = <(AppError, AppError)>[
      (
        const AuthenticationFailure(AuthenticationFailureType.network, 'safe'),
        const AuthenticationFailure(AuthenticationFailureType.network, 'safe'),
      ),
      (
        const PlantFailure(PlantFailureType.notFound, 'safe'),
        const PlantFailure(PlantFailureType.notFound, 'safe'),
      ),
      (
        const PlantObservationFailure(
          PlantObservationFailureType.network,
          'safe',
        ),
        const PlantObservationFailure(
          PlantObservationFailureType.network,
          'safe',
        ),
      ),
      (
        const KnowledgeRetrievalFailure(
          KnowledgeRetrievalFailureType.network,
          'safe',
        ),
        const KnowledgeRetrievalFailure(
          KnowledgeRetrievalFailureType.network,
          'safe',
        ),
      ),
      (
        const PlantDiagnosisFailure(PlantDiagnosisFailureType.network, 'safe'),
        const PlantDiagnosisFailure(PlantDiagnosisFailureType.network, 'safe'),
      ),
      (
        const SoilCheckFailure(SoilCheckFailureType.network, 'safe'),
        const SoilCheckFailure(SoilCheckFailureType.network, 'safe'),
      ),
      (
        const CareLogFailure(CareLogFailureType.network, 'safe'),
        const CareLogFailure(CareLogFailureType.network, 'safe'),
      ),
      (
        const FertilizerAssessmentFailure(
          FertilizerAssessmentFailureType.network,
          'safe',
        ),
        const FertilizerAssessmentFailure(
          FertilizerAssessmentFailureType.network,
          'safe',
        ),
      ),
    ];

    for (final (first, second) in pairs) {
      expect(first, second);
    }
    expect(
      const PlantFailure(PlantFailureType.notFound, 'safe'),
      isNot(const PlantFailure(PlantFailureType.network, 'safe')),
    );
  });
}
