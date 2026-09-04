import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/features/care_history/domain/entities/care_log.dart';
import 'package:plantcare_ai/features/care_history/domain/services/care_log_validator.dart';
import 'package:plantcare_ai/features/care_history/presentation/bloc/care_log_form_bloc.dart';
import 'package:plantcare_ai/features/care_history/presentation/widgets/care_log_labels.dart';
import 'package:plantcare_ai/features/navigation/presentation/app_routes.dart';

class InvalidCareLogTypePage extends StatelessWidget {
  const InvalidCareLogTypePage({required this.plantId, super.key});
  final String plantId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Log care action')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose either watering or fertilizing.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.careHistory(plantId)),
              child: const Text('Back to care history'),
            ),
          ],
        ),
      ),
    ),
  );
}

class CareLogFormPage extends StatefulWidget {
  const CareLogFormPage({required this.plantId, required this.type, super.key});
  final String plantId;
  final CareLogType type;

  @override
  State<CareLogFormPage> createState() => _CareLogFormPageState();
}

class _CareLogFormPageState extends State<CareLogFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  final _product = TextEditingController();
  final _application = TextEditingController();
  DateTime _occurredAt = DateTime.now();
  WateringMethod _wateringMethod = WateringMethod.top;
  FertilizerForm _fertilizerForm = FertilizerForm.liquid;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    _product.dispose();
    _application.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final watering = widget.type == CareLogType.watering;
    return BlocListener<CareLogFormBloc, CareLogFormState>(
      listenWhen: (before, after) => before.status != after.status,
      listener: (context, state) {
        if (state.status == CareLogFormStatus.success) {
          context.go(AppRoutes.careHistory(widget.plantId));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(watering ? 'Log watering' : 'Log fertilizer'),
        ),
        body: BlocBuilder<CareLogFormBloc, CareLogFormState>(
          builder: (context, state) {
            final submitting = state.status == CareLogFormStatus.submitting;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          watering
                              ? 'Record what you applied. The amount is not a recommended amount.'
                              : 'PlantCare AI is recording your action, not confirming that the product or amount is appropriate.',
                        ),
                        const SizedBox(height: 20),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Occurred date and time'),
                          subtitle: Text(careDateTimeLabel(_occurredAt)),
                          trailing: const Icon(Icons.calendar_month_outlined),
                          onTap: submitting ? null : _pickDateTime,
                        ),
                        const SizedBox(height: 12),
                        if (watering) ...[
                          DropdownButtonFormField<WateringMethod>(
                            initialValue: _wateringMethod,
                            decoration: const InputDecoration(
                              labelText: 'Watering method',
                            ),
                            items: WateringMethod.values
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value.label),
                                  ),
                                )
                                .toList(),
                            onChanged: submitting
                                ? null
                                : (value) => _wateringMethod = value!,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const ValueKey('amount-ml'),
                            controller: _amount,
                            enabled: !submitting,
                            decoration: const InputDecoration(
                              labelText: 'Amount in mL (optional)',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            validator: _amountValidator,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _notes,
                            enabled: !submitting,
                            maxLength: CareLogLimits.notes,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                            ),
                          ),
                        ] else ...[
                          DropdownButtonFormField<FertilizerForm>(
                            initialValue: _fertilizerForm,
                            decoration: const InputDecoration(
                              labelText: 'Fertilizer form',
                            ),
                            items: FertilizerForm.values
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value.label),
                                  ),
                                )
                                .toList(),
                            onChanged: submitting
                                ? null
                                : (value) => _fertilizerForm = value!,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _product,
                            enabled: !submitting,
                            maxLength: CareLogLimits.productName,
                            decoration: const InputDecoration(
                              labelText: 'Product name (optional)',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _application,
                            enabled: !submitting,
                            maxLength: CareLogLimits.applicationNote,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Application note (optional)',
                            ),
                          ),
                        ],
                        if (state.status == CareLogFormStatus.failure) ...[
                          const SizedBox(height: 16),
                          Text(
                            state.errorMessage ??
                                'Couldn\'t save this care log.',
                            key: const ValueKey('care-log-form-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          key: const ValueKey('submit-care-log'),
                          onPressed: submitting ? null : _submit,
                          icon: submitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(submitting ? 'Saving…' : 'Save care log'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _amountValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final amount = double.tryParse(value);
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        amount > CareLogLimits.maxAmountMl) {
      return 'Enter an amount from more than 0 to 100,000 mL.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<CareLogFormBloc>().add(
      CareLogFormSubmitted(
        occurredAt: _occurredAt,
        wateringMethod: widget.type == CareLogType.watering
            ? _wateringMethod
            : null,
        fertilizerForm: widget.type == CareLogType.fertilizing
            ? _fertilizerForm
            : null,
        amountMl: _amount.text.trim().isEmpty
            ? null
            : double.parse(_amount.text.trim()),
        notes: _notes.text,
        productName: _product.text,
        applicationNote: _application.text,
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime.now().subtract(CareLogLimits.oldestAge),
      lastDate: DateTime.now().add(CareLogLimits.futureClockSkew),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null) return;
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }
}
