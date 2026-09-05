import 'dart:async';

import 'package:plantcare_domain/soil_check.dart';

final class FakeSoilCheckRepository implements SoilCheckRepository {
  final history = StreamController<List<SoilCheckRecord>>.broadcast(sync: true);
  final details = <String, StreamController<SoilCheckRecord?>>{};
  Object? saveError;
  int saveCalls = 0;
  SoilCheckRecord? savedRecord;
  @override
  Future<String> save(String plantId, SoilCheckRecord record) async {
    saveCalls++;
    savedRecord = record;
    if (saveError != null) throw saveError!;
    return 'soil-1';
  }

  @override
  Stream<List<SoilCheckRecord>> watchHistory(String plantId) => history.stream;
  @override
  Stream<SoilCheckRecord?> watchDetails(String plantId, String soilCheckId) =>
      (details[soilCheckId] ??= StreamController<SoilCheckRecord?>.broadcast(
        sync: true,
      )).stream;
  @override
  Future<void> delete(String plantId, String soilCheckId) async {}

  void emitDetail(String id, SoilCheckRecord? item) =>
      (details[id] ??= StreamController<SoilCheckRecord?>.broadcast(
        sync: true,
      )).add(item);
  Future<void> close() async {
    await history.close();
    for (final controller in details.values) {
      await controller.close();
    }
  }
}
