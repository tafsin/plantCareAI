import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_features/src/navigation/app_routes.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('Account', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          key: const ValueKey('privacy-data-tile'),
          leading: const Icon(Icons.shield_outlined),
          title: const Text('Privacy and data'),
          subtitle: const Text(
            'Privacy choices, legal information, and account deletion',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(AppRoutes.privacyData),
        ),
      ),
    ],
  );
}
