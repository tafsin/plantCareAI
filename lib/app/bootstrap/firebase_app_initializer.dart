import 'package:firebase_core/firebase_core.dart';
import 'package:plantcare_ai/app/bootstrap/app_initializer.dart';

typedef InitializeFirebase = Future<void> Function(FirebaseOptions options);
typedef FirebaseBootstrapStep = Future<void> Function();

final class FirebaseAppInitializer implements AppInitializer {
  FirebaseAppInitializer({
    required this.options,
    InitializeFirebase? initializeFirebase,
    this.configureEmulators,
    this.activateAppCheck,
    this.startApplicationServices,
  }) : _initializeFirebase = initializeFirebase ?? _initializeFirebaseApp;

  final FirebaseOptions options;
  final InitializeFirebase _initializeFirebase;
  final FirebaseBootstrapStep? configureEmulators;
  final FirebaseBootstrapStep? activateAppCheck;
  final FirebaseBootstrapStep? startApplicationServices;

  Future<void>? _initialization;
  var _isInitialized = false;
  var _isFirebaseInitialized = false;
  var _areEmulatorsConfigured = false;
  var _isAppCheckActivated = false;
  var _areApplicationServicesStarted = false;

  @override
  Future<void> initialize() {
    if (_isInitialized) {
      return Future.value();
    }

    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (!_isFirebaseInitialized) {
        await _initializeFirebase(options);
        _isFirebaseInitialized = true;
      }
      if (!_areEmulatorsConfigured) {
        await configureEmulators?.call();
        _areEmulatorsConfigured = true;
      }
      if (!_isAppCheckActivated) {
        await activateAppCheck?.call();
        _isAppCheckActivated = true;
      }
      if (!_areApplicationServicesStarted) {
        await startApplicationServices?.call();
        _areApplicationServicesStarted = true;
      }
      _isInitialized = true;
    } finally {
      if (!_isInitialized) {
        _initialization = null;
      }
    }
  }

  static Future<void> _initializeFirebaseApp(FirebaseOptions options) async {
    await Firebase.initializeApp(options: options);
  }
}
