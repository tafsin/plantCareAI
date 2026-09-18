import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_data/src/account_management/account_firestore_gateway.dart';

void main() {
  test('exhausts multiple pages with acknowledged sub-500 commits', () async {
    final driver = _Driver();
    for (var plant = 0; plant < 3; plant += 1) {
      final plantPath = ['users', 'owner', 'plants', 'plant-$plant'];
      driver.add(plantPath);
      for (var observation = 0; observation < 4; observation += 1) {
        final observationPath = [
          ...plantPath,
          'observations',
          'observation-$observation',
        ];
        driver.add(observationPath);
        for (var diagnosis = 0; diagnosis < 3; diagnosis += 1) {
          driver.add([...observationPath, 'diagnoses', 'diagnosis-$diagnosis']);
        }
      }
      for (final collection
          in FirebaseAccountFirestoreGateway.childCollections) {
        for (var item = 0; item < 4; item += 1) {
          driver.add([...plantPath, collection, '$collection-$item']);
        }
      }
    }
    driver.add(['users', 'other', 'plants', 'untouched']);
    driver.add(['knowledgeChunks', 'curated']);

    final gateway = FirebaseAccountFirestoreGateway.withDriver(
      driver,
      pageSize: 2,
    );
    await gateway.deleteAllApplicationData('owner');
    await gateway.verifyApplicationDataDeleted('owner');

    expect(
      driver.paths.where((path) => path.contains('/users/owner/')),
      isEmpty,
    );
    expect(driver.paths, contains('/users/other/plants/untouched'));
    expect(driver.paths, contains('/knowledgeChunks/curated'));
    expect(driver.maxCommitSize, lessThan(500));
    expect(driver.queryLimits, containsAll([1, 2]));
    expect(driver.queriedPaths, isNot(contains('/knowledgeChunks')));
  });

  test(
    'deletes diagnoses before observations and descendants before plants',
    () async {
      final driver = _Driver()
        ..add(['users', 'owner', 'plants', 'plant'])
        ..add([
          'users',
          'owner',
          'plants',
          'plant',
          'observations',
          'observation',
        ])
        ..add([
          'users',
          'owner',
          'plants',
          'plant',
          'observations',
          'observation',
          'diagnoses',
          'diagnosis',
        ])
        ..add(['users', 'owner', 'plants', 'plant', 'reminders', 'reminder']);
      final gateway = FirebaseAccountFirestoreGateway.withDriver(driver);

      await gateway.deleteAllApplicationData('owner');

      final diagnosis = driver.deleted.indexWhere(
        (path) => path.endsWith('/diagnosis'),
      );
      final observation = driver.deleted.indexWhere(
        (path) => path.endsWith('/observation'),
      );
      final reminder = driver.deleted.indexWhere(
        (path) => path.endsWith('/reminder'),
      );
      final plant = driver.deleted.indexWhere(
        (path) => path.endsWith('/plant'),
      );
      expect(diagnosis, lessThan(observation));
      expect(observation, lessThan(plant));
      expect(reminder, lessThan(plant));
    },
  );

  test('empty and missing accounts are successful idempotent no-ops', () async {
    final driver = _Driver();
    final gateway = FirebaseAccountFirestoreGateway.withDriver(driver);

    await gateway.deleteAllApplicationData('owner');
    await gateway.deleteAllApplicationData('owner');
    await gateway.verifyApplicationDataDeleted('owner');

    expect(driver.deleted, isEmpty);
  });

  test(
    'commit failure stops, preserves Auth-independent state, and retry resumes',
    () async {
      final driver = _Driver();
      final plantPath = ['users', 'owner', 'plants', 'plant'];
      driver
        ..add(plantPath)
        ..add([...plantPath, 'careLogs', 'care-1'])
        ..add([...plantPath, 'careLogs', 'care-2'])
        ..add([...plantPath, 'careLogs', 'care-3'])
        ..failCommitNumber = 2;
      final gateway = FirebaseAccountFirestoreGateway.withDriver(
        driver,
        pageSize: 2,
      );

      await expectLater(
        gateway.deleteAllApplicationData('owner'),
        throwsA(isA<StateError>()),
      );
      expect(driver.paths, isNotEmpty);

      driver.failCommitNumber = null;
      await gateway.deleteAllApplicationData('owner');
      await gateway.verifyApplicationDataDeleted('owner');
      await gateway.deleteAllApplicationData('owner');
      expect(driver.paths, isEmpty);
    },
  );

  test('query failure and final verification failure propagate', () async {
    final queryDriver = _Driver()..failQueryNumber = 1;
    await expectLater(
      FirebaseAccountFirestoreGateway.withDriver(queryDriver)
          .deleteAllApplicationData('owner'),
      throwsA(isA<StateError>()),
    );

    final verifyDriver = _Driver()
      ..add(['users', 'owner', 'plants', 'late-write']);
    await expectLater(
      FirebaseAccountFirestoreGateway.withDriver(verifyDriver)
          .verifyApplicationDataDeleted('owner'),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'cleanup handoff driver receives only authenticated UID and exact source',
    () async {
      final driver = _Driver();
      final gateway = FirebaseAccountFirestoreGateway.withDriver(driver);

      await gateway.createProviderCleanupRequest(
        uid: 'authenticated-uid',
        source: 'self_service_web',
      );

      expect(driver.cleanupRequests, [
        (uid: 'authenticated-uid', source: 'self_service_web'),
      ]);
    },
  );
}

final class _Driver implements AccountFirestoreDriver {
  final paths = <String>{};
  final deleted = <String>[];
  final queriedPaths = <String>[];
  final queryLimits = <int>[];
  final cleanupRequests = <({String uid, String source})>[];
  int? failCommitNumber;
  int? failQueryNumber;
  int commitCount = 0;
  int queryCount = 0;
  int maxCommitSize = 0;

  void add(List<String> path) => paths.add('/${path.join('/')}');

  @override
  Future<void> createProviderCleanupRequest({
    required String uid,
    required String source,
  }) async => cleanupRequests.add((uid: uid, source: source));

  @override
  Future<List<AccountFirestoreDocument>> queryPage(
    List<String> collectionPath, {
    required int limit,
  }) async {
    queryCount += 1;
    if (failQueryNumber == queryCount) throw StateError('query failed');
    final collection = '/${collectionPath.join('/')}';
    queriedPaths.add(collection);
    queryLimits.add(limit);
    final expectedSegments = collectionPath.length + 1;
    final matches = paths.where((path) {
      final segments = path.substring(1).split('/');
      return path.startsWith('$collection/') &&
          segments.length == expectedSegments;
    }).toList()..sort();
    return matches
        .take(limit)
        .map((path) => AccountFirestoreDocument(path.substring(1).split('/')))
        .toList(growable: false);
  }

  @override
  Future<void> deleteDocuments(List<AccountFirestoreDocument> documents) async {
    commitCount += 1;
    if (failCommitNumber == commitCount) throw StateError('commit failed');
    maxCommitSize = documents.length > maxCommitSize
        ? documents.length
        : maxCommitSize;
    for (final document in documents) {
      final path = '/${document.path.join('/')}';
      paths.remove(path);
      deleted.add(path);
    }
  }
}
