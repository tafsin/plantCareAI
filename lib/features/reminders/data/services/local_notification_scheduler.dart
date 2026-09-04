import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/features/reminders/domain/entities/reminder.dart';
import 'package:plantcare_ai/features/reminders/domain/services/notification_scheduler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

tz.TZDateTime zonedReminderTime(DateTime dueAt, tz.Location location) =>
    tz.TZDateTime.from(dueAt.toUtc(), location);

@LazySingleton(as: NotificationScheduler)
final class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler(this._ids);
  final NotificationIdStore _ids;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  String? _pendingTap;
  bool _initialized = false;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Stream<String> get notificationTapPayloads async* {
    if (_pendingTap case final payload?) {
      _pendingTap = null;
      yield payload;
    }
    yield* _taps.stream;
  }

  @override
  Future<void> initialize() async {
    if (!isSupported) return;
    if (!_initialized) tz_data.initializeTimeZones();
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload case final payload?) _taps.add(payload);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null) {
      _pendingTap = payload;
    }
    _initialized = true;
  }

  @override
  Future<NotificationPermission> checkPermission() async {
    if (!isSupported) return NotificationPermission.unavailable;
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final enabled = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      return enabled == true
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    }
    final settings = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    if (settings?.isEnabled == true) return NotificationPermission.granted;
    return NotificationPermission.denied;
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    if (!isSupported) return NotificationPermission.unavailable;
    await initialize();
    final granted = defaultTargetPlatform == TargetPlatform.android
        ? await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission()
        : await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true);
    return granted == true
        ? NotificationPermission.granted
        : NotificationPermission.denied;
  }

  @override
  Future<void> schedule({
    required String userId,
    required Reminder reminder,
    required String plantName,
  }) async {
    if (!isSupported) return;
    await initialize();
    final id = await _ids.idFor(userId, reminder.id);
    final body = reminder.type == ReminderType.soilCheck
        ? 'Check the soil for $plantName'
        : 'Review fertilizer care for $plantName';
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: zonedReminderTime(reminder.dueAt, tz.local),
      title: 'PlantCare AI reminder',
      body: body,
      payload:
          '/plants/${Uri.encodeComponent(reminder.plantId)}/reminders/${Uri.encodeComponent(reminder.id)}',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'plant_care_reminders',
          'Plant care reminders',
          channelDescription: 'Reminders to check or review plant care.',
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel({
    required String userId,
    required String reminderId,
  }) async {
    if (!isSupported) return;
    final id = (await _ids.entries(userId))[reminderId];
    if (id != null) await _plugin.cancel(id: id);
    await _ids.remove(userId, reminderId);
  }

  @override
  Future<void> reconcile({
    required String userId,
    required List<Reminder> reminders,
    required Map<String, String> plantNames,
    required DateTime now,
  }) async {
    if (!isSupported ||
        await checkPermission() != NotificationPermission.granted) {
      return;
    }
    await initialize();
    final active = futureActiveReminders(reminders, now);
    final known = await _ids.entries(userId);
    for (final reminderId
        in known.keys.where((id) => !active.containsKey(id)).toList()) {
      await cancel(userId: userId, reminderId: reminderId);
    }
    for (final reminder in active.values) {
      await schedule(
        userId: userId,
        reminder: reminder,
        plantName: plantNames[reminder.plantId] ?? 'your plant',
      );
    }
  }

  @override
  Future<void> clearUser(String userId) async {
    if (!isSupported) return;
    for (final id in (await _ids.entries(userId)).values) {
      await _plugin.cancel(id: id);
    }
    await _ids.clear(userId);
  }
}
