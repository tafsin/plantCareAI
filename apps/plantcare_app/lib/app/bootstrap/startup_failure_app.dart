import 'package:flutter/material.dart';
import 'package:plantcare_app/app/theme/app_theme.dart';
import 'package:plantcare_app/core/widgets/app_error_view.dart';
import 'package:plantcare_shared/errors.dart';

typedef RetryStartup = Future<bool> Function();

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({required this.onRetry, super.key});

  final RetryStartup onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: _StartupFailurePage(onRetry: onRetry),
    );
  }
}

class _StartupFailurePage extends StatefulWidget {
  const _StartupFailurePage({required this.onRetry});

  final RetryStartup onRetry;

  @override
  State<_StartupFailurePage> createState() => _StartupFailurePageState();
}

class _StartupFailurePageState extends State<_StartupFailurePage> {
  static const _startupError = UnexpectedAppError(
    'PlantCare AI couldn\u2019t start. Check your connection and try again.',
  );

  var _isRetrying = false;

  Future<void> _retry() async {
    setState(() => _isRetrying = true);
    final initialized = await widget.onRetry();
    if (mounted && !initialized) {
      setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isRetrying
            ? const Center(child: CircularProgressIndicator())
            : AppErrorView(error: _startupError, onRetry: _retry),
      ),
    );
  }
}
