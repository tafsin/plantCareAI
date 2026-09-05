import 'package:plantcare_domain/soil_check.dart';

extension SoilMoistureLevelLabel on SoilMoistureLevel {
  String get label => switch (this) {
    SoilMoistureLevel.veryDry => 'Very dry',
    SoilMoistureLevel.dry => 'Dry',
    SoilMoistureLevel.slightlyMoist => 'Slightly moist',
    SoilMoistureLevel.moist => 'Moist',
    SoilMoistureLevel.wet => 'Wet',
  };

  String get description => switch (this) {
    SoilMoistureLevel.veryDry => 'Dry and crumbly with no cool moisture felt.',
    SoilMoistureLevel.dry =>
      'Mostly dry; little or no soil clings to a finger.',
    SoilMoistureLevel.slightlyMoist => 'A little cool or damp, but not wet.',
    SoilMoistureLevel.moist => 'Clearly damp; soil may cling lightly.',
    SoilMoistureLevel.wet =>
      'Saturated, muddy, or water readily coats a finger.',
  };
}
