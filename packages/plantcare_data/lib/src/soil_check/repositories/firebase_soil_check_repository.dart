import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_data/src/core/data_limits.dart';
import 'package:plantcare_data/src/soil_check/models/soil_check_codec.dart';
import 'package:plantcare_domain/soil_check.dart';

@LazySingleton(as: SoilCheckRepository)
final class FirebaseSoilCheckRepository implements SoilCheckRepository {
  const FirebaseSoilCheckRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _checks(String plantId) {
    final user = _auth.currentUser;
    if (user == null) {
      throw const SoilCheckFailure(
        SoilCheckFailureType.unauthenticated,
        'Sign in to use soil checks.',
      );
    }
    if (!_validId(plantId)) {
      throw const SoilCheckFailure(
        SoilCheckFailureType.plantNotFound,
        'Plant not found.',
      );
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .doc(plantId)
        .collection('soilChecks');
  }

  @override
  Future<String> save(String plantId, SoilCheckRecord record) async {
    try {
      final result = await _checks(plantId)
          .add(SoilCheckCodec.toFirestore(record));
      return result.id;
    } catch (error, stackTrace) {
      throw _map(error, stackTrace, saving: true);
    }
  }

  @override
  Stream<List<SoilCheckRecord>> watchHistory(String plantId) {
    try {
      return _checks(plantId)
          .orderBy('createdAt', descending: true)
          .limit(DataLimits.maxHistoryItemsPerPlant)
          .snapshots(includeMetadataChanges: true)
          .map(
            (value) => value.docs
                .map(SoilCheckCodec.fromFirestore)
                .toList(growable: false),
          )
          .handleError(
            (Object error, StackTrace stack) => throw _map(error, stack),
          );
    } catch (error, stackTrace) {
      throw _map(error, stackTrace);
    }
  }

  @override
  Stream<SoilCheckRecord?> watchDetails(String plantId, String soilCheckId) {
    if (!_validId(soilCheckId)) return Stream.value(null);
    try {
      return _checks(plantId)
          .doc(soilCheckId)
          .snapshots(includeMetadataChanges: true)
          .map(
            (value) =>
                value.exists ? SoilCheckCodec.fromFirestore(value) : null,
          )
          .handleError(
            (Object error, StackTrace stack) => throw _map(error, stack),
          );
    } catch (error, stackTrace) {
      throw _map(error, stackTrace);
    }
  }

  @override
  Future<void> delete(String plantId, String soilCheckId) async {
    if (!_validId(soilCheckId)) {
      throw const SoilCheckFailure(
        SoilCheckFailureType.notFound,
        'Soil check not found.',
      );
    }
    try {
      await _checks(plantId).doc(soilCheckId).delete();
    } catch (error, stackTrace) {
      throw _map(error, stackTrace);
    }
  }

  bool _validId(String value) =>
      value.trim().isNotEmpty && !value.contains('/');

  SoilCheckFailure _map(
    Object error,
    StackTrace stackTrace, {
    bool saving = false,
  }) {
    if (error is SoilCheckFailure) return error;
    if (kDebugMode) {
      developer.log(
        'Firestore soil check operation failed',
        name: 'plantcare_ai.soil_check',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
    if (error is FirebaseException &&
        (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
      return const SoilCheckFailure(
        SoilCheckFailureType.network,
        'Check your connection and try again.',
      );
    }
    return SoilCheckFailure(
      saving ? SoilCheckFailureType.saveFailed : SoilCheckFailureType.unknown,
      saving
          ? 'The recommendation is ready but could not be saved.'
          : 'Couldn\'t load soil checks. Try again.',
    );
  }
}
