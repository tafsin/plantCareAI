import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/core/errors/app_error.dart';
import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';
import 'package:plantcare_ai/features/care_history/presentation/bloc/care_history_bloc.dart';
import 'package:plantcare_ai/features/care_history/presentation/bloc/care_log_details_bloc.dart';
import 'package:plantcare_ai/features/care_history/presentation/bloc/care_log_form_bloc.dart';

import '../../../helpers/fake_care_log_dependencies.dart';

void main() {
  late FakeCareLogRepository repository;
  setUp(() => repository = FakeCareLogRepository());
  tearDown(() => repository.close());

  blocTest<CareHistoryBloc, CareHistoryState>(
    'history supports loading, empty, loaded, failure, and retry',
    build: () => CareHistoryBloc(repository),
    act: (bloc) async {
      bloc.add(const CareHistoryWatchRequested('plant-1'));
      await _tick();
      repository.history.add(const []);
      await _tick();
      repository.history.add([_watering]);
      await _tick();
      repository.history.addError(Exception('offline'));
      await _tick();
      bloc.add(const CareHistoryWatchRequested('plant-1'));
      await _tick();
      repository.history.add([_watering]);
    },
    verify: (bloc) {
      expect(bloc.state.status, CareHistoryStatus.loaded);
      expect(bloc.state.logs, [_watering]);
    },
  );

  blocTest<CareLogFormBloc, CareLogFormState>(
    'submits watering successfully',
    build: () => CareLogFormBloc(repository, 'plant-1', CareLogType.watering),
    act: (bloc) => bloc.add(
      CareLogFormSubmitted(
        occurredAt: DateTime.now(),
        wateringMethod: WateringMethod.soak,
        amountMl: 300,
        notes: '  Recorded note  ',
      ),
    ),
    verify: (bloc) {
      expect(repository.wateringAdds, 1);
      expect(repository.addedLog, isA<WateringLog>());
      expect(repository.addedLog?.notes, 'Recorded note');
      expect(bloc.state.status, CareLogFormStatus.success);
    },
  );

  blocTest<CareLogFormBloc, CareLogFormState>(
    'submits fertilizer successfully',
    build: () =>
        CareLogFormBloc(repository, 'plant-1', CareLogType.fertilizing),
    act: (bloc) => bloc.add(
      CareLogFormSubmitted(
        occurredAt: DateTime.now(),
        fertilizerForm: FertilizerForm.compost,
        productName: 'Compost',
        applicationNote: 'Surface application',
      ),
    ),
    verify: (bloc) {
      expect(repository.fertilizingAdds, 1);
      expect(repository.addedLog, isA<FertilizingLog>());
      expect(bloc.state.status, CareLogFormStatus.success);
    },
  );

  blocTest<CareLogFormBloc, CareLogFormState>(
    'prevents duplicate submissions while one is pending',
    setUp: () => repository.pendingAdd = Completer<String>(),
    build: () => CareLogFormBloc(repository, 'plant-1', CareLogType.watering),
    act: (bloc) async {
      final event = CareLogFormSubmitted(
        occurredAt: DateTime.now(),
        wateringMethod: WateringMethod.top,
      );
      bloc.add(event);
      bloc.add(event);
      await _tick();
      repository.pendingAdd!.complete('care-1');
    },
    verify: (_) => expect(repository.wateringAdds, 1),
  );

  blocTest<CareLogFormBloc, CareLogFormState>(
    'failed submission retains normalized draft',
    setUp: () => repository.addError = const CareLogFailure(
      CareLogFailureType.network,
      'Offline',
    ),
    build: () =>
        CareLogFormBloc(repository, 'plant-1', CareLogType.fertilizing),
    act: (bloc) => bloc.add(
      CareLogFormSubmitted(
        occurredAt: DateTime.now(),
        fertilizerForm: FertilizerForm.liquid,
        productName: ' Feed ',
      ),
    ),
    verify: (bloc) {
      expect(bloc.state.status, CareLogFormStatus.failure);
      expect((bloc.state.draft! as FertilizingLog).productName, 'Feed');
    },
  );

  blocTest<CareLogDetailsBloc, CareLogDetailsState>(
    'successful deletion completes',
    setUp: () => repository.logs['care-1'] = _watering,
    build: () => CareLogDetailsBloc(repository, 'plant-1', 'care-1'),
    act: (bloc) async {
      bloc.add(const CareLogDetailsRequested());
      await _tick();
      bloc.add(const CareLogDeleteRequested());
    },
    verify: (bloc) {
      expect(repository.deleteCalls, 1);
      expect(bloc.state.status, CareLogDetailsStatus.deleted);
    },
  );

  blocTest<CareLogDetailsBloc, CareLogDetailsState>(
    'failed deletion preserves the record',
    setUp: () {
      repository.logs['care-1'] = _watering;
      repository.deleteError = const CareLogFailure(
        CareLogFailureType.network,
        'Offline',
      );
    },
    build: () => CareLogDetailsBloc(repository, 'plant-1', 'care-1'),
    act: (bloc) async {
      bloc.add(const CareLogDetailsRequested());
      await _tick();
      bloc.add(const CareLogDeleteRequested());
    },
    verify: (bloc) {
      expect(bloc.state.status, CareLogDetailsStatus.failure);
      expect(bloc.state.log, _watering);
    },
  );

  test('form validation rejects missing conditional fields', () async {
    final watering = CareLogFormBloc(
      repository,
      'plant-1',
      CareLogType.watering,
    )..add(CareLogFormSubmitted(occurredAt: DateTime.now()));
    await _tick();
    expect(watering.state.errorMessage, 'Select a watering method.');
    expect(repository.wateringAdds, 0);
    await watering.close();
  });
}

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 5));

final _watering = WateringLog(
  id: 'care-1',
  occurredAt: DateTime.utc(2026, 9, 3),
  wateringMethod: WateringMethod.top,
);
