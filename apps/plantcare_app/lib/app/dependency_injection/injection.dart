import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_app/app/dependency_injection/injection.config.dart';
import 'package:plantcare_data/data_module.dart';
import 'package:plantcare_features/features_module.dart';

final getIt = GetIt.instance;

@InjectableInit(
  externalPackageModulesBefore: [
    ExternalModule(PlantcareDataPackageModule),
    ExternalModule(PlantcareFeaturesPackageModule),
  ],
  // Injectable 3 validates root dependencies without expanding the contracts
  // registered inside an external micro-package module.
  ignoreUnregisteredTypesInPackages: ['plantcare_domain'],
)
Future<void> configureDependencies() async {
  await getIt.init();
}
