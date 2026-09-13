import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  final appRoot = _appRoot();
  final workspaceRoot = _workspaceRoot(appRoot);

  test('app-owned and web brand assets match the approved sources', () {
    final approvedCopies = <String, String>{
      'assets/branding/app-icon-master.png':
          'design/plantcare-brand/masters/app-icon-master.png',
      'assets/branding/brand-mark-transparent.png':
          'design/plantcare-brand/masters/brand-mark-transparent.png',
      'assets/branding/wordmark-horizontal.png':
          'design/plantcare-brand/masters/wordmark-horizontal.png',
      'assets/branding/play-store-icon-512.png':
          'design/plantcare-brand/android/play-store-icon-512.png',
      'assets/branding/adaptive-foreground-1024.png':
          'design/plantcare-brand/android/adaptive-foreground-1024.png',
      'assets/branding/AppIcon-1024.png':
          'design/plantcare-brand/ios/AppIcon-1024.png',
      'assets/branding/splash-mark-512.png':
          'design/plantcare-brand/splash/splash-mark-512.png',
      'web/favicon-16.png': 'design/plantcare-brand/web/favicon-16.png',
      'web/favicon-32.png': 'design/plantcare-brand/web/favicon-32.png',
      'web/favicon-48.png': 'design/plantcare-brand/web/favicon-48.png',
      'web/icons/Icon-192.png': 'design/plantcare-brand/web/icons/Icon-192.png',
      'web/icons/Icon-512.png': 'design/plantcare-brand/web/icons/Icon-512.png',
      'web/icons/Icon-maskable-192.png':
          'design/plantcare-brand/web/icons/Icon-maskable-192.png',
      'web/icons/Icon-maskable-512.png':
          'design/plantcare-brand/web/icons/Icon-maskable-512.png',
    };

    for (final MapEntry(key: copyPath, value: sourcePath)
        in approvedCopies.entries) {
      final copy = File('${appRoot.path}/$copyPath');
      final source = File('${workspaceRoot.path}/$sourcePath');
      expect(copy.existsSync(), isTrue, reason: copyPath);
      expect(source.existsSync(), isTrue, reason: sourcePath);
      expect(
        _filesHaveIdenticalBytes(copy, source),
        isTrue,
        reason: '$copyPath must remain identical to $sourcePath',
      );
    }
  });

  test('app-owned and web brand assets have their approved dimensions', () {
    final expected = <String, ({int width, int height})>{
      'assets/branding/app-icon-master.png': (width: 1254, height: 1254),
      'assets/branding/brand-mark-transparent.png': (width: 1254, height: 1254),
      'assets/branding/wordmark-horizontal.png': (width: 2172, height: 724),
      'assets/branding/play-store-icon-512.png': (width: 512, height: 512),
      'assets/branding/adaptive-foreground-1024.png': (
        width: 1024,
        height: 1024,
      ),
      'assets/branding/AppIcon-1024.png': (width: 1024, height: 1024),
      'assets/branding/splash-mark-512.png': (width: 512, height: 512),
      'web/favicon-16.png': (width: 16, height: 16),
      'web/favicon-32.png': (width: 32, height: 32),
      'web/favicon-48.png': (width: 48, height: 48),
      'web/icons/Icon-192.png': (width: 192, height: 192),
      'web/icons/Icon-512.png': (width: 512, height: 512),
      'web/icons/Icon-maskable-192.png': (width: 192, height: 192),
      'web/icons/Icon-maskable-512.png': (width: 512, height: 512),
    };

    for (final MapEntry(key: path, value: dimensions) in expected.entries) {
      final decoded = _decode(appRoot, path);
      expect(decoded.width, dimensions.width, reason: path);
      expect(decoded.height, dimensions.height, reason: path);
    }
  });

  test('iOS marketing icon is opaque', () {
    final icon = _decode(
      appRoot,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
      'Icon-App-1024x1024@1x.png',
    );

    expect(icon.width, 1024);
    expect(icon.height, 1024);
    expect(icon.hasAlpha, isFalse);
  });

  test('web manifest references every approved PWA icon', () {
    final manifest = jsonDecode(
      File('${appRoot.path}/web/manifest.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final icons = (manifest['icons']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final iconPaths = icons.map((entry) => entry['src']).toSet();

    expect(manifest['name'], 'PlantCare AI');
    expect(manifest['short_name'], 'PlantCare AI');
    expect(manifest['theme_color'], '#2E7D32');
    expect(manifest['background_color'], '#F5FAF2');
    expect(
      iconPaths,
      containsAll(<String>{
        'icons/Icon-192.png',
        'icons/Icon-512.png',
        'icons/Icon-maskable-192.png',
        'icons/Icon-maskable-512.png',
      }),
    );
    final index = File('${appRoot.path}/web/index.html').readAsStringSync();
    expect(index, contains('href="favicon-16.png"'));
    expect(index, contains('href="favicon-32.png"'));
    expect(index, contains('href="favicon-48.png"'));
  });

  test('Android launcher is branded and adaptive configuration is present', () {
    final launcher = _decode(
      appRoot,
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    );
    final adaptiveXml = File(
      '${appRoot.path}/android/app/src/main/res/'
      'mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    final colorsXml = File(
      '${appRoot.path}/android/app/src/main/res/values/colors.xml',
    ).readAsStringSync();
    var greenDominantPixels = 0;
    var blueDominantPixels = 0;
    for (final pixel in launcher) {
      if (pixel.g > pixel.r && pixel.g > pixel.b) greenDominantPixels++;
      if (pixel.b > pixel.r && pixel.b > pixel.g) blueDominantPixels++;
    }

    expect(launcher.width, 192);
    expect(launcher.height, 192);
    expect(greenDominantPixels, greaterThan(blueDominantPixels));
    expect(adaptiveXml, contains('@color/ic_launcher_background'));
    expect(adaptiveXml, contains('@drawable/ic_launcher_foreground'));
    expect(adaptiveXml, contains('android:inset="16%"'));
    expect(colorsXml, contains('#F5FAF2'));
  });

  test(
    'platform application identifiers and Xcode asset settings are kept',
    () {
      final androidBuild = File('${appRoot.path}/android/app/build.gradle.kts')
          .readAsStringSync();
      final xcodeProject = File(
        '${appRoot.path}/ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();

      expect(androidBuild, contains('com.tasnimalam.plantcare_ai'));
      expect(xcodeProject, contains('com.tasnimalam.plantcareAi'));
      expect(
        xcodeProject,
        isNot(
          contains(
            'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = '
            'AppIcon;',
          ),
        ),
      );
    },
  );
}

Directory _appRoot() {
  final current = Directory.current;
  final workspaceApp = Directory('${current.path}/apps/plantcare_app');
  return workspaceApp.existsSync() ? workspaceApp : current;
}

Directory _workspaceRoot(Directory appRoot) => appRoot.parent.parent;

bool _filesHaveIdenticalBytes(File first, File second) {
  final firstBytes = first.readAsBytesSync();
  final secondBytes = second.readAsBytesSync();
  if (firstBytes.length != secondBytes.length) return false;
  for (var index = 0; index < firstBytes.length; index++) {
    if (firstBytes[index] != secondBytes[index]) return false;
  }
  return true;
}

image.Image _decode(Directory appRoot, String relativePath) {
  final file = File('${appRoot.path}/$relativePath');
  expect(file.existsSync(), isTrue, reason: relativePath);
  final decoded = image.decodePng(file.readAsBytesSync());
  expect(decoded, isNotNull, reason: relativePath);
  return decoded!;
}
