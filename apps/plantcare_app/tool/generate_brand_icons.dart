import 'dart:io';

Future<void> main() async {
  final result = await Process.start(Platform.resolvedExecutable, const [
    'run',
    'flutter_launcher_icons',
  ], mode: ProcessStartMode.inheritStdio);
  final resultCode = await result.exitCode;
  if (resultCode != 0) exit(resultCode);

  // flutter_launcher_icons 0.14.4 matches every ASSETCATALOG build setting
  // while selecting AppIcon. Restore the unrelated Xcode boolean it touches.
  final project = File('ios/Runner.xcodeproj/project.pbxproj');
  const expected =
      'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;';
  final original = await project.readAsString();
  final corrected = original.replaceAll(
    'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon;',
    expected,
  );
  if (!corrected.contains(expected)) {
    stderr.writeln('Could not verify the Xcode asset-symbol build setting.');
    exitCode = 1;
    return;
  }
  if (corrected != original) await project.writeAsString(corrected);
}
