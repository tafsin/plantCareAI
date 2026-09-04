import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/theme/app_theme.dart';
import 'package:plantcare_ai/app/theme/theme_bloc.dart';
import 'package:plantcare_ai/core/constants/app_constants.dart';
import 'package:plantcare_ai/core/utils/environment_config.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/auth_session_bloc.dart';
import 'package:plantcare_ai/features/authentication/presentation/pages/auth_loading_page.dart';

class PlantCareApp extends StatelessWidget {
  const PlantCareApp({
    required this.router,
    required this.themeBloc,
    required this.authSessionBloc,
    required this.environmentConfig,
    super.key,
  });

  final GoRouter router;
  final ThemeBloc themeBloc;
  final AuthSessionBloc authSessionBloc;
  final EnvironmentConfig environmentConfig;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: themeBloc),
        BlocProvider.value(value: authSessionBloc),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: !environmentConfig.isProduction,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeState.themeMode,
            routerConfig: router,
            builder: (context, child) {
              return BlocBuilder<AuthSessionBloc, AuthSessionState>(
                builder: (context, sessionState) {
                  if (sessionState is AuthSessionChecking) {
                    return const AuthLoadingPage();
                  }
                  return child ?? const SizedBox.shrink();
                },
              );
            },
          );
        },
      ),
    );
  }
}
