import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/features/plant_diagnosis/presentation/bloc/diagnosis_details_bloc.dart';
import 'package:plantcare_ai/features/plant_diagnosis/presentation/widgets/diagnosis_result_view.dart';

class DiagnosisDetailsPage extends StatelessWidget {
  const DiagnosisDetailsPage({
    required this.plantId,
    required this.observationId,
    super.key,
  });
  final String plantId;
  final String observationId;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<DiagnosisDetailsBloc, DiagnosisDetailsState>(
        builder: (context, state) => switch (state.status) {
          DiagnosisDetailsStatus.initial || DiagnosisDetailsStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          DiagnosisDetailsStatus.notFound => const Center(
            child: Text('Diagnosis not found.'),
          ),
          DiagnosisDetailsStatus.failure => Center(
            child: Text(state.errorMessage ?? 'Couldn’t load this diagnosis.'),
          ),
          DiagnosisDetailsStatus.loaded => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.go(
                            AppRoutes.diagnosisHistory(plantId, observationId),
                          ),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        Expanded(
                          child: Text(
                            'Saved diagnosis',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DiagnosisResultView(
                      diagnosis: state.item!,
                      sources: state.sources,
                    ),
                  ],
                ),
              ),
            ),
          ),
        },
      );
}
