import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_app/app/application/reminder_lifecycle_service.dart';
import 'package:plantcare_app/app/bootstrap/firebase_app_initializer.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_domain/reminders.dart';

import '../helpers/fake_authentication_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'authentication exposes current user and signed-in state changes',
    () async {
      final repository = FakeAuthenticationRepository();
      addTearDown(repository.close);
      final states = <AppUser?>[];
      final subscription = repository.authStateChanges.listen(states.add);
      addTearDown(subscription.cancel);

      expect(repository.currentUser, isNull);
      expect(repository.isSignedIn, isFalse);
      repository.emitAuthState(const AppUser(uid: 'user-1', email: null));
      expect(repository.isSignedIn, isTrue);
      repository.emitAuthState(null);

      expect(states, [const AppUser(uid: 'user-1', email: null), null]);
      expect(repository.currentUser, isNull);
    },
  );

  test(
    'application services start after Firebase, emulators, and App Check',
    () async {
      final calls = <String>[];
      final initializer = FirebaseAppInitializer(
        options: const FirebaseOptions(
          apiKey: 'test',
          appId: 'test',
          messagingSenderId: 'test',
          projectId: 'test',
        ),
        initializeFirebase: (_) async => calls.add('firebase'),
        configureEmulators: () async => calls.add('emulators'),
        activateAppCheck: () async => calls.add('app-check'),
        startApplicationServices: () async => calls.add('services'),
      );

      await initializer.initialize();

      expect(calls, ['firebase', 'emulators', 'app-check', 'services']);
    },
  );

  test(
    'reminder lifecycle follows the abstract authentication session',
    () async {
      final session = FakeAuthenticationRepository()
        ..currentUser = const AppUser(uid: 'user-1', email: null);
      final reminders = _ReminderRepository();
      final plants = _PlantRepository();
      final scheduler = _RecordingScheduler();
      addTearDown(session.close);
      addTearDown(reminders.close);
      addTearDown(plants.close);

      final service = ReminderLifecycleService(
        session,
        reminders,
        plants,
        scheduler,
      );
      await service.start();

      expect(scheduler.initializeCalls, 1);
      expect(reminders.watchCalls, 1);
      expect(plants.watchCalls, 1);

      plants.emit(const [
        Plant(
          id: 'plant-1',
          commonName: 'Pothos',
          environment: PlantEnvironment.indoor,
          growingMedium: GrowingMedium.pot,
          sunlight: Sunlight.partial,
          growthStage: GrowthStage.mature,
        ),
      ]);
      reminders.emit([
        Reminder(
          id: 'reminder-1',
          plantId: 'plant-1',
          type: ReminderType.soilCheck,
          dueAt: DateTime.now().add(const Duration(days: 1)),
          status: ReminderStatus.active,
          title: 'Check soil',
          source: ReminderSource.userCreated,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.lastUserId, 'user-1');
      expect(scheduler.lastPlantNames, {'plant-1': 'Pothos'});
      expect(scheduler.lastReminders.single.id, 'reminder-1');

      session.emitAuthState(const AppUser(uid: 'user-2', email: null));
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.clearedUsers, ['user-1']);
      expect(reminders.watchCalls, 2);
      expect(plants.watchCalls, 2);
    },
  );
}

final class _ReminderRepository implements ReminderRepository {
  final _controller = StreamController<List<Reminder>>.broadcast(sync: true);
  var watchCalls = 0;

  @override
  Stream<List<Reminder>> watchAll() {
    watchCalls++;
    return _controller.stream;
  }

  void emit(List<Reminder> reminders) => _controller.add(reminders);

  Future<void> close() => _controller.close();

  @override
  Future<String> create(Reminder reminder) => throw UnimplementedError();

  @override
  Future<void> setStatus(
    String plantId,
    String reminderId,
    ReminderStatus status, {
    DateTime? dueAt,
  }) => throw UnimplementedError();

  @override
  Stream<List<Reminder>> watchForPlant(String plantId) =>
      throw UnimplementedError();

  @override
  Stream<Reminder?> watchOne(String plantId, String reminderId) =>
      throw UnimplementedError();
}

final class _PlantRepository implements PlantRepository {
  final _controller = StreamController<List<Plant>>.broadcast(sync: true);
  var watchCalls = 0;

  @override
  Stream<List<Plant>> watchPlants() {
    watchCalls++;
    return _controller.stream;
  }

  void emit(List<Plant> plants) => _controller.add(plants);

  Future<void> close() => _controller.close();

  @override
  Future<String> addPlant(PlantDraft plant) => throw UnimplementedError();

  @override
  Future<void> deletePlant(String plantId) => throw UnimplementedError();

  @override
  Future<void> updatePlant(String plantId, PlantDraft plant) =>
      throw UnimplementedError();

  @override
  Stream<Plant?> watchPlant(String plantId) => throw UnimplementedError();
}

final class _RecordingScheduler implements NotificationScheduler {
  var initializeCalls = 0;
  final clearedUsers = <String>[];
  String? lastUserId;
  List<Reminder> lastReminders = const [];
  Map<String, String> lastPlantNames = const {};

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<void> clearUser(String userId) async => clearedUsers.add(userId);

  @override
  Future<void> reconcile({
    required String userId,
    required List<Reminder> reminders,
    required Map<String, String> plantNames,
    required DateTime now,
  }) async {
    lastUserId = userId;
    lastReminders = reminders;
    lastPlantNames = plantNames;
  }

  @override
  Future<void> cancel({required String userId, required String reminderId}) =>
      throw UnimplementedError();

  @override
  Future<NotificationPermission> checkPermission() =>
      throw UnimplementedError();

  @override
  Stream<String> get notificationTapPayloads => const Stream.empty();

  @override
  Future<NotificationPermission> requestPermission() =>
      throw UnimplementedError();

  @override
  Future<void> schedule({
    required String userId,
    required Reminder reminder,
    required String plantName,
  }) => throw UnimplementedError();
}
