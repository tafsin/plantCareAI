import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_domain/plants.dart';
import 'package:plantcare_domain/reminders.dart';

@lazySingleton
final class ReminderLifecycleService with WidgetsBindingObserver {
  ReminderLifecycleService(
    this._session,
    this._reminders,
    this._plants,
    this._scheduler,
  );

  final AuthenticationSession _session;
  final ReminderRepository _reminders;
  final PlantRepository _plants;
  final NotificationScheduler _scheduler;
  StreamSubscription<AppUser?>? _authSubscription;
  StreamSubscription<List<Reminder>>? _reminderSubscription;
  StreamSubscription<List<Plant>>? _plantSubscription;
  String? _userId;
  List<Reminder> _items = const [];
  List<Plant> _plantItems = const [];

  Future<void> start() async {
    if (_authSubscription != null) return;
    WidgetsBinding.instance.addObserver(this);
    await _scheduler.initialize();
    _authSubscription = _session.authStateChanges.listen(_userChanged);
    _userChanged(_session.currentUser);
  }

  void _userChanged(AppUser? user) {
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
      unawaited(_clearUserSafely(previous));
    }
    if (user == null) return;
    _reminderSubscription = _reminders.watchAll().listen(
      (items) {
        _items = items;
        unawaited(_reconcileSafely());
      },
      onError: (Object error, StackTrace stackTrace) =>
          _reportBackgroundError('watch reminders', error, stackTrace),
    );
    _plantSubscription = _plants.watchPlants().listen(
      (items) {
        _plantItems = items;
        unawaited(_reconcileSafely());
      },
      onError: (Object error, StackTrace stackTrace) =>
          _reportBackgroundError('watch plants', error, stackTrace),
    );
  }

  Future<void> _clearUserSafely(String userId) async {
    try {
      await _scheduler.clearUser(userId);
    } catch (error, stackTrace) {
      _reportBackgroundError('clear notifications', error, stackTrace);
    }
  }

  Future<void> _reconcileSafely() async {
    try {
      await _reconcile();
    } catch (error, stackTrace) {
      _reportBackgroundError('reconcile notifications', error, stackTrace);
    }
  }

  void _reportBackgroundError(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!kDebugMode) return;
    developer.log(
      'Reminder lifecycle failed to $operation',
      name: 'plantcare_ai.reminders',
      error: error,
      stackTrace: stackTrace,
    );
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
      unawaited(_reconcileSafely());
    }
  }
}
