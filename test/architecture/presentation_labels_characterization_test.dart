import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/care_history/presentation/widgets/care_log_labels.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/presentation/widgets/fertilizer_assessment_labels.dart';
import 'package:plantcare_ai/features/reminders/presentation/widgets/reminder_labels.dart';
import 'package:plantcare_ai/features/soil_check/presentation/widgets/soil_check_labels.dart';
import 'package:plantcare_domain/care_history.dart';
import 'package:plantcare_domain/fertilizer_assessment.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:plantcare_domain/soil_check.dart';

void main() {
  test('care-log labels remain stable', () {
    expect(WateringMethod.values.map((value) => value.label), [
      'Top watering',
      'Bottom watering',
      'Soak',
      'Drip',
      'Other',
    ]);
    expect(FertilizerForm.values.map((value) => value.label), [
      'Liquid',
      'Granular',
      'Slow release',
      'Compost',
      'Other organic',
      'Other',
    ]);
  });

  test('fertilizer labels and descriptions remain stable', () {
    expect(GrowthActivity.values.map((value) => value.label), [
      'Active growth',
      'Slow or dormant',
      'Stressed or unhealthy',
      'Recently repotted',
      'I’m not sure',
    ]);
    expect(GrowthActivity.values.map((value) => value.description), [
      'The plant is producing new leaves, stems, flowers, or fruit.',
      'Growth has naturally slowed or paused, often with shorter days.',
      'The plant is wilted, damaged, diseased, pest-affected, or otherwise struggling.',
      'The plant was recently moved into fresh potting mix or a new container.',
      'Choose this when you cannot confidently describe current growth.',
    ]);
    expect(FertilizerCategory.values.map((value) => value.label), [
      'Balanced houseplant fertilizer',
      'Vegetable or tomato fertilizer',
      'Flowering or fruiting fertilizer',
      'General garden fertilizer',
      'Compost or organic amendment',
      'Insufficient evidence',
    ]);
  });

  test('reminder and soil-check wording remains stable', () {
    expect(ReminderType.values.map((value) => value.label), [
      'Check soil moisture',
      'Review fertilizer guidance',
    ]);
    expect(SoilMoistureLevel.values.map((value) => value.label), [
      'Very dry',
      'Dry',
      'Slightly moist',
      'Moist',
      'Wet',
    ]);
    expect(SoilMoistureLevel.values.map((value) => value.description), [
      'Dry and crumbly with no cool moisture felt.',
      'Mostly dry; little or no soil clings to a finger.',
      'A little cool or damp, but not wet.',
      'Clearly damp; soil may cling lightly.',
      'Saturated, muddy, or water readily coats a finger.',
    ]);
  });
}
