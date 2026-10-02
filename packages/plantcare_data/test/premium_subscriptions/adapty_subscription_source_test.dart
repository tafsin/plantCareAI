import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom paywall uses direct purchase without AdaptyUI presentation', () {
    final source = File('lib/src/premium_subscriptions/adapty_sdk_facade.dart')
        .readAsStringSync();

    expect(source, contains('withActivateUI(false)'));
    expect(source, contains('Adapty().makePurchase'));
    expect(source, isNot(contains('createFlowView')));
    expect(source, isNot(contains('setFlowsEventsObserver')));
    expect(source, isNot(contains('AdaptyUIFlowView')));
  });

  test('subscription diagnostics never interpolate the SDK key', () {
    final source = File(
      'lib/src/premium_subscriptions/adapty_premium_subscription_repository.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('developer.log(key')));
    expect(source, isNot(contains('developer.log(apiKey')));
    expect(source, isNot(contains(r'$key')));
  });
}
