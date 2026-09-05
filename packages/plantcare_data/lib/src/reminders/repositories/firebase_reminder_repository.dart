import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_data/src/core/data_limits.dart';
import 'package:plantcare_data/src/reminders/models/reminder_codec.dart';
import 'package:plantcare_domain/reminders.dart';

@LazySingleton(as: ReminderRepository)
final class FirebaseReminderRepository implements ReminderRepository {
  const FirebaseReminderRepository(this._firestore, this._auth);
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid =>
      _auth.currentUser?.uid ?? (throw StateError('Sign in to use reminders.'));
  CollectionReference<Map<String, dynamic>> _plants() =>
      _firestore.collection('users').doc(_uid).collection('plants');
  CollectionReference<Map<String, dynamic>> _items(String plantId) =>
      _plants().doc(plantId).collection('reminders');

  @override
  Stream<List<Reminder>> watchAll() {
    late StreamController<List<Reminder>> controller;
    StreamSubscription? plantsSubscription;
    final reminderSubscriptions = <String, StreamSubscription>{};
    final byPlant = <String, List<Reminder>>{};
    void emitAll() {
      final items = byPlant.values.expand((items) => items).toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      controller.add(List.unmodifiable(items));
    }

    controller = StreamController<List<Reminder>>(
      onListen: () {
        plantsSubscription = _plants()
            .limit(DataLimits.maxPlantsPerUser)
            .snapshots()
            .listen((snapshot) {
              final ids = snapshot.docs.map((doc) => doc.id).toSet();
              for (final removed
                  in reminderSubscriptions.keys
                      .where((id) => !ids.contains(id))
                      .toList()) {
                reminderSubscriptions.remove(removed)?.cancel();
                byPlant.remove(removed);
              }
              for (final id in ids.where(
                (id) => !reminderSubscriptions.containsKey(id),
              )) {
                reminderSubscriptions[id] = watchForPlant(id).listen((items) {
                  byPlant[id] = items;
                  emitAll();
                }, onError: controller.addError);
              }
              emitAll();
            }, onError: controller.addError);
      },
      onCancel: () async {
        await plantsSubscription?.cancel();
        for (final subscription in reminderSubscriptions.values) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  @override
  Stream<List<Reminder>> watchForPlant(String plantId) =>
      _items(plantId)
          .orderBy('dueAt')
          .limit(DataLimits.maxRemindersPerPlant)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => ReminderCodec.fromFirestore(plantId, doc))
                .toList(growable: false),
          );

  @override
  Stream<Reminder?> watchOne(String plantId, String reminderId) =>
      _items(plantId)
          .doc(reminderId)
          .snapshots()
          .map(
            (doc) =>
                doc.exists ? ReminderCodec.fromFirestore(plantId, doc) : null,
          );

  @override
  Future<String> create(Reminder reminder) async {
    final plant = _plants().doc(reminder.plantId);
    if (!(await plant.get()).exists) throw StateError('Plant not found.');
    if (reminder.soilCheckId != null &&
        !(await plant.collection('soilChecks').doc(reminder.soilCheckId).get())
            .exists) {
      throw StateError('Soil check not found.');
    }
    if (reminder.fertilizerAssessmentId != null &&
        !(await plant
                .collection('fertilizerAssessments')
                .doc(reminder.fertilizerAssessmentId)
                .get())
            .exists) {
      throw StateError('Fertilizer assessment not found.');
    }
    return (await _items(reminder.plantId)
            .add(ReminderCodec.toCreate(reminder)))
        .id;
  }

  @override
  Future<void> setStatus(
    String plantId,
    String reminderId,
    ReminderStatus status, {
    DateTime? dueAt,
  }) async {
    await _items(plantId).doc(reminderId).update({
      'status': status.value,
      if (dueAt != null) 'dueAt': Timestamp.fromDate(dueAt.toUtc()),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
