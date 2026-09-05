import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_domain/care_history.dart';
import 'package:plantcare_features/src/care_history/presentation/bloc/care_history_bloc.dart';
import 'package:plantcare_features/src/care_history/presentation/widgets/care_log_labels.dart';
import 'package:plantcare_features/src/navigation/app_routes.dart';

class CareHistoryPage extends StatefulWidget {
  const CareHistoryPage({required this.plantId, super.key});
  final String plantId;

  @override
  State<CareHistoryPage> createState() => _CareHistoryPageState();
}

class _CareHistoryPageState extends State<CareHistoryPage> {
  CareLogType? _filter;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Care history')),
    body: BlocBuilder<CareHistoryBloc, CareHistoryState>(
      builder: (context, state) => switch (state.status) {
        CareHistoryStatus.initial || CareHistoryStatus.loading
            when state.logs.isEmpty =>
          const Center(child: CircularProgressIndicator()),
        CareHistoryStatus.failure when state.logs.isEmpty => _Message(
          message: state.errorMessage ?? 'Couldn\'t load care history.',
          onRetry: () => context.read<CareHistoryBloc>().add(
            CareHistoryWatchRequested(widget.plantId),
          ),
        ),
        _ => _loaded(context, state),
      },
    ),
  );

  Widget _loaded(BuildContext context, CareHistoryState state) {
    final logs = state.logs
        .where((log) => _filter == null || log.type == _filter)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              ChoiceChip(
                label: const Text('Watering'),
                selected: _filter == CareLogType.watering,
                onSelected: (_) =>
                    setState(() => _filter = CareLogType.watering),
              ),
              ChoiceChip(
                label: const Text('Fertilizing'),
                selected: _filter == CareLogType.fertilizing,
                onSelected: (_) =>
                    setState(() => _filter = CareLogType.fertilizing),
              ),
            ],
          ),
        ),
        if (state.status == CareHistoryStatus.failure)
          MaterialBanner(
            content: Text(
              state.errorMessage ?? 'Couldn\'t refresh care history.',
            ),
            actions: [
              TextButton(
                onPressed: () => context.read<CareHistoryBloc>().add(
                  CareHistoryWatchRequested(widget.plantId),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        Expanded(
          child: state.logs.isEmpty
              ? const _Message(message: 'No care actions recorded yet.')
              : logs.isEmpty
              ? const _Message(message: 'No care actions match this filter.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _CareLogTile(plantId: widget.plantId, log: logs[index]),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => context.go(
                    AppRoutes.newCareLog(widget.plantId, CareLogType.watering),
                  ),
                  icon: const Icon(Icons.water_drop_outlined),
                  label: const Text('Log watering'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go(
                    AppRoutes.newCareLog(
                      widget.plantId,
                      CareLogType.fertilizing,
                    ),
                  ),
                  icon: const Icon(Icons.eco_outlined),
                  label: const Text('Log fertilizer'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CareLogTile extends StatelessWidget {
  const _CareLogTile({required this.plantId, required this.log});
  final String plantId;
  final CareLog log;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      careDateTimeLabel(log.occurredAt),
      careMethodLabel(log),
      if (log case WateringLog(:final amountMl?)) '${_number(amountMl)} mL',
      if (log case FertilizingLog(:final productName?)) productName,
      if (log.notes case final String notes)
        notes.length > 100 ? '${notes.substring(0, 100)}…' : notes,
    ];
    return Card(
      child: ListTile(
        key: ValueKey('care-log-${log.id}'),
        leading: Icon(
          log is WateringLog ? Icons.water_drop_outlined : Icons.eco_outlined,
        ),
        title: Text(careActionTitle(log)),
        subtitle: Text(
          details.join(' • '),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(AppRoutes.careLogDetails(plantId, log.id)),
      ),
    );
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

class _Message extends StatelessWidget {
  const _Message({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );
}
