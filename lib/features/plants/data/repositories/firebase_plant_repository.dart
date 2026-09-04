import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/core/constants/app_constants.dart';
import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/plants/data/models/firestore_plant_model.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';
import 'package:plantcare_ai/features/plants/domain/repositories/plant_repository.dart';

@LazySingleton(as: PlantRepository)
final class FirebasePlantRepository implements PlantRepository {
  const FirebasePlantRepository(this._firestore, this._firebaseAuth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> _plants() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const PlantFailure(
        PlantFailureType.unauthenticated,
        'Sign in to manage your plants.',
      );
    }
    return _firestore.collection('users').doc(user.uid).collection('plants');
  }

  @override
  Stream<List<Plant>> watchPlants() {
    try {
      return _plants()
          .orderBy('updatedAt', descending: true)
          .limit(AppConstants.maxPlantsPerUser)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) =>
                snapshot.docs.map(FirestorePlantModel.fromSnapshot).toList(),
          )
          .handleError(_mapStreamError);
    } on PlantFailure {
      rethrow;
    } catch (error, stackTrace) {
      throw _mapError('watch plants', error, stackTrace);
    }
  }

  @override
  Stream<Plant?> watchPlant(String plantId) {
    if (plantId.trim().isEmpty || plantId.contains('/')) {
      return Stream.value(null);
    }
    try {
      return _plants()
          .doc(plantId)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => snapshot.exists
                ? FirestorePlantModel.fromSnapshot(snapshot)
                : null,
          )
          .handleError(_mapStreamError);
    } on PlantFailure {
      rethrow;
    } catch (error, stackTrace) {
      throw _mapError('watch plant', error, stackTrace);
    }
  }

  @override
  Future<String> addPlant(PlantDraft plant) async {
    try {
      final reference = await _plants().add(
        FirestorePlantModel.createData(plant),
      );
      return reference.id;
    } catch (error, stackTrace) {
      throw _mapError('add plant', error, stackTrace);
    }
  }

  @override
  Future<void> updatePlant(String plantId, PlantDraft plant) async {
    try {
      await _plants()
          .doc(plantId)
          .update(FirestorePlantModel.updateData(plant));
    } catch (error, stackTrace) {
      throw _mapError('update plant', error, stackTrace);
    }
  }

  @override
  Future<void> deletePlant(String plantId) async {
    try {
      await _plants().doc(plantId).delete();
    } catch (error, stackTrace) {
      throw _mapError('delete plant', error, stackTrace);
    }
  }

  Never _mapStreamError(Object error, StackTrace stackTrace) {
    throw _mapError('read plants', error, stackTrace);
  }

  PlantFailure _mapError(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    if (error is PlantFailure) return error;
    if (kDebugMode) {
      developer.log(
        'Firestore failed during $operation',
        name: 'plantcare_ai.plants',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => const PlantFailure(
          PlantFailureType.permissionDenied,
          'You don\'t have permission to access this plant.',
        ),
        'not-found' => const PlantFailure(
          PlantFailureType.notFound,
          'Plant not found.',
        ),
        'unavailable' || 'deadline-exceeded' => const PlantFailure(
          PlantFailureType.network,
          'Check your connection and try again.',
        ),
        _ => const PlantFailure(
          PlantFailureType.unknown,
          'Couldn\'t complete that plant request. Please try again.',
        ),
      };
    }
    return const PlantFailure(
      PlantFailureType.unknown,
      'Couldn\'t complete that plant request. Please try again.',
    );
  }
}
