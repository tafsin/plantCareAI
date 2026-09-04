import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/core/constants/app_constants.dart';
import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/care_history/data/models/care_log_codec.dart';
import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';
import 'package:plantcare_ai/features/care_history/domain/repositories/care_log_repository.dart';

@LazySingleton(as: CareLogRepository)
final class FirebaseCareLogRepository implements CareLogRepository {
  const FirebaseCareLogRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _plant(String plantId) {
    final user = _auth.currentUser;
    if (user == null) {
      throw const CareLogFailure(
        CareLogFailureType.unauthenticated,
        'Sign in to use care history.',
      );
    }
    if (!_validId(plantId)) {
      throw const CareLogFailure(
        CareLogFailureType.missingParent,
        'Plant not found.',
      );
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .doc(plantId);
  }

  CollectionReference<Map<String, dynamic>> _logs(String plantId) =>
      _plant(plantId).collection('careLogs');

  @override
  Stream<List<CareLog>> watchForPlant(String plantId) => _watch(plantId);

  Stream<List<CareLog>> _watch(String plantId) async* {
    try {
      if (!(await _plant(plantId).get()).exists) {
        throw const CareLogFailure(
          CareLogFailureType.missingParent,
          'Plant not found.',
        );
      }
      await for (final snapshot
          in _logs(plantId)
              .orderBy('occurredAt', descending: true)
              .limit(AppConstants.maxHistoryItemsPerPlant)
              .snapshots(includeMetadataChanges: true)) {
        final logs = <CareLog>[];
        for (final document in snapshot.docs) {
          try {
            logs.add(CareLogCodec.fromFirestore(document));
          } catch (error, stackTrace) {
            _diagnoseMalformed(document.id, error, stackTrace);
          }
        }
        logs.sort(_newestFirst);
        yield List<CareLog>.unmodifiable(logs);
      }
    } catch (error, stackTrace) {
      throw _map(error, stackTrace);
    }
  }

  @override
  Future<CareLog?> getById(String plantId, String careLogId) async {
    if (!_validId(careLogId)) return null;
    try {
      if (!(await _plant(plantId).get()).exists) {
        throw const CareLogFailure(
          CareLogFailureType.missingParent,
          'Plant not found.',
        );
      }
      final snapshot = await _logs(plantId).doc(careLogId).get();
      if (!snapshot.exists) return null;
      try {
        return CareLogCodec.fromFirestore(snapshot);
      } catch (error, stackTrace) {
        _diagnoseMalformed(careLogId, error, stackTrace);
        throw const CareLogFailure(
          CareLogFailureType.malformedData,
          'This care log is invalid and cannot be displayed.',
        );
      }
    } catch (error, stackTrace) {
      throw _map(error, stackTrace);
    }
  }

  @override
  Future<String> addWatering(String plantId, WateringLog log) =>
      _add(plantId, log);

  @override
  Future<String> addFertilizing(String plantId, FertilizingLog log) =>
      _add(plantId, log);

  Future<String> _add(String plantId, CareLog log) async {
    try {
      if (!(await _plant(plantId).get()).exists) {
        throw const CareLogFailure(
          CareLogFailureType.missingParent,
          'Plant not found.',
        );
      }
      return (await _logs(plantId).add(CareLogCodec.toFirestore(log))).id;
    } catch (error, stackTrace) {
      throw _map(error, stackTrace);
    }
  }

  @override
  Future<void> delete(String plantId, String careLogId) async {
    if (!_validId(careLogId)) {
      throw const CareLogFailure(
        CareLogFailureType.notFound,
        'Care log not found.',
      );
    }
    try {
      if (!(await _plant(plantId).get()).exists) {
        throw const CareLogFailure(
          CareLogFailureType.missingParent,
          'Plant not found.',
        );
      }
      final reference = _logs(plantId).doc(careLogId);
      if (!(await reference.get()).exists) {
        throw const CareLogFailure(
          CareLogFailureType.notFound,
          'Care log not found.',
        );
      }
      await reference.delete();
    } catch (error, stackTrace) {
      throw _map(error, stackTrace);
    }
  }

  CareLogFailure _map(Object error, StackTrace stackTrace) {
    if (error is CareLogFailure) return error;
    if (kDebugMode) {
      developer.log(
        'Firestore care-log operation failed',
        name: 'plantcare_ai.care_history',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => const CareLogFailure(
          CareLogFailureType.permissionDenied,
          'You do not have access to this care history.',
        ),
        'unauthenticated' => const CareLogFailure(
          CareLogFailureType.unauthenticated,
          'Sign in to use care history.',
        ),
        'unavailable' || 'deadline-exceeded' => const CareLogFailure(
          CareLogFailureType.network,
          'Check your connection and try again.',
        ),
        'not-found' => const CareLogFailure(
          CareLogFailureType.notFound,
          'Care log not found.',
        ),
        _ => const CareLogFailure(
          CareLogFailureType.unknown,
          'Couldn\'t update care history. Try again.',
        ),
      };
    }
    return const CareLogFailure(
      CareLogFailureType.unknown,
      'Couldn\'t update care history. Try again.',
    );
  }

  void _diagnoseMalformed(String id, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    developer.log(
      'Excluded malformed care log $id',
      name: 'plantcare_ai.care_history',
      error: error.runtimeType,
      stackTrace: stackTrace,
    );
  }

  static int _newestFirst(CareLog left, CareLog right) {
    final time = right.occurredAt.compareTo(left.occurredAt);
    return time != 0 ? time : right.id.compareTo(left.id);
  }

  static bool _validId(String value) =>
      value.trim().isNotEmpty && !value.contains('/');
}
