import 'package:injectable/injectable.dart';
import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';
import 'package:plantcare_ai/features/care_history/domain/repositories/care_log_repository.dart';
import 'package:plantcare_ai/features/care_history/presentation/bloc/care_history_bloc.dart';
import 'package:plantcare_ai/features/care_history/presentation/bloc/care_log_details_bloc.dart';
import 'package:plantcare_ai/features/care_history/presentation/bloc/care_log_form_bloc.dart';

@lazySingleton
final class CareLogBlocFactory {
  const CareLogBlocFactory(this._repository);
  final CareLogRepository _repository;

  CareHistoryBloc createHistoryBloc() => CareHistoryBloc(_repository);
  CareLogFormBloc createFormBloc(String plantId, CareLogType type) =>
      CareLogFormBloc(_repository, plantId, type);
  CareLogDetailsBloc createDetailsBloc(String plantId, String careLogId) =>
      CareLogDetailsBloc(_repository, plantId, careLogId);
}
