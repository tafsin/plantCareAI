import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:plantcare_features/src/navigation/app_routes.dart';
import 'package:plantcare_features/src/reminders/presentation/bloc/reminder_form_bloc.dart';
import 'package:plantcare_features/src/reminders/presentation/widgets/reminder_labels.dart';

class ReminderFormPage extends StatefulWidget {
  const ReminderFormPage({required this.plantId, super.key});
  final String plantId;
  @override
  State<ReminderFormPage> createState() => _ReminderFormPageState();
}

class _ReminderFormPageState extends State<ReminderFormPage> {
  late ReminderType _type;
  late DateTime _dueAt;
  final _title = TextEditingController();
  final _note = TextEditingController();
  bool _notifications = false;
  @override
  void initState() {
    super.initState();
    final bloc = context.read<ReminderFormBloc>();
    _type = bloc.source == ReminderSource.fertilizerAssessmentSuggestion
        ? ReminderType.fertilizerReview
        : ReminderType.soilCheck;
    _dueAt = (bloc.suggestedAt ?? DateTime.now().add(const Duration(days: 1)))
        .toLocal();
    _title.text = _type.label;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time != null) {
      setState(
        () => _dueAt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New care reminder')),
    body: BlocConsumer<ReminderFormBloc, ReminderFormState>(
      listener: (context, state) {
        if (state.status == ReminderFormStatus.savedAndScheduled ||
            state.status == ReminderFormStatus.savedInAppOnly) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.status == ReminderFormStatus.savedAndScheduled
                    ? 'Reminder saved and scheduled on this device.'
                    : state.errorMessage ??
                          'Reminder saved. It will appear in PlantCare AI.',
              ),
            ),
          );
          context.go(AppRoutes.reminders);
        } else if (state.status == ReminderFormStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Couldn’t save reminder.'),
            ),
          );
        }
      },
      builder: (context, state) {
        final busy = state.status == ReminderFormStatus.submitting;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Review and confirm',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Suggested times are never scheduled automatically. You can adjust this time before saving.',
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<ReminderType>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Reminder type',
                      border: OutlineInputBorder(),
                    ),
                    items: ReminderType.values
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.label)),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            _type = v!;
                            _title.text = v.label;
                          }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _title,
                    maxLength: ReminderLimits.title,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Due'),
                    subtitle: Text(_dueAt.toString()),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: busy ? null : _pick,
                  ),
                  TextField(
                    controller: _note,
                    maxLength: ReminderLimits.note,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (!kIsWeb)
                    Card(
                      child: SwitchListTile(
                        value: _notifications,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => _notifications = v),
                        title: const Text('Notify me on this device'),
                        subtitle: const Text(
                          'When you save, PlantCare AI will ask for notification permission. If denied, the reminder remains available in the app.',
                        ),
                      ),
                    )
                  else
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Web reminders appear while you use PlantCare AI. Background notifications are not available in this version.',
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => context.read<ReminderFormBloc>().add(
                            ReminderFormSubmitted(
                              type: _type,
                              dueAt: _dueAt,
                              title: _title.text,
                              note: _note.text,
                              permissionConfirmed: _notifications,
                            ),
                          ),
                    child: busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirm reminder'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
