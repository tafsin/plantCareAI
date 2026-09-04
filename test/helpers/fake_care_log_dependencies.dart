import 'dart:async';

import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';
import 'package:plantcare_ai/features/care_history/domain/repositories/care_log_repository.dart';

final class FakeCareLogRepository implements CareLogRepository {
  final history = StreamController<List<CareLog>>.broadcast(sync: true);
  final logs = <String, CareLog>{};
  Object? historyError;
  Object? addError;
  Object? deleteError;
  Completer<String>? pendingAdd;
  int wateringAdds = 0;
  int fertilizingAdds = 0;
  int deleteCalls = 0;
  CareLog? addedLog;

  @override
  Stream<List<CareLog>> watchForPlant(String plantId) {
    if (historyError != null) return Stream.error(historyError!);
    return history.stream;
  }

  @override
  Future<CareLog?> getById(String plantId, String careLogId) async =>
      logs[careLogId];

  @override
  Future<String> addWatering(String plantId, WateringLog log) {
    wateringAdds++;
    return _add(log);
  }

  @override
  Future<String> addFertilizing(String plantId, FertilizingLog log) {
    fertilizingAdds++;
    return _add(log);
  }

  Future<String> _add(CareLog log) async {
    addedLog = log;
    if (addError != null) throw addError!;
    if (pendingAdd != null) return pendingAdd!.future;
    return 'care-1';
  }

  @override
  Future<void> delete(String plantId, String careLogId) async {
    deleteCalls++;
    if (deleteError != null) throw deleteError!;
    logs.remove(careLogId);
  }

  Future<void> close() => history.close();
}
