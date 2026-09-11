import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:plantcare_domain/authentication.dart';
import 'package:plantcare_domain/local_plant_images.dart';

@lazySingleton
final class LocalPlantImageLifecycleService with WidgetsBindingObserver {
  LocalPlantImageLifecycleService(this._session, this._images);

  final AuthenticationSession _session;
  final LocalPlantImageRepository _images;
  StreamSubscription<AppUser?>? _authSubscription;

  Future<void> start() async {
    if (_authSubscription != null) return;
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _session.authStateChanges.listen((user) {
      if (user != null) unawaited(_cleanup());
    });
    if (_session.currentUser != null) await _cleanup();
  }

  Future<void> _cleanup() async {
    try {
      await _images.cleanup();
    } on LocalPlantImageFailure {
      // Cleanup is best effort; normal image reads still self-heal missing files.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _session.currentUser != null) {
      unawaited(_cleanup());
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _authSubscription?.cancel();
    _authSubscription = null;
  }
}
