import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_shared/environment.dart';

@InjectableInit.microPackage(
  ignoreUnregisteredTypes: [FirebaseAuth, FirebaseFirestore, EnvironmentConfig],
)
void initMicroPackage() {}
