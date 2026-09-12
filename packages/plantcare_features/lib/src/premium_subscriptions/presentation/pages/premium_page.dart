import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';

import '../bloc/paywall_bloc.dart';
import '../bloc/premium_access_bloc.dart';

class PremiumPage extends StatelessWidget {
  const PremiumPage({this.returnTo, super.key});

  final String? returnTo;

  static const _freeBenefits = [
    'Up to 3 saved plants',
    'AI and care features included',
  ];
  static const _premiumBenefits = [
    'Unlimited saved plants',
    'Everything in Free',
  ];

  @override
  Widget build(BuildContext context) {
    final access = context.watch<PremiumAccessBloc>().state.snapshot;
    return BlocListener<PremiumAccessBloc, PremiumAccessState>(
      listenWhen: (previous, current) =>
          !previous.snapshot.isActive && current.snapshot.isActive,
      listener: (context, state) {
        if (returnTo case final destination?) context.go(destination);
      },
      child: BlocBuilder<PaywallBloc, PaywallState>(
        builder: (context, state) => ListView(
          key: const ValueKey('premium-page'),
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      access.isActive
                          ? 'Premium is active'
                          : 'PlantCare Premium',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Premium unlocks unlimited saved plants. AI and care features remain available on the Free plan.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cards = [
                          const _PlanCard(
                            title: 'Free',
                            icon: Icons.eco_outlined,
                            benefits: _freeBenefits,
                          ),
                          const _PlanCard(
                            title: 'Premium',
                            icon: Icons.workspace_premium_outlined,
                            benefits: _premiumBenefits,
                            emphasized: true,
                          ),
                        ];
                        if (constraints.maxWidth < 700) {
                          return Column(
                            children: [
                              cards.first,
                              const SizedBox(height: 16),
                              cards.last,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: cards.first),
                            const SizedBox(width: 16),
                            Expanded(child: cards.last),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _PurchasePanel(state: state, access: access),
                    const SizedBox(height: 12),
                    _SecondaryActions(state: state),
                    if (access.warningMessage case final warning?) ...[
                      const SizedBox(height: 12),
                      _StatusCard(icon: Icons.info_outline, message: warning),
                    ],
                    const SizedBox(height: 8),
                    _LegalActions(state: state),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.icon,
    required this.benefits,
    this.emphasized = false,
  });

  final String title;
  final IconData icon;
  final List<String> benefits;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$title plan',
    child: Card(
      color: emphasized ? Theme.of(context).colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, semanticLabel: '$title plan'),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final benefit in benefits)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(benefit)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _PurchasePanel extends StatelessWidget {
  const _PurchasePanel({required this.state, required this.access});

  final PaywallState state;
  final PremiumAccessSnapshot access;

  @override
  Widget build(BuildContext context) {
    if (state.platform == PurchasePlatform.web) {
      return const _StatusCard(
        key: ValueKey('web-purchasing-unavailable'),
        icon: Icons.phone_android,
        message: 'Mobile purchasing is not currently available on web.',
      );
    }
    if (state.platform != PurchasePlatform.android) {
      return const _StatusCard(
        key: ValueKey('ios-purchasing-unavailable'),
        icon: Icons.phone_android,
        message: 'Premium purchasing is currently available on Android.',
      );
    }
    final offer = state.offer;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (offer != null) ...[
              Text(
                '${offer.localizedPrice} / ${offer.billingPeriod}',
                key: const ValueKey('localized-offer'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
            ],
            if (state.isBusy)
              Semantics(
                label: 'Premium operation in progress',
                liveRegion: true,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: CircularProgressIndicator(
                    key: ValueKey('premium-progress'),
                  ),
                ),
              ),
            if (state.message case final message?) ...[
              Text(
                message,
                key: const ValueKey('premium-status-message'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            if (state.status == PaywallStatus.paywallUnavailable ||
                state.status == PaywallStatus.productUnavailable ||
                state.status == PaywallStatus.failure)
              OutlinedButton.icon(
                key: const ValueKey('premium-retry'),
                onPressed: state.isBusy
                    ? null
                    : () => context.read<PaywallBloc>().add(
                        const PaywallLoadRequested(),
                      ),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              )
            else if (!access.isActive)
              FilledButton.icon(
                key: const ValueKey('present-premium-flow'),
                onPressed: state.canPurchase
                    ? () => context.read<PaywallBloc>().add(
                        const PaywallPresentRequested(),
                      )
                    : null,
                icon: const Icon(Icons.workspace_premium),
                label: const Text('View Premium'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({required this.state});

  final PaywallState state;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final actions = [
        OutlinedButton(
          key: const ValueKey('restore-purchases'),
          onPressed: state.platform == PurchasePlatform.android && !state.isBusy
              ? () => context.read<PaywallBloc>().add(
                  const PaywallRestoreRequested(),
                )
              : null,
          child: const Text('Restore Purchases'),
        ),
        OutlinedButton(
          key: const ValueKey('manage-subscription'),
          onPressed: state.platform == PurchasePlatform.android && !state.isBusy
              ? () => context.read<PaywallBloc>().add(
                  const PaywallManageRequested(),
                )
              : null,
          child: const Text('Manage Subscription'),
        ),
      ];
      if (constraints.maxWidth < 500) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [actions.first, const SizedBox(height: 8), actions.last],
        );
      }
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: actions,
      );
    },
  );
}

class _LegalActions extends StatelessWidget {
  const _LegalActions({required this.state});

  final PaywallState state;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final actions = [
        TextButton(
          key: const ValueKey('privacy-policy'),
          onPressed: state.hasPrivacyPolicy && !state.isBusy
              ? () => context.read<PaywallBloc>().add(
                  const PaywallPrivacyRequested(),
                )
              : null,
          child: const Text('Privacy Policy'),
        ),
        TextButton(
          key: const ValueKey('terms-of-service'),
          onPressed: state.hasTermsOfService && !state.isBusy
              ? () => context.read<PaywallBloc>().add(
                  const PaywallTermsRequested(),
                )
              : null,
          child: const Text('Terms'),
        ),
      ];
      if (constraints.maxWidth < 500) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: actions,
        );
      }
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        children: actions,
      );
    },
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.message, super.key});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
