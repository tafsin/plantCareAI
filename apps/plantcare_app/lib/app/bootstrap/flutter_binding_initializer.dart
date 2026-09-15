import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

typedef BindingInitializer = void Function();

void initializePlantCareFlutterBinding({
  bool isDebugMode = kDebugMode,
  BindingInitializer marionette = _initializeMarionetteBinding,
  BindingInitializer standard = _initializeStandardBinding,
}) {
  if (isDebugMode) {
    marionette();
    return;
  }

  standard();
}

void _initializeMarionetteBinding() {
  MarionetteBinding.ensureInitialized();
}

void _initializeStandardBinding() {
  WidgetsFlutterBinding.ensureInitialized();
}
