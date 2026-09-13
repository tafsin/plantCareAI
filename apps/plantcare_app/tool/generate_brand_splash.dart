import 'dart:io';

Future<void> main() async {
  final result = await Process.start(Platform.resolvedExecutable, const [
    'run',
    'flutter_native_splash:create',
  ], mode: ProcessStartMode.inheritStdio);
  final resultCode = await result.exitCode;
  if (resultCode != 0) exit(resultCode);

  // The generator currently leaves trailing whitespace in generated web and
  // Android text resources.
  for (final path in const [
    'web/index.html',
    'android/app/src/main/res/values-v31/styles.xml',
    'android/app/src/main/res/values-night-v31/styles.xml',
  ]) {
    await _trimTrailingWhitespace(File(path));
  }
}

Future<void> _trimTrailingWhitespace(File file) async {
  final original = await file.readAsString();
  final normalized = original
      .split('\n')
      .map((line) => line.trimRight())
      .join('\n');
  if (normalized != original) await file.writeAsString(normalized);
}
