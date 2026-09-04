import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/core/data/data_limits.dart';
import 'package:plantcare_ai/features/plant_diagnosis/data/models/plant_diagnosis_codec.dart';
import 'package:plantcare_ai/features/plant_diagnosis/domain/entities/plant_diagnosis.dart';
import 'package:plantcare_ai/features/plant_diagnosis/domain/errors/plant_diagnosis_failure.dart';
import 'package:plantcare_ai/features/plant_diagnosis/domain/repositories/plant_diagnosis_repository.dart';

@LazySingleton(as: PlantDiagnosisRepository)
final class FirebasePlantDiagnosisRepository
    implements PlantDiagnosisRepository {
  const FirebasePlantDiagnosisRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _diagnoses(
    String plantId,
    String observationId,
  ) {
    final user = _auth.currentUser;
    if (user == null) {
      throw const PlantDiagnosisFailure(
        PlantDiagnosisFailureType.unauthenticated,
        'Sign in to access grounded diagnoses.',
      );
    }
    if (!_validId(plantId) || !_validId(observationId)) {
      throw const PlantDiagnosisFailure(
        PlantDiagnosisFailureType.notFound,
        'Plant observation not found.',
      );
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .doc(plantId)
        .collection('observations')
        .doc(observationId)
        .collection('diagnoses');
  }

  @override
  Future<String> saveDiagnosis(
    String plantId,
    String observationId,
    PlantDiagnosis diagnosis,
  ) async {
    try {
      final reference = await _diagnoses(
        plantId,
        observationId,
      ).add(PlantDiagnosisCodec.toFirestore(diagnosis));
      return reference.id;
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace, saving: true);
    }
  }

  @override
  Stream<List<PlantDiagnosis>> watchDiagnoses(
    String plantId,
    String observationId,
  ) {
    try {
      return _diagnoses(plantId, observationId)
          .orderBy('createdAt', descending: true)
          .limit(DataLimits.maxHistoryItemsPerPlant)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => snapshot.docs
                .map(PlantDiagnosisCodec.fromFirestore)
                .toList(growable: false),
          )
          .handleError((Object error, StackTrace stackTrace) {
            throw _mapError(error, stackTrace);
          });
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Stream<PlantDiagnosis?> watchDiagnosis(
    String plantId,
    String observationId,
    String diagnosisId,
  ) {
    if (!_validId(diagnosisId)) return Stream.value(null);
    try {
      return _diagnoses(plantId, observationId)
          .doc(diagnosisId)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => snapshot.exists
                ? PlantDiagnosisCodec.fromFirestore(snapshot)
                : null,
          )
          .handleError((Object error, StackTrace stackTrace) {
            throw _mapError(error, stackTrace);
          });
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  bool _validId(String value) =>
      value.trim().isNotEmpty && value == value.trim() && !value.contains('/');

  PlantDiagnosisFailure _mapError(
    Object error,
    StackTrace stackTrace, {
    bool saving = false,
  }) {
    if (error is PlantDiagnosisFailure) return error;
    if (kDebugMode) {
      developer.log(
        'Firestore diagnosis operation failed',
        name: 'plantcare_ai.diagnosis',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'unauthenticated' => const PlantDiagnosisFailure(
          PlantDiagnosisFailureType.unauthenticated,
          'Sign in to access grounded diagnoses.',
        ),
        'permission-denied' => PlantDiagnosisFailure(
          saving
              ? PlantDiagnosisFailureType.saveFailed
              : PlantDiagnosisFailureType.notFound,
          saving
              ? 'The diagnosis was generated but could not be saved.'
              : 'Diagnosis not found or unavailable.',
        ),
        'unavailable' || 'deadline-exceeded' => PlantDiagnosisFailure(
          saving
              ? PlantDiagnosisFailureType.saveFailed
              : PlantDiagnosisFailureType.network,
          saving
              ? 'The diagnosis was generated but could not be saved.'
              : 'Check your connection and try again.',
        ),
        _ => PlantDiagnosisFailure(
          saving
              ? PlantDiagnosisFailureType.saveFailed
              : PlantDiagnosisFailureType.unknown,
          saving
              ? 'The diagnosis was generated but could not be saved.'
              : 'Couldn\'t load grounded diagnoses. Try again.',
        ),
      };
    }
    return PlantDiagnosisFailure(
      saving
          ? PlantDiagnosisFailureType.saveFailed
          : PlantDiagnosisFailureType.unknown,
      saving
          ? 'The diagnosis was generated but could not be saved.'
          : 'Couldn\'t load grounded diagnoses. Try again.',
    );
  }
}
