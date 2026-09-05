import 'package:injectable/injectable.dart';

@InjectableInit.microPackage(
  ignoreUnregisteredTypesInPackages: ['plantcare_domain'],
)
void initMicroPackage() {}
