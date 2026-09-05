import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_domain/reminders.dart';
import 'package:plantcare_features/src/home/presentation/pages/home_page.dart';
import 'package:plantcare_features/src/reminders/presentation/bloc/reminders_bloc.dart';

final class _FakeReminderRepository implements ReminderRepository {
  @override
  Future<String> create(Reminder reminder) async => 'reminder-id';

  @override
  Future<void> setStatus(
    String plantId,
    String reminderId,
    ReminderStatus status, {
    DateTime? dueAt,
  }) async {}

  @override
  Stream<List<Reminder>> watchAll() => const Stream.empty();

  @override
  Stream<List<Reminder>> watchForPlant(String plantId) => const Stream.empty();

  @override
  Stream<Reminder?> watchOne(String plantId, String reminderId) =>
      const Stream.empty();
}

void main() {
  for (final size in [const Size(390, 600), const Size(1200, 300)]) {
    testWidgets('home content scrolls to the actions at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        BlocProvider(
          create: (_) => RemindersBloc(_FakeReminderRepository()),
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: const Scaffold(body: HomePage()),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final welcome = find.text('Welcome to PlantCare AI');
      final initialWelcomeY = tester.getTopLeft(welcome).dy;
      expect(find.text('Reminders').hitTestable(), findsNothing);

      await tester.drag(
        find.byKey(const ValueKey('home-page')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(welcome).dy, lessThan(initialWelcomeY));
      expect(find.text('My Plants').hitTestable(), findsOneWidget);
      expect(find.text('Reminders').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dashboard cards have the same size when a label wraps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      BlocProvider(
        create: (_) => RemindersBloc(_FakeReminderRepository()),
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(body: HomePage()),
        ),
      ),
    );

    final cardSizes =
        [
          'Overdue reminders',
          'Soil checks due today',
          'Upcoming fertilizer reviews',
        ].map((label) {
          final card = find.ancestor(
            of: find.text(label),
            matching: find.byType(Card),
          );
          return tester.getSize(card);
        }).toList();

    expect(cardSizes.toSet(), hasLength(1));
  });
}
