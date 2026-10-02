import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_domain/premium_subscriptions.dart';

@lazySingleton
final class PremiumSubscriptionLifecycleService with WidgetsBindingObserver {
  PremiumSubscriptionLifecycleService(this._session, this._subscriptions);

  final AuthenticationSession _session;
  final PremiumSubscriptionRepository _subscriptions;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _session.currentUser != null) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      await _subscriptions.refreshProfile();
    } on Object {
      // The repository preserves the last verified access and publishes a
      // warning. Resume refresh must never interrupt the free application.
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }
}
