import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

abstract interface class AccountFirestoreGateway {
  Future<void> createProviderCleanupRequest({
    required String uid,
    required String source,
  });

  Future<void> deleteAllApplicationData(String uid);

  Future<void> verifyApplicationDataDeleted(String uid);
}

final class AccountFirestoreDocument {
  const AccountFirestoreDocument(this.path);

  final List<String> path;
  String get id => path.last;
}

abstract interface class AccountFirestoreDriver {
  Future<void> createProviderCleanupRequest({
    required String uid,
    required String source,
  });

  Future<List<AccountFirestoreDocument>> queryPage(
    List<String> collectionPath, {
    required int limit,
  });

  Future<void> deleteDocuments(List<AccountFirestoreDocument> documents);
}

final class FirebaseAccountFirestoreGateway implements AccountFirestoreGateway {
  FirebaseAccountFirestoreGateway(FirebaseFirestore firestore)
    : this.withDriver(_FirebaseAccountFirestoreDriver(firestore));

  @visibleForTesting
  FirebaseAccountFirestoreGateway.withDriver(this._driver, {int pageSize = 100})
    : assert(pageSize > 0 && pageSize < 500),
      _pageSize = pageSize;

  static const childCollections = <String>[
    'soilChecks',
    'careLogs',
    'fertilizerAssessments',
    'reminders',
  ];

  final AccountFirestoreDriver _driver;
  final int _pageSize;

  @override
  Future<void> createProviderCleanupRequest({
    required String uid,
    required String source,
  }) => _driver.createProviderCleanupRequest(uid: uid, source: source);

  @override
  Future<void> deleteAllApplicationData(String uid) async {
    final plants = ['users', uid, 'plants'];
    while (true) {
      final page = await _page(plants);
      if (page.isEmpty) return;
      for (final plant in page) {
        await _deletePlant(plant);
      }
    }
  }

  Future<void> _deletePlant(AccountFirestoreDocument plant) async {
    final observations = [...plant.path, 'observations'];
    while (true) {
      final page = await _page(observations);
      if (page.isEmpty) break;
      for (final observation in page) {
        final diagnoses = [...observation.path, 'diagnoses'];
        await _deleteCollection(diagnoses);
        await _requireEmpty(diagnoses);
        await _driver.deleteDocuments([observation]);
      }
    }
    for (final name in childCollections) {
      await _deleteCollection([...plant.path, name]);
    }
    await _requireEmpty(observations);
    for (final name in childCollections) {
      await _requireEmpty([...plant.path, name]);
    }
    await _driver.deleteDocuments([plant]);
  }

  Future<void> _deleteCollection(List<String> collectionPath) async {
    while (true) {
      final page = await _page(collectionPath);
      if (page.isEmpty) return;
      await _driver.deleteDocuments(page);
    }
  }

  Future<List<AccountFirestoreDocument>> _page(List<String> collectionPath) =>
      _driver.queryPage(collectionPath, limit: _pageSize);

  Future<void> _requireEmpty(List<String> collectionPath) async {
    if ((await _driver.queryPage(collectionPath, limit: 1)).isNotEmpty) {
      throw StateError('Account data verification failed.');
    }
  }

  @override
  Future<void> verifyApplicationDataDeleted(String uid) =>
      _requireEmpty(['users', uid, 'plants']);
}

final class _FirebaseAccountFirestoreDriver implements AccountFirestoreDriver {
  const _FirebaseAccountFirestoreDriver(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<void> createProviderCleanupRequest({
    required String uid,
    required String source,
  }) => _firestore.collection('accountDeletionCleanupRequests').doc(uid).set({
    'schemaVersion': 1,
    'requestedAt': FieldValue.serverTimestamp(),
    'providerCleanup': const ['adapty'],
    'source': source,
  });

  @override
  Future<List<AccountFirestoreDocument>> queryPage(
    List<String> collectionPath, {
    required int limit,
  }) async {
    final snapshot = await _collection(collectionPath)
        .orderBy(FieldPath.documentId)
        .limit(limit)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map(
          (document) =>
              AccountFirestoreDocument([...collectionPath, document.id]),
        )
        .toList(growable: false);
  }

  @override
  Future<void> deleteDocuments(List<AccountFirestoreDocument> documents) async {
    final batch = _firestore.batch();
    for (final document in documents) {
      batch.delete(_document(document.path));
    }
    await batch.commit();
  }

  CollectionReference<Map<String, dynamic>> _collection(List<String> path) {
    assert(path.isNotEmpty && path.length.isOdd);
    CollectionReference<Map<String, dynamic>> collection = _firestore
        .collection(path.first);
    for (var index = 1; index < path.length; index += 2) {
      collection = collection.doc(path[index]).collection(path[index + 1]);
    }
    return collection;
  }

  DocumentReference<Map<String, dynamic>> _document(List<String> path) {
    assert(path.length.isEven);
    return _collection(path.sublist(0, path.length - 1)).doc(path.last);
  }
}
