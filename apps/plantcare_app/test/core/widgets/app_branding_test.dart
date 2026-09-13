import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_app/app/theme/app_theme.dart';
import 'package:plantcare_app/core/widgets/app_branding.dart';

void main() {
  test('native splash dark color matches the application dark surface', () {
    expect(AppTheme.dark.colorScheme.surface, const Color(0xFF10140F));
  });

  testWidgets('uses the approved wordmark when a light layout is wide enough', (
    tester,
  ) async {
    await _showBranding(tester, width: 440);

    expect(find.byKey(const ValueKey('brand-wordmark')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('uses mark and native text on narrow layouts without overflow', (
    tester,
  ) async {
    await _showBranding(tester, width: 280);

    expect(
      find.byKey(const ValueKey('brand-mark-native-text')),
      findsOneWidget,
    );
    expect(find.text('PlantCare AI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses accessible mark and native text on dark surfaces', (
    tester,
  ) async {
    await _showBranding(tester, width: 440, brightness: Brightness.dark);

    expect(find.byKey(const ValueKey('brand-wordmark')), findsNothing);
    expect(
      find.byKey(const ValueKey('brand-mark-native-text')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('PlantCare AI'), findsOneWidget);
  });

  testWidgets(
    'large text remains contained on a narrow authentication layout',
    (tester) async {
      await _showBranding(tester, width: 240, textScaleFactor: 3);

      expect(
        find.byKey(const ValueKey('brand-mark-native-text')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _showBranding(
  WidgetTester tester, {
  required double width,
  Brightness brightness = Brightness.light,
  double textScaleFactor = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Center(
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: textScaleFactor,
            maxScaleFactor: textScaleFactor,
            child: SizedBox(width: width, child: const AppBranding.auth()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
