import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_features/src/plants/presentation/bloc/plant_details_bloc.dart';

class CarePlantGuard extends StatelessWidget {
  const CarePlantGuard({required this.plantId, required this.child, super.key});

  final String plantId;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<PlantDetailsBloc, PlantDetailsState>(
        builder: (context, state) => switch (state.status) {
          PlantDetailsStatus.initial || PlantDetailsStatus.loading =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
          PlantDetailsStatus.notFound => const Scaffold(
            body: Center(child: Text('Plant not found.')),
          ),
          PlantDetailsStatus.failure => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.errorMessage ?? 'Couldn\'t load this plant.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.read<PlantDetailsBloc>().add(
                      PlantDetailsWatchRequested(plantId),
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
          PlantDetailsStatus.loaded => child,
        },
      );
}
