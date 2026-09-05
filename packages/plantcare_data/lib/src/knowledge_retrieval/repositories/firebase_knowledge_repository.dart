import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_data/src/core/data_limits.dart';
import 'package:plantcare_data/src/knowledge_retrieval/models/knowledge_document_codec.dart';
import 'package:plantcare_domain/knowledge_retrieval.dart';

@LazySingleton(as: KnowledgeRepository)
final class FirebaseKnowledgeRepository implements KnowledgeRepository {
  const FirebaseKnowledgeRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  static const _selector = KnowledgeDatasetCompatibilitySelector();

  @override
  Future<KnowledgeEvidenceSet> loadPreferredEvidenceForPlant(
    String canonicalPlantKey,
  ) async {
    _requireAuthentication();
    if (!SupportedPlants.keys.contains(canonicalPlantKey)) {
      return KnowledgeEvidenceSet(
        datasetVersion: KnowledgeVersions.dataset,
        canonicalPlantKey: canonicalPlantKey,
        chunks: const [],
        sources: const [],
      );
    }
    try {
      final preferred = await _loadPreferredEvidence(canonicalPlantKey);
      final fallback = preferred == null
          ? await _loadProductionEvidence(canonicalPlantKey)
          : null;
      if (preferred != null) {
        final placeholderFallback = KnowledgeEvidenceSet(
          datasetVersion: KnowledgeVersions.dataset,
          canonicalPlantKey: canonicalPlantKey,
          chunks: const [],
          sources: const [],
        );
        final selected = _selector.select(
          fallback: placeholderFallback,
          preferred: preferred,
        );
        if (selected.datasetVersion == KnowledgeVersions.preferredDataset) {
          return selected;
        }
      }
      return _selector.select(
        fallback: fallback ?? await _loadProductionEvidence(canonicalPlantKey),
      );
    } catch (error, stackTrace) {
      throw _mapError(error, stackTrace);
    }
  }

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
          .limit(DataLimits.maxKnowledgeChunksPerPlant)
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

  Future<KnowledgeEvidenceSet?> _loadPreferredEvidence(
    String canonicalPlantKey,
  ) async {
    final release = _firestore
        .collection('knowledgeDatasets')
        .doc(KnowledgeVersions.preferredDataset);
    final manifest = await release.get();
    final data = manifest.data();
    if (data == null ||
        !KnowledgeDocumentCodec.isCompletePreferredRelease(data)) {
      return null;
    }
    return _loadEvidence(
      canonicalPlantKey: canonicalPlantKey,
      datasetVersion: KnowledgeVersions.preferredDataset,
      chunks: release.collection('chunks'),
      sources: release.collection('sources'),
    );
  }

  Future<KnowledgeEvidenceSet> _loadProductionEvidence(
    String canonicalPlantKey,
  ) => _loadEvidence(
    canonicalPlantKey: canonicalPlantKey,
    datasetVersion: KnowledgeVersions.dataset,
    chunks: _firestore.collection('knowledgeChunks'),
    sources: _firestore.collection('knowledgeSources'),
  );

  Future<KnowledgeEvidenceSet> _loadEvidence({
    required String canonicalPlantKey,
    required String datasetVersion,
    required CollectionReference<Map<String, dynamic>> chunks,
    required CollectionReference<Map<String, dynamic>> sources,
  }) async {
    final snapshot = await chunks
        .where('canonicalPlantKey', isEqualTo: canonicalPlantKey)
        .where('datasetVersion', isEqualTo: datasetVersion)
        .limit(DataLimits.maxKnowledgeChunksPerPlant)
        .get();
    final chunkDocuments = KnowledgeDocumentCodec.chunks({
      for (final document in snapshot.docs) document.id: document.data(),
    });
    final sourceIds =
        chunkDocuments.items
            .expand((chunk) => chunk.sourceIds)
            .toSet()
            .toList(growable: false)
          ..sort();
    final sourceSnapshots = await Future.wait(
      sourceIds.map((id) => sources.doc(id).get()),
    );
    final sourceDocuments = KnowledgeDocumentCodec.sources({
      for (final source in sourceSnapshots)
        source.id: source.exists ? source.data() : null,
    });
    return KnowledgeEvidenceSet(
      datasetVersion: datasetVersion,
      canonicalPlantKey: canonicalPlantKey,
      chunks: chunkDocuments.items,
      sources: sourceDocuments.items,
      warnings: [...chunkDocuments.warnings, ...sourceDocuments.warnings],
    );
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
