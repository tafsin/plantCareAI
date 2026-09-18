import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_features/src/account_management/presentation/bloc/account_deletion_bloc.dart';
import 'package:plantcare_features/src/navigation/app_routes.dart';

class PrivacyDataPage extends StatelessWidget {
  const PrivacyDataPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Privacy and data',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      BlocBuilder<AccountDeletionBloc, AccountDeletionState>(
        builder: (context, state) => Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.policy_outlined),
                title: const Text('Privacy Policy'),
                subtitle: state.hasPrivacyPolicy
                    ? null
                    : const Text('Link is not configured.'),
                onTap: state.hasPrivacyPolicy
                    ? () => context.read<AccountDeletionBloc>().add(
                        const AccountDeletionDestinationRequested(
                          AccountDeletionDestination.privacy,
                        ),
                      )
                    : null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Service'),
                subtitle: state.hasTermsOfService
                    ? null
                    : const Text('Link is not configured.'),
                onTap: state.hasTermsOfService
                    ? () => context.read<AccountDeletionBloc>().add(
                        const AccountDeletionDestinationRequested(
                          AccountDeletionDestination.terms,
                        ),
                      )
                    : null,
              ),
              const Divider(height: 1),
              ListTile(
                key: const ValueKey('delete-account-data-tile'),
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Delete account and data'),
                subtitle: const Text('Permanently delete your PlantCare data'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(AppRoutes.accountDeletion),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
