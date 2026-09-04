import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/features/navigation/presentation/app_routes.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_details_bloc.dart';
import 'package:plantcare_ai/features/plants/presentation/bloc/plant_form_bloc.dart';
import 'package:plantcare_ai/features/plants/presentation/widgets/plant_labels.dart';
import 'package:plantcare_domain/plants.dart';

class PlantFormPage extends StatefulWidget {
  const PlantFormPage({this.initialPlant, super.key});
  final Plant? initialPlant;

  @override
  State<PlantFormPage> createState() => _PlantFormPageState();
}

class _PlantFormPageState extends State<PlantFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _commonNameController;
  late final TextEditingController _scientificNameController;
  late final TextEditingController _potSizeController;
  late final TextEditingController _notesController;
  late PlantEnvironment _environment;
  late GrowingMedium _growingMedium;
  late Sunlight _sunlight;
  late GrowthStage _growthStage;

  @override
  void initState() {
    super.initState();
    final plant = widget.initialPlant;
    _commonNameController = TextEditingController(text: plant?.commonName);
    _scientificNameController = TextEditingController(
      text: plant?.scientificName,
    );
    _potSizeController = TextEditingController(
      text: plant?.potSizeLiters?.toString(),
    );
    _notesController = TextEditingController(text: plant?.notes);
    _environment = plant?.environment ?? PlantEnvironment.indoor;
    _growingMedium = plant?.growingMedium ?? GrowingMedium.pot;
    _sunlight = plant?.sunlight ?? Sunlight.partial;
    _growthStage = plant?.growthStage ?? GrowthStage.vegetative;
  }

  @override
  void dispose() {
    _commonNameController.dispose();
    _scientificNameController.dispose();
    _potSizeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<PlantFormBloc>().add(
      PlantFormSubmitted(
        plantId: widget.initialPlant?.id,
        draft: PlantDraft(
          commonName: _commonNameController.text,
          scientificName: _scientificNameController.text,
          environment: _environment,
          growingMedium: _growingMedium,
          potSizeLiters: _growingMedium == GrowingMedium.pot
              ? double.tryParse(_potSizeController.text.trim())
              : null,
          sunlight: _sunlight,
          growthStage: _growthStage,
          notes: _notesController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialPlant != null;
    return BlocConsumer<PlantFormBloc, PlantFormState>(
      listener: (context, state) {
        if ((state.status == PlantFormStatus.created ||
                state.status == PlantFormStatus.updated) &&
            state.plantId != null) {
          context.go(AppRoutes.plantDetails(state.plantId!));
        }
      },
      builder: (context, state) {
        final submitting = state.status == PlantFormStatus.submitting;
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back to plants',
                          onPressed: submitting
                              ? null
                              : () => context.go(
                                  isEditing
                                      ? AppRoutes.plantDetails(
                                          widget.initialPlant!.id,
                                        )
                                      : AppRoutes.plants,
                                ),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEditing ? 'Edit plant' : 'Add plant',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const ValueKey('plant-common-name'),
                      controller: _commonNameController,
                      enabled: !submitting,
                      textInputAction: TextInputAction.next,
                      maxLength: PlantValidationLimits.commonNameMaxLength,
                      decoration: const InputDecoration(
                        labelText: 'Common name',
                        border: OutlineInputBorder(),
                      ),
                      validator: PlantValidator.commonName,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('plant-scientific-name'),
                      controller: _scientificNameController,
                      enabled: !submitting,
                      textInputAction: TextInputAction.next,
                      maxLength: PlantValidationLimits.scientificNameMaxLength,
                      decoration: const InputDecoration(
                        labelText: 'Scientific name (optional)',
                        border: OutlineInputBorder(),
                      ),
                      validator: PlantValidator.scientificName,
                    ),
                    const SizedBox(height: 12),
                    _EnumDropdown<PlantEnvironment>(
                      fieldKey: const ValueKey('plant-environment'),
                      label: 'Environment',
                      value: _environment,
                      values: PlantEnvironment.values,
                      itemLabel: (value) => value.label,
                      enabled: !submitting,
                      onChanged: (value) =>
                          setState(() => _environment = value),
                    ),
                    const SizedBox(height: 20),
                    _EnumDropdown<GrowingMedium>(
                      fieldKey: const ValueKey('plant-growing-medium'),
                      label: 'Growing medium',
                      value: _growingMedium,
                      values: GrowingMedium.values,
                      itemLabel: (value) => value.label,
                      enabled: !submitting,
                      onChanged: (value) {
                        setState(() {
                          _growingMedium = value;
                          if (value == GrowingMedium.ground) {
                            _potSizeController.clear();
                          }
                        });
                      },
                    ),
                    if (_growingMedium == GrowingMedium.pot) ...[
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const ValueKey('plant-pot-size'),
                        controller: _potSizeController,
                        enabled: !submitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Pot size in liters (optional)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            PlantValidator.potSize(value, _growingMedium),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _EnumDropdown<Sunlight>(
                      fieldKey: const ValueKey('plant-sunlight'),
                      label: 'Sunlight',
                      value: _sunlight,
                      values: Sunlight.values,
                      itemLabel: (value) => value.label,
                      enabled: !submitting,
                      onChanged: (value) => setState(() => _sunlight = value),
                    ),
                    const SizedBox(height: 20),
                    _EnumDropdown<GrowthStage>(
                      fieldKey: const ValueKey('plant-growth-stage'),
                      label: 'Growth stage',
                      value: _growthStage,
                      values: GrowthStage.values,
                      itemLabel: (value) => value.label,
                      enabled: !submitting,
                      onChanged: (value) =>
                          setState(() => _growthStage = value),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const ValueKey('plant-notes'),
                      controller: _notesController,
                      enabled: !submitting,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: PlantValidationLimits.notesMaxLength,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: PlantValidator.notes,
                    ),
                    if (state.status == PlantFormStatus.failure) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          state.errorMessage ?? 'Couldn\'t save this plant.',
                          key: const ValueKey('plant-form-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const ValueKey('plant-form-submit'),
                      onPressed: submitting ? null : _submit,
                      child: submitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEditing ? 'Save changes' : 'Add plant'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class EditPlantPage extends StatelessWidget {
  const EditPlantPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlantDetailsBloc, PlantDetailsState>(
      builder: (context, state) => switch (state.status) {
        PlantDetailsStatus.initial || PlantDetailsStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        PlantDetailsStatus.notFound => const Center(
          child: Text('Plant not found.'),
        ),
        PlantDetailsStatus.failure => Center(
          child: Text(state.errorMessage ?? 'Couldn\'t load this plant.'),
        ),
        PlantDetailsStatus.loaded => PlantFormPage(
          key: ValueKey('edit-${state.plant!.id}'),
          initialPlant: state.plant,
        ),
      },
    );
  }
}

class _EnumDropdown<T> extends StatelessWidget {
  const _EnumDropdown({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.enabled,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final T value;
  final List<T> values;
  final String Function(T) itemLabel;
  final bool enabled;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: fieldKey,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: values
          .map(
            (value) => DropdownMenuItem<T>(
              value: value,
              child: Text(itemLabel(value)),
            ),
          )
          .toList(),
      onChanged: enabled
          ? (value) {
              if (value != null) onChanged(value);
            }
          : null,
    );
  }
}
