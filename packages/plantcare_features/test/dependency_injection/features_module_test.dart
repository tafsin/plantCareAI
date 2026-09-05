import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart' show GetItHelper;
import 'package:plantcare_features/authentication.dart';
import 'package:plantcare_features/care_history.dart';
import 'package:plantcare_features/features_module.dart';
import 'package:plantcare_features/fertilizer_assessment.dart';
import 'package:plantcare_features/knowledge_retrieval.dart';
import 'package:plantcare_features/plant_diagnosis.dart';
import 'package:plantcare_features/plant_identification.dart';
import 'package:plantcare_features/plant_observation.dart';
import 'package:plantcare_features/plants.dart';
import 'package:plantcare_features/reminders.dart';
import 'package:plantcare_features/soil_check.dart';

void main() {
  test(
    'registers every presentation factory through the micro-package module',
    () {
      final container = GetIt.asNewInstance();

      PlantcareFeaturesPackageModule().init(GetItHelper(container));

      expect(container.isRegistered<AuthSessionBloc>(), isTrue);
      expect(container.isRegistered<AuthenticationBlocFactory>(), isTrue);
      expect(container.isRegistered<CareLogBlocFactory>(), isTrue);
      expect(container.isRegistered<FertilizerAssessmentBlocFactory>(), isTrue);
      expect(container.isRegistered<KnowledgeRetrievalBlocFactory>(), isTrue);
      expect(container.isRegistered<PlantDiagnosisBlocFactory>(), isTrue);
      expect(container.isRegistered<PlantObservationBlocFactory>(), isTrue);
      expect(container.isRegistered<PlantBlocFactory>(), isTrue);
      expect(container.isRegistered<PlantIdentificationBlocFactory>(), isTrue);
      expect(container.isRegistered<ReminderBlocFactory>(), isTrue);
      expect(container.isRegistered<SoilCheckBlocFactory>(), isTrue);
    },
  );
}
