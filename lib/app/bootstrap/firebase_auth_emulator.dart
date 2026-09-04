import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:plantcare_ai/core/utils/environment_config.dart';

Future<void> configureFirebaseEmulators({
  required FirebaseAuth firebaseAuth,
  required FirebaseFirestore firebaseFirestore,
  required EnvironmentConfig environmentConfig,
}) async {
  if (!environmentConfig.useFirebaseAuthEmulator) {
    return;
  }

  final host = firebaseAuthEmulatorHost(
    platform: defaultTargetPlatform,
    isWeb: kIsWeb,
  );
  await firebaseAuth.useAuthEmulator(host, 9099);
  firebaseFirestore.useFirestoreEmulator(host, 8080);
}

String firebaseAuthEmulatorHost({
  required TargetPlatform platform,
  required bool isWeb,
}) {
  return !isWeb && platform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';
}
