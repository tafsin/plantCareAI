import 'package:flutter/material.dart';
import 'package:plantcare_app/core/constants/app_constants.dart';
import 'package:plantcare_app/core/constants/brand_assets.dart';

class AppBranding extends StatelessWidget {
  const AppBranding.auth({super.key}) : _compact = false;

  const AppBranding.compact({super.key}) : _compact = true;

  final bool _compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final hasWordmarkWidth = constraints.maxWidth >= 380;
        if (!_compact && !isDark && hasWordmarkWidth) {
          return Semantics(
            key: const ValueKey('brand-wordmark'),
            image: true,
            label: AppConstants.appName,
            child: ExcludeSemantics(
              child: Center(
                child: SizedBox(
                  height: 88,
                  child: Image.asset(
                    BrandAssets.wordmark,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          );
        }

        return Semantics(
          key: ValueKey(_compact ? 'shell-branding' : 'brand-mark-native-text'),
          image: true,
          label: AppConstants.appName,
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: _compact
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: _compact ? 30 : 60,
                  child: Image.asset(
                    BrandAssets.mark,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
                SizedBox(width: _compact ? 8 : 12),
                Flexible(
                  child: Text(
                    AppConstants.appName,
                    maxLines: _compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: _compact
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
