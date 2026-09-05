import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_app/core/constants/app_constants.dart';
import 'package:plantcare_features/authentication.dart';
import 'package:plantcare_features/navigation.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  int get _selectedIndex => location.startsWith(AppRoutes.reminders)
      ? 2
      : location.startsWith(AppRoutes.plants)
      ? 1
      : 0;

  void _navigate(BuildContext context, int index) {
    context.go(switch (index) {
      0 => AppRoutes.home,
      1 => AppRoutes.plants,
      _ => AppRoutes.reminders,
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthSessionBloc, AuthSessionState>(
      listenWhen: (previous, current) {
        return previous is AuthSessionAuthenticated &&
            current is AuthSessionAuthenticated &&
            current.logoutFailureCount > previous.logoutFailureCount;
      },
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Couldn\'t sign out. Please try again.'),
            ),
          );
      },
      builder: (context, sessionState) {
        final isLoggingOut =
            sessionState is AuthSessionAuthenticated &&
            sessionState.isLoggingOut;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide =
                constraints.maxWidth >= AppConstants.wideLayoutBreakpoint;
            final title = switch (_selectedIndex) {
              0 when location == AppRoutes.privacySafety => 'Privacy & Safety',
              0 => 'Home',
              1 => 'My Plants',
              _ => 'Reminders',
            };

            return Scaffold(
              appBar: AppBar(
                title: Text(title),
                actions: [
                  IconButton(
                    key: const ValueKey('privacy-safety-button'),
                    tooltip: 'Privacy and safety',
                    onPressed: () => context.go(AppRoutes.privacySafety),
                    icon: const Icon(Icons.info_outline),
                  ),
                  IconButton(
                    key: const ValueKey('logout-button'),
                    tooltip: 'Sign out',
                    onPressed: isLoggingOut
                        ? null
                        : () => context.read<AuthSessionBloc>().add(
                            const AuthSessionLogoutRequested(),
                          ),
                    icon: isLoggingOut
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout),
                  ),
                ],
              ),
              body: Row(
                children: [
                  if (isWide) ...[
                    NavigationRail(
                      key: const ValueKey('wide-navigation'),
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) =>
                          _navigate(context, index),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: Text('Home'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.local_florist_outlined),
                          selectedIcon: Icon(Icons.local_florist),
                          label: Text('My Plants'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.notifications_outlined),
                          selectedIcon: Icon(Icons.notifications),
                          label: Text('Reminders'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                  ],
                  Expanded(child: child),
                ],
              ),
              bottomNavigationBar: isWide
                  ? null
                  : NavigationBar(
                      key: const ValueKey('narrow-navigation'),
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) =>
                          _navigate(context, index),
                      destinations: const [
                        NavigationDestination(
                          key: ValueKey('home-destination'),
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          key: ValueKey('plants-destination'),
                          icon: Icon(Icons.local_florist_outlined),
                          selectedIcon: Icon(Icons.local_florist),
                          label: 'My Plants',
                        ),
                        NavigationDestination(
                          key: ValueKey('reminders-destination'),
                          icon: Icon(Icons.notifications_outlined),
                          selectedIcon: Icon(Icons.notifications),
                          label: 'Reminders',
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}
