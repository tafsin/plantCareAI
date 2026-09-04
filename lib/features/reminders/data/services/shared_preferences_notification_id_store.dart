import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

@LazySingleton(as: NotificationIdStore)
final class SharedPreferencesNotificationIdStore
    implements NotificationIdStore {
  static const _prefix = 'plantcare.notification_ids.v1.';
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<int> idFor(String userId, String reminderId) async {
    final values = await entries(userId);
    final existing = values[reminderId];
    if (existing != null) return existing;
    final used = values.values.toSet();
    final candidate = allocateNotificationId('$userId:$reminderId', used);
    values[reminderId] = candidate;
    await (await _prefs).setString('$_prefix$userId', jsonEncode(values));
    return candidate;
  }

  @override
  Future<Map<String, int>> entries(String userId) async {
    final encoded = (await _prefs).getString('$_prefix$userId');
    if (encoded == null) return {};
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value as int));
  }

  @override
  Future<void> remove(String userId, String reminderId) async {
    final values = await entries(userId)
      ..remove(reminderId);
    await (await _prefs).setString('$_prefix$userId', jsonEncode(values));
  }

  @override
  Future<void> clear(String userId) async =>
      (await _prefs).remove('$_prefix$userId');
}
