import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/features/information/presentation/pages/privacy_safety_page.dart';

void main() {
  testWidgets('discloses Spark V1 privacy, AI, reminder, and account limits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrivacySafetyPage())),
    );

    expect(find.text('Privacy & Safety'), findsOneWidget);
    expect(find.textContaining('sent to Firebase AI'), findsOneWidget);
    expect(find.textContaining('does not save the photo'), findsOneWidget);
    expect(find.textContaining('can be wrong'), findsOneWidget);
    expect(find.textContaining('not guaranteed by a server'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('V1 account limits'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(
      find.textContaining('full data export are not included'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
