import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/account_management.dart';
import 'package:url_launcher/url_launcher.dart';

@LazySingleton(as: AccountDestinationLauncher)
final class UrlAccountDestinationLauncher
    implements AccountDestinationLauncher {
  const UrlAccountDestinationLauncher(this._configuration);

  final AccountDeletionConfiguration _configuration;

  @override
  bool get hasPrivacyPolicy => _configuration.privacyPolicyUrl != null;

  @override
  bool get hasTermsOfService => _configuration.termsOfServiceUrl != null;

  @override
  bool get hasSupportEmail => _configuration.hasSupportEmail;

  @override
  String? get supportEmail => _configuration.supportEmail;

  @override
  Future<void> openPrivacyPolicy() => _open(
    _configuration.privacyPolicyUrl,
    'Privacy policy is unavailable for this build.',
  );

  @override
  Future<void> openTermsOfService() => _open(
    _configuration.termsOfServiceUrl,
    'Terms are unavailable for this build.',
  );

  @override
  Future<void> openGooglePlaySubscriptions() => _open(
    AccountDeletionConfiguration.googlePlaySubscriptionsUrl,
    'Google Play subscription management could not be opened.',
  );

  @override
  Future<void> openSupportRequest() => _open(
    _configuration.supportMailto,
    'Account deletion support is not configured for this build.',
  );

  Future<void> _open(Uri? uri, String unavailableMessage) async {
    if (uri == null) {
      throw AccountDeletionFailure(
        AccountDeletionFailureType.configuration,
        unavailableMessage,
      );
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw AccountDeletionFailure(
        AccountDeletionFailureType.launch,
        unavailableMessage,
      );
    }
  }
}
