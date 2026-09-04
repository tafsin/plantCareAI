import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/core/data/data_limits.dart';
import 'package:plantcare_ai/features/plant_observation/data/models/plant_observation_codec.dart';
import 'package:plantcare_ai/features/plant_observation/domain/entities/plant_observation.dart';
import 'package:plantcare_ai/features/plant_observation/domain/errors/plant_observation_failure.dart';
import 'package:plantcare_ai/features/plant_observation/domain/repositories/plant_observation_repository.dart';

@LazySingleton(as: PlantObservationRepository)
final class FirebasePlantObservationRepository
    implements PlantObservationRepository {
  const FirebasePlantObservationRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _observations(String plantId) {
    final user = _auth.currentUser;
    if (user == null) {
      throw const PlantObservationFailure(
        PlantObservationFailureType.unauthenticated,
        'Sign in to view plant observations.',
      );
    }
    if (!_validId(plantId)) {
      throw const PlantObservationFailure(
        PlantObservationFailureType.plantNotFound,
        'Plant not found.',
      );
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .doc(plantId)
        .collection('observations');
  }

  @override
  Future<String> saveObservation(
    String plantId,
    PlantObservation observation,
  ) async {
    try {
      final reference = await _observations(plantId)
          .add(PlantObservationCodec.toFirestore(observation));
      return reference.id;
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace, saving: true);
    }
  }

  @override
  Stream<List<PlantObservation>> watchObservations(String plantId) {
    try {
      return _observations(plantId)
          .orderBy('createdAt', descending: true)
          .limit(DataLimits.maxHistoryItemsPerPlant)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => snapshot.docs
                .map(PlantObservationCodec.fromFirestore)
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
  Stream<PlantObservation?> watchObservation(
    String plantId,
    String observationId,
  ) {
    if (!_validId(observationId)) return Stream.value(null);
    try {
      return _observations(plantId)
          .doc(observationId)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => snapshot.exists
                ? PlantObservationCodec.fromFirestore(snapshot)
                : null,
          )
          .handleError((Object error, StackTrace stackTrace) {
            throw _mapError(error, stackTrace);
          });
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  bool _validId(String id) => id.trim().isNotEmpty && !id.contains('/');

  PlantObservationFailure _mapError(
    Object error,
    StackTrace stackTrace, {
    bool saving = false,
  }) {
    if (error is PlantObservationFailure) return error;
    if (kDebugMode) {
      developer.log(
        'Firestore observation operation failed',
        name: 'plantcare_ai.observation',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => const PlantObservationFailure(
          PlantObservationFailureType.plantNotFound,
          'Plant not found or unavailable.',
        ),
        'unauthenticated' => const PlantObservationFailure(
          PlantObservationFailureType.unauthenticated,
          'Sign in to view plant observations.',
        ),
        'unavailable' || 'deadline-exceeded' => const PlantObservationFailure(
          PlantObservationFailureType.network,
          'Check your connection and try again.',
        ),
        _ when saving => const PlantObservationFailure(
          PlantObservationFailureType.saveFailed,
          'The observation was created but could not be saved.',
        ),
        _ => const PlantObservationFailure(
          PlantObservationFailureType.unknown,
          'Couldn\'t load plant observations. Try again.',
        ),
      };
    }
    return PlantObservationFailure(
      saving
          ? PlantObservationFailureType.saveFailed
          : PlantObservationFailureType.unknown,
      saving
          ? 'The observation was created but could not be saved.'
          : 'Couldn\'t load plant observations. Try again.',
    );
  }
}
