import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/core/constants/app_constants.dart';
import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/data/models/knowledge_document_codec.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/entities/knowledge_retrieval.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/repositories/knowledge_repository.dart';
import 'package:plantcare_ai/features/knowledge_retrieval/domain/services/plant_name_resolver.dart';

@LazySingleton(as: KnowledgeRepository)
final class FirebaseKnowledgeRepository implements KnowledgeRepository {
  const FirebaseKnowledgeRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<KnowledgeDocuments<KnowledgeChunk>> loadChunksForPlant(
    String canonicalPlantKey,
  ) async {
    _requireAuthentication();
    if (!SupportedPlants.keys.contains(canonicalPlantKey)) {
      return const KnowledgeDocuments(items: []);
    }
    try {
      final snapshot = await _firestore
          .collection('knowledgeChunks')
          .where('canonicalPlantKey', isEqualTo: canonicalPlantKey)
          .where('datasetVersion', isEqualTo: KnowledgeVersions.dataset)
          .limit(AppConstants.maxKnowledgeChunksPerPlant)
          .get();
      final result = KnowledgeDocumentCodec.chunks({
        for (final document in snapshot.docs) document.id: document.data(),
      });
      for (final warning in result.warnings) {
        _safeDiagnostic(warning);
      }
      return result;
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<KnowledgeDocuments<KnowledgeSource>> loadSources(
    Set<String> ids,
  ) async {
    _requireAuthentication();
    final safeIds = ids.where(_validId).toList(growable: false)..sort();
    try {
      final snapshots = await Future.wait(
        safeIds.map(
          (id) => _firestore.collection('knowledgeSources').doc(id).get(),
        ),
      );
      final result = KnowledgeDocumentCodec.sources({
        for (final snapshot in snapshots)
          snapshot.id: snapshot.exists ? snapshot.data() : null,
      });
      for (final warning in result.warnings) {
        _safeDiagnostic(warning);
      }
      return result;
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

  void _requireAuthentication() {
    if (_auth.currentUser == null) {
      throw const KnowledgeRetrievalFailure(
        KnowledgeRetrievalFailureType.unauthenticated,
        'Sign in to retrieve plant-care knowledge.',
      );
    }
  }

  bool _validId(String value) =>
      value.trim().isNotEmpty && value == value.trim() && !value.contains('/');

  void _safeDiagnostic(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'plantcare_ai.knowledge');
    }
  }

  KnowledgeRetrievalFailure _mapError(Object error, StackTrace stackTrace) {
    if (error is KnowledgeRetrievalFailure) return error;
    if (kDebugMode) {
      developer.log(
        'Firestore knowledge read failed',
        name: 'plantcare_ai.knowledge',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => const KnowledgeRetrievalFailure(
          KnowledgeRetrievalFailureType.permissionDenied,
          'You don\'t have permission to read the knowledge library.',
        ),
        'unauthenticated' => const KnowledgeRetrievalFailure(
          KnowledgeRetrievalFailureType.unauthenticated,
          'Sign in to retrieve plant-care knowledge.',
        ),
        'unavailable' || 'deadline-exceeded' => const KnowledgeRetrievalFailure(
          KnowledgeRetrievalFailureType.network,
          'Check your connection and try again.',
        ),
        _ => const KnowledgeRetrievalFailure(
          KnowledgeRetrievalFailureType.unknown,
          'Couldn\'t retrieve plant-care knowledge. Try again.',
        ),
      };
    }
    return const KnowledgeRetrievalFailure(
      KnowledgeRetrievalFailureType.unknown,
      'Couldn\'t retrieve plant-care knowledge. Try again.',
    );
  }
}
