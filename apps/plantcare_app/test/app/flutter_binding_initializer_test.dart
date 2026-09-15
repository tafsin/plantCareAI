import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_app/app/bootstrap/flutter_binding_initializer.dart';

void main() {
  test('initializes Marionette in debug mode', () {
    final initializedBindings = <String>[];

    initializePlantCareFlutterBinding(
      isDebugMode: true,
      marionette: () => initializedBindings.add('marionette'),
      standard: () => initializedBindings.add('standard'),
    );

    expect(initializedBindings, ['marionette']);
  });

  test('initializes the standard binding outside debug mode', () {
    final initializedBindings = <String>[];

    initializePlantCareFlutterBinding(
      isDebugMode: false,
      marionette: () => initializedBindings.add('marionette'),
      standard: () => initializedBindings.add('standard'),
    );

    expect(initializedBindings, ['standard']);
  });
}
