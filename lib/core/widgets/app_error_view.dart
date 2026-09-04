import 'package:flutter/material.dart';
import 'package:plantcare_shared/errors.dart';

class AppErrorView extends StatelessWidget {
  const AppErrorView({required this.error, this.onRetry, super.key});

  final AppError error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                error.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
