import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_ai/app/theme/app_theme.dart';
import 'package:plantcare_ai/features/home/presentation/pages/home_page.dart';
import 'package:plantcare_ai/features/reminders/presentation/bloc/reminders_bloc.dart';
import 'package:plantcare_domain/reminders.dart';

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
          theme: AppTheme.light,
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
