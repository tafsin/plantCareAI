import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/core/constants/app_constants.dart';
import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/data/models/fertilizer_assessment_codec.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/entities/fertilizer_assessment.dart';
import 'package:plantcare_ai/features/fertilizer_assessment/domain/repositories/fertilizer_assessment_repository.dart';

@LazySingleton(as: FertilizerAssessmentRepository)
final class FirebaseFertilizerAssessmentRepository
    implements FertilizerAssessmentRepository {
  const FirebaseFertilizerAssessmentRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _assessments(String plantId) {
    final user = _auth.currentUser;
    if (user == null) {
      throw const FertilizerAssessmentFailure(
        FertilizerAssessmentFailureType.unauthenticated,
        'Sign in to use fertilizer guidance.',
      );
    }
    if (!_validId(plantId)) {
      throw const FertilizerAssessmentFailure(
        FertilizerAssessmentFailureType.plantNotFound,
        'Plant not found.',
      );
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .doc(plantId)
        .collection('fertilizerAssessments');
  }

  @override
  Future<String> save(String plantId, FertilizerAssessment assessment) async {
    try {
      return (await _assessments(plantId)
              .add(FertilizerAssessmentCodec.toFirestore(assessment)))
          .id;
    } catch (error, stackTrace) {
      throw _map(error, stackTrace, saving: true);
    }
  }

  @override
  Stream<List<FertilizerAssessment>> watchHistory(String plantId) {
    try {
      return _assessments(plantId)
          .orderBy('createdAt', descending: true)
          .limit(AppConstants.maxHistoryItemsPerPlant)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => snapshot.docs
                .map(FertilizerAssessmentCodec.fromFirestore)
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
  Stream<FertilizerAssessment?> watchDetails(
    String plantId,
    String assessmentId,
  ) {
    if (!_validId(assessmentId)) return Stream.value(null);
    try {
      return _assessments(plantId)
          .doc(assessmentId)
          .snapshots(includeMetadataChanges: true)
          .map(
            (snapshot) => snapshot.exists
                ? FertilizerAssessmentCodec.fromFirestore(snapshot)
                : null,
          )
          .handleError(
            (Object error, StackTrace stack) => throw _map(error, stack),
          );
    } catch (error, stackTrace) {
      throw _map(error, stackTrace);
    }
  }

  @override
  Future<void> delete(String plantId, String assessmentId) async {
    if (!_validId(assessmentId)) {
      throw const FertilizerAssessmentFailure(
        FertilizerAssessmentFailureType.notFound,
        'Fertilizer assessment not found.',
      );
    }
    try {
      await _assessments(plantId).doc(assessmentId).delete();
    } catch (error, stackTrace) {
      throw _map(error, stackTrace);
    }
  }

  FertilizerAssessmentFailure _map(
    Object error,
    StackTrace stackTrace, {
    bool saving = false,
  }) {
    if (error is FertilizerAssessmentFailure) return error;
    if (kDebugMode) {
      developer.log(
        'Firestore fertilizer assessment operation failed',
        name: 'plantcare_ai.fertilizer_assessment',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
    if (error is FirebaseException &&
        (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
      return const FertilizerAssessmentFailure(
        FertilizerAssessmentFailureType.network,
        'Check your connection and try again.',
      );
    }
    return FertilizerAssessmentFailure(
      saving
          ? FertilizerAssessmentFailureType.saveFailed
          : FertilizerAssessmentFailureType.unknown,
      saving
          ? 'The guidance is ready but could not be saved.'
          : 'Couldn\'t load fertilizer assessments. Try again.',
    );
  }

  static bool _validId(String value) =>
      value.trim().isNotEmpty && !value.contains('/');
}
