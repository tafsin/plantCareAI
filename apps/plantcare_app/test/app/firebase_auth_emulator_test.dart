import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_app/app/bootstrap/firebase_auth_emulator.dart';

void main() {
  test('uses Android emulator loopback from an Android application', () {
    expect(
      firebaseAuthEmulatorHost(platform: TargetPlatform.android, isWeb: false),
      '10.0.2.2',
    );
  });

  test('uses localhost for web and iOS simulator applications', () {
    expect(
      firebaseAuthEmulatorHost(platform: TargetPlatform.android, isWeb: true),
      'localhost',
    );
    expect(
      firebaseAuthEmulatorHost(platform: TargetPlatform.iOS, isWeb: false),
      'localhost',
    );
  });
}
