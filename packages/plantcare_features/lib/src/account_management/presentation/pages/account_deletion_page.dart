import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plantcare_domain/account_management.dart';
import 'package:plantcare_features/src/account_management/presentation/bloc/account_deletion_bloc.dart';

class PublicAccountDeletionPage extends StatefulWidget {
  const PublicAccountDeletionPage({
    required this.isAuthenticated,
    required this.signIn,
    required this.deletion,
    super.key,
  });

  final bool isAuthenticated;
  final Widget signIn;
  final Widget deletion;

  @override
  State<PublicAccountDeletionPage> createState() =>
      _PublicAccountDeletionPageState();
}

class _PublicAccountDeletionPageState extends State<PublicAccountDeletionPage> {
  var _showSignIn = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PlantCare AI account deletion')),
    body: SafeArea(
      child: BlocBuilder<AccountDeletionBloc, AccountDeletionState>(
        builder: (context, state) {
          if (state.stage == AccountDeletionStage.complete) {
            return Center(
              child: Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Account deletion complete',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your PlantCare AI account and application data were deleted. You are now signed out.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (widget.isAuthenticated) return widget.deletion;
          if (_showSignIn) {
            return Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showSignIn = false),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to deletion information'),
                  ),
                ),
                Expanded(child: widget.signIn),
              ],
            );
          }
          return ListView(
            key: const ValueKey('public-account-deletion-scroll'),
            padding: const EdgeInsets.all(24),
            children: [
              const _DeletionPolicyDisclosure(),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('public-deletion-sign-in'),
                onPressed: () => setState(() => _showSignIn = true),
                icon: const Icon(Icons.login),
                label: const Text('Sign in to delete my account'),
              ),
              const SizedBox(height: 12),
              const Text(
                'You may instead start an ownership-verification request with support. Support will acknowledge the request promptly without confirming whether an account exists. Never send credentials or payment details.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: state.hasSupportEmail
                    ? () => context.read<AccountDeletionBloc>().add(
                        const AccountDeletionDestinationRequested(
                          AccountDeletionDestination.support,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.email_outlined),
                label: Text(
                  state.hasSupportEmail
                      ? 'Start a support request'
                      : 'Support email is not configured',
                ),
              ),
              if (state.supportEmail case final email?) ...[
                const SizedBox(height: 8),
                Semantics(
                  label: 'Account deletion support email address: $email',
                  child: SelectableText(
                    email,
                    key: const ValueKey('account-deletion-support-address'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: state.hasPrivacyPolicy
                        ? () => context.read<AccountDeletionBloc>().add(
                            const AccountDeletionDestinationRequested(
                              AccountDeletionDestination.privacy,
                            ),
                          )
                        : null,
                    child: Text(
                      state.hasPrivacyPolicy
                          ? 'Privacy Policy'
                          : 'Privacy Policy unavailable',
                    ),
                  ),
                  TextButton(
                    onPressed: state.hasTermsOfService
                        ? () => context.read<AccountDeletionBloc>().add(
                            const AccountDeletionDestinationRequested(
                              AccountDeletionDestination.terms,
                            ),
                          )
                        : null,
                    child: Text(
                      state.hasTermsOfService
                          ? 'Terms of Service'
                          : 'Terms unavailable',
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({this.showPublicHeading = false, super.key});

  final bool showPublicHeading;

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  final _confirmationController = TextEditingController();
  final _passwordController = TextEditingController();
  var _acknowledged = false;
  var _obscurePassword = true;
  AccountReauthenticationMethod? _method;

  @override
  void initState() {
    super.initState();
    context.read<AccountDeletionBloc>().add(const AccountDeletionPrepared());
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<AccountDeletionBloc, AccountDeletionState>(
    listenWhen: (previous, current) => previous.methods != current.methods,
    listener: (context, state) {
      if (_method == null && state.methods.isNotEmpty) {
        setState(() => _method = state.methods.first);
      }
    },
    builder: (context, state) {
      final canSubmit =
          !state.isBusy &&
          state.stage != AccountDeletionStage.complete &&
          _acknowledged &&
          _confirmationController.text == 'DELETE' &&
          _method != null;
      return ListView(
        key: const ValueKey('account-deletion-page'),
        padding: const EdgeInsets.all(24),
        children: [
          if (widget.showPublicHeading)
            Text(
              'Delete account and data',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          if (widget.showPublicHeading) const SizedBox(height: 16),
          const _DeletionPolicyDisclosure(),
          const SizedBox(height: 20),
          _SubscriptionWarning(
            active: state.premiumIsActive,
            acknowledged: _acknowledged,
            enabled: !state.isBusy,
            onChanged: (value) => setState(() => _acknowledged = value),
            onManage: () => context.read<AccountDeletionBloc>().add(
              const AccountDeletionDestinationRequested(
                AccountDeletionDestination.subscriptions,
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('deletion-confirmation-field'),
            controller: _confirmationController,
            enabled: !state.isBusy,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
              helperText: 'This is case-sensitive and must have no spaces.',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (state.methods.length > 1) ...[
            Text(
              'Verify with a linked sign-in method',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IgnorePointer(
              ignoring: state.isBusy,
              child: RadioGroup<AccountReauthenticationMethod>(
                groupValue: _method,
                onChanged: (value) => setState(() => _method = value),
                child: Column(
                  children: [
                    for (final method in state.methods)
                      RadioListTile<AccountReauthenticationMethod>(
                        value: method,
                        title: Text(
                          method == AccountReauthenticationMethod.password
                              ? 'Email and current password'
                              : 'Google',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (_method == AccountReauthenticationMethod.password) ...[
            TextField(
              key: const ValueKey('deletion-password-field'),
              controller: _passwordController,
              enabled: !state.isBusy,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Current password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: state.isBusy
                      ? null
                      : () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_method == AccountReauthenticationMethod.google)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Google will ask you to verify the linked account. PlantCare AI never asks for your Google password.',
              ),
            ),
          if (state.message case final message?) ...[
            Semantics(
              liveRegion: true,
              child: Card(
                color: state.stage == AccountDeletionStage.complete
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(message),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (state.isBusy) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              label: _stageLabel(state.stage),
              child: Text(_stageLabel(state.stage)),
            ),
            const SizedBox(height: 16),
          ],
          if (state.stage == AccountDeletionStage.incomplete)
            FilledButton.tonal(
              key: const ValueKey('retry-account-deletion'),
              onPressed: _method == null
                  ? null
                  : () => context.read<AccountDeletionBloc>().add(
                      AccountDeletionRetried(
                        method: _method!,
                        password: _passwordController.text,
                      ),
                    ),
              child: const Text('Retry account deletion'),
            )
          else
            FilledButton(
              key: const ValueKey('delete-account-button'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: canSubmit
                  ? () => context.read<AccountDeletionBloc>().add(
                      AccountDeletionSubmitted(
                        confirmation: _confirmationController.text,
                        subscriptionAcknowledged: _acknowledged,
                        method: _method!,
                        password: _passwordController.text,
                      ),
                    )
                  : null,
              child: const Text('Permanently delete account and data'),
            ),
          if (state.failureType ==
              AccountDeletionFailureType.providerCleanupRequest) ...[
            const SizedBox(height: 12),
            const Text(
              'Adapty cleanup was not queued. No account data was deleted.',
            ),
          ],
          const SizedBox(height: 12),
          if (state.hasSupportEmail)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('contact-deletion-support'),
                  onPressed: () => context.read<AccountDeletionBloc>().add(
                    const AccountDeletionDestinationRequested(
                      AccountDeletionDestination.support,
                    ),
                  ),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Start a support request'),
                ),
                if (state.supportEmail case final email?)
                  Semantics(
                    label: 'Account deletion support email address: $email',
                    child: SelectableText(
                      email,
                      key: const ValueKey('account-deletion-support-address'),
                    ),
                  ),
              ],
            )
          else
            const Text(
              'Account deletion support email is not configured. Please use self-service deletion or try again later.',
            ),
          const SizedBox(height: 8),
          const Text(
            'Support will ask you to verify ownership. Never send passwords, authentication tokens, payment details, or other credentials.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: state.hasPrivacyPolicy
                    ? () => context.read<AccountDeletionBloc>().add(
                        const AccountDeletionDestinationRequested(
                          AccountDeletionDestination.privacy,
                        ),
                      )
                    : null,
                child: Text(
                  state.hasPrivacyPolicy
                      ? 'Privacy Policy'
                      : 'Privacy Policy unavailable',
                ),
              ),
              TextButton(
                onPressed: state.hasTermsOfService
                    ? () => context.read<AccountDeletionBloc>().add(
                        const AccountDeletionDestinationRequested(
                          AccountDeletionDestination.terms,
                        ),
                      )
                    : null,
                child: Text(
                  state.hasTermsOfService
                      ? 'Terms of Service'
                      : 'Terms unavailable',
                ),
              ),
            ],
          ),
        ],
      );
    },
  );

  static String _stageLabel(AccountDeletionStage stage) => switch (stage) {
    AccountDeletionStage.reauthenticating => 'Verifying your account…',
    AccountDeletionStage.recordingProviderCleanup =>
      'Recording provider cleanup request…',
    AccountDeletionStage.deletingRemoteData =>
      'Deleting and verifying account data…',
    AccountDeletionStage.clearingLocalData =>
      'Clearing account data from this device…',
    AccountDeletionStage.deletingAuthentication =>
      'Deleting your sign-in identity…',
    _ => 'Preparing account deletion…',
  };
}

class _SubscriptionWarning extends StatelessWidget {
  const _SubscriptionWarning({
    required this.active,
    required this.acknowledged,
    required this.enabled,
    required this.onChanged,
    required this.onManage,
  });

  final bool active;
  final bool acknowledged;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.tertiaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            active ? 'Active Premium subscription' : 'Subscription reminder',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Deleting your account or uninstalling PlantCare AI does not cancel a Google Play subscription. Cancellation is recommended when relevant, but it is not required to request or complete account deletion.',
          ),
          TextButton(
            onPressed: enabled ? onManage : null,
            child: const Text('Manage Google Play subscriptions'),
          ),
          CheckboxListTile(
            key: const ValueKey('subscription-warning-acknowledgement'),
            contentPadding: EdgeInsets.zero,
            value: acknowledged,
            onChanged: enabled ? (value) => onChanged(value ?? false) : null,
            title: const Text('I understand the subscription warning'),
          ),
        ],
      ),
    ),
  );
}

class _DeletionPolicyDisclosure extends StatelessWidget {
  const _DeletionPolicyDisclosure();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Permanent deletion',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'We acknowledge deletion requests promptly. After ownership is successfully verified, deletion is completed within 30 calendar days.',
      ),
      const SizedBox(height: 12),
      const Text(
        'Deletion permanently removes your Firebase Authentication identity, plants, observations, diagnoses, soil checks, care logs, fertilizer assessments, reminders, account-scoped notification metadata, and account-scoped local images this device can access.',
      ),
      const SizedBox(height: 12),
      const Text(
        'PlantCare retains none of that account or application content after verified deletion. A minimal deletion-support record may be kept for up to 90 days, then permanently purged. If ownership cannot be verified, request correspondence is deleted no later than 30 days after the last verification attempt; you may submit a new request later.',
      ),
      const SizedBox(height: 12),
      const Text(
        'Google Play and Adapty may retain billing, transaction, fraud-prevention, tax, or legally required records under their own policies. These provider-controlled records are not PlantCare application data.',
      ),
      const SizedBox(height: 12),
      const Text(
        'Remote deletion cannot erase files that remain only on another inaccessible device. Clear PlantCare AI application data or uninstall the app on that device to remove them.',
      ),
    ],
  );
}
