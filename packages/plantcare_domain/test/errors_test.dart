import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_domain/care_history.dart';
import 'package:plantcare_domain/fertilizer_assessment.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';
import 'package:plantcare_domain/plant_diagnosis.dart';
import 'package:plantcare_domain/plant_observation.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_domain/soil_check.dart';
import 'package:plantcare_shared/errors.dart';
import 'package:test/test.dart';

void main() {
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
