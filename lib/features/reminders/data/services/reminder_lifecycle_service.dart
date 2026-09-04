import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/features/plants/domain/entities/plant.dart';
import 'package:plantcare_ai/features/plants/domain/repositories/plant_repository.dart';
import 'package:plantcare_ai/features/reminders/domain/entities/reminder.dart';
import 'package:plantcare_ai/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:plantcare_ai/features/reminders/domain/services/notification_scheduler.dart';

@lazySingleton
final class ReminderLifecycleService with WidgetsBindingObserver {
  ReminderLifecycleService(
    this._auth,
    this._reminders,
    this._plants,
    this._scheduler,
  );
  final FirebaseAuth _auth;
  final ReminderRepository _reminders;
  final PlantRepository _plants;
  final NotificationScheduler _scheduler;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<Reminder>>? _reminderSubscription;
  StreamSubscription<List<Plant>>? _plantSubscription;
  String? _userId;
  List<Reminder> _items = const [];
  List<Plant> _plantItems = const [];

  Future<void> start() async {
    if (_authSubscription != null) return;
    WidgetsBinding.instance.addObserver(this);
    await _scheduler.initialize();
    _authSubscription = _auth.userChanges().listen(_userChanged);
    _userChanged(_auth.currentUser);
  }

  void _userChanged(User? user) {
    final previous = _userId;
    if (previous == user?.uid && _reminderSubscription != null) return;
    _reminderSubscription?.cancel();
    _plantSubscription?.cancel();
    _reminderSubscription = null;
    _plantSubscription = null;
    _items = const [];
    _plantItems = const [];
    _userId = user?.uid;
    if (previous != null && previous != user?.uid) {
      unawaited(_scheduler.clearUser(previous));
    }
    if (user == null) return;
    _reminderSubscription = _reminders.watchAll().listen((items) {
      _items = items;
      unawaited(_reconcile());
    });
    _plantSubscription = _plants.watchPlants().listen((items) {
      _plantItems = items;
      unawaited(_reconcile());
    });
  }

  Future<void> _reconcile() async {
    final userId = _userId;
    if (userId == null) return;
    await _scheduler.reconcile(
      userId: userId,
      reminders: _items,
      plantNames: {for (final plant in _plantItems) plant.id: plant.commonName},
      now: DateTime.now(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reconcile());
    }
  }
}
