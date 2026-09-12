import 'package:equatable/equatable.dart';
import 'package:plantcare_shared/errors.dart';

abstract final class PremiumSubscriptionIds {
  static const accessLevel = 'premium';
  static const placement = 'main_paywall';
  static const product = 'plantcare_premium';
  static const basePlan = 'monthly';
  static const androidPackage = 'com.tasnimalam.plantcare_ai';
}

enum PurchasePlatform { android, ios, web, unsupported }

enum PremiumAccessStatus { checking, inactive, active }

final class PremiumAccessSnapshot extends Equatable {
  const PremiumAccessSnapshot({
    required this.userId,
    required this.status,
    this.warningMessage,
  });

  const PremiumAccessSnapshot.signedOut()
    : userId = null,
      status = PremiumAccessStatus.inactive,
      warningMessage = null;

  final String? userId;
  final PremiumAccessStatus status;
  final String? warningMessage;

  bool get isActive => status == PremiumAccessStatus.active;

  PremiumAccessSnapshot withWarning(String message) => PremiumAccessSnapshot(
    userId: userId,
    status: status,
    warningMessage: message,
  );

  @override
  List<Object?> get props => [userId, status, warningMessage];
}

final class PremiumOffer extends Equatable {
  const PremiumOffer({
    required this.productId,
    required this.basePlanId,
    required this.localizedPrice,
    required this.billingPeriod,
  });

  final String productId;
  final String basePlanId;
  final String localizedPrice;
  final String billingPeriod;

  @override
  List<Object?> get props => [
    productId,
    basePlanId,
    localizedPrice,
    billingPeriod,
  ];
}

enum PaywallAvailability {
  ready,
  unsupported,
  configurationUnavailable,
  paywallUnavailable,
  productUnavailable,
}

final class PaywallPreparation extends Equatable {
  const PaywallPreparation(this.availability, {this.offer, this.message});

  final PaywallAvailability availability;
  final PremiumOffer? offer;
  final String? message;

  bool get canPresent =>
      availability == PaywallAvailability.ready && offer != null;

  @override
  List<Object?> get props => [availability, offer, message];
}

sealed class PaywallEvent extends Equatable {
  const PaywallEvent();

  @override
  List<Object?> get props => [];
}

final class PaywallPurchaseStarted extends PaywallEvent {
  const PaywallPurchaseStarted();
}

final class PaywallPurchasePending extends PaywallEvent {
  const PaywallPurchasePending();
}

final class PaywallPurchaseCancelled extends PaywallEvent {
  const PaywallPurchaseCancelled();
}

final class PaywallPurchaseVerified extends PaywallEvent {
  const PaywallPurchaseVerified();
}

final class PaywallRestoreStarted extends PaywallEvent {
  const PaywallRestoreStarted();
}

final class PaywallRestoreCompleted extends PaywallEvent {
  const PaywallRestoreCompleted({required this.hasPremium});

  final bool hasPremium;

  @override
  List<Object?> get props => [hasPremium];
}

final class PaywallDismissed extends PaywallEvent {
  const PaywallDismissed();
}

final class PaywallOperationFailed extends PaywallEvent {
  const PaywallOperationFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

enum PremiumFailureType {
  configuration,
  notReady,
  unavailable,
  purchase,
  restore,
  launch,
  unsupported,
  unknown,
}

final class PremiumSubscriptionFailure extends AppError {
  const PremiumSubscriptionFailure(this.type, super.message);

  final PremiumFailureType type;

  @override
  List<Object?> get props => [type, message];
}

final class RestorePurchasesResult extends Equatable {
  const RestorePurchasesResult({required this.hasPremium});

  final bool hasPremium;

  @override
  List<Object?> get props => [hasPremium];
}

final class PremiumSubscriptionConfiguration extends Equatable {
  const PremiumSubscriptionConfiguration({
    required this.publicSdkKey,
    required this.privacyPolicyUrl,
    required this.termsOfServiceUrl,
  });

  final String? publicSdkKey;
  final Uri? privacyPolicyUrl;
  final Uri? termsOfServiceUrl;

  bool get canActivate => publicSdkKey?.trim().isNotEmpty ?? false;

  @override
  List<Object?> get props => [
    publicSdkKey,
    privacyPolicyUrl,
    termsOfServiceUrl,
  ];
}

abstract interface class PremiumSubscriptionRepository {
  PurchasePlatform get platform;

  Stream<PremiumAccessSnapshot> get accessChanges;

  Stream<PaywallEvent> get paywallEvents;

  PremiumAccessSnapshot get currentAccess;

  Future<void> initialize();

  Future<PaywallPreparation> preparePaywall();

  Future<void> presentPaywall();

  Future<RestorePurchasesResult> restorePurchases();

  Future<void> refreshProfile();

  Future<void> dispose();
}

abstract interface class PremiumDestinationLauncher {
  bool get hasPrivacyPolicy;

  bool get hasTermsOfService;

  Future<void> openManageSubscription({String? productId});

  Future<void> openPrivacyPolicy();

  Future<void> openTermsOfService();
}
