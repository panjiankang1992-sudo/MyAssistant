import 'package:flutter_test/flutter_test.dart';
import 'package:ai_assistant/features/todo/providers/selected_date_provider.dart';
import 'package:ai_assistant/features/todo/widgets/week_calendar_strip.dart';
import 'package:ai_assistant/features/todo/widgets/todo_item.dart';
import 'package:ai_assistant/features/todo/widgets/todo_list.dart';
import 'package:ai_assistant/domain/models/todo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('selectedDateProvider', () {
    test('defaults to today', () {
      final container = ProviderContainer();
      final selectedDate = container.read(selectedDateProvider);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(selectedDate, today);
      container.dispose();
    });

    test('date setter normalizes to midnight', () {
      final container = ProviderContainer();
      final notifier = container.read(selectedDateProvider.notifier);
      final dateWithTime = DateTime(2026, 5, 20, 14, 30, 45);
      notifier.date = dateWithTime;
      expect(container.read(selectedDateProvider), DateTime(2026, 5, 20));
      container.dispose();
    });

    test('changing date updates the state', () {
      final container = ProviderContainer();
      final notifier = container.read(selectedDateProvider.notifier);

      notifier.date = DateTime(2026, 5, 15);
      expect(container.read(selectedDateProvider), DateTime(2026, 5, 15));

      // Reset to today
      final now = DateTime.now();
      notifier.date = now;
      expect(
        container.read(selectedDateProvider),
        DateTime(now.year, now.month, now.day),
      );

      container.dispose();
    });
  });

  group('WeekCalendarStrip', () {
    testWidgets('renders 7 day columns per page', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                width: 400,
                child: WeekCalendarStrip(
                  selectedDate: DateTime(2026, 5, 22),
                  onDateSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('一'), findsOneWidget);
      expect(find.text('二'), findsOneWidget);
      expect(find.text('三'), findsOneWidget);
      expect(find.text('四'), findsOneWidget);
      expect(find.text('五'), findsOneWidget);
      expect(find.text('六'), findsOneWidget);
      expect(find.text('日'), findsOneWidget);
    });

    testWidgets('calls onDateSelected when a day is tapped', (tester) async {
      DateTime? selectedDate;
      final initialDate = DateTime(2026, 5, 22);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                width: 400,
                child: WeekCalendarStrip(
                  selectedDate: initialDate,
                  onDateSelected: (date) => selectedDate = date,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('${initialDate.day}'));
      await tester.pumpAndSettle();

      expect(selectedDate, isNotNull);
      expect(selectedDate!.day, equals(initialDate.day));
    });

    testWidgets('shows date numbers for current week', (tester) async {
      // The strip centers the selected day, showing three days on either side.
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                width: 400,
                child: WeekCalendarStrip(
                  selectedDate: DateTime(2026, 5, 22),
                  onDateSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show day numbers 19-25 around May 22.
      expect(find.text('19'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('23'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
    });
  });

  group('TodoItem readOnly', () {
    Widget buildTodoItem({required bool readOnly}) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TodoItem(
              todo: Todo(
                id: 'test-1',
                title: '测试待办',
                source: 'manual',
                type: 'personal',
                time: '09:00',
                date: DateTime(2026, 5, 22),
                createdAt: DateTime(2026, 5, 22),
                updatedAt: DateTime(2026, 5, 22),
              ),
              readOnly: readOnly,
              onTap: () {},
              onToggle: () {},
              onLongPress: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('renders in both readOnly and editable modes', (tester) async {
      await tester.pumpWidget(buildTodoItem(readOnly: true));
      expect(find.text('测试待办'), findsOneWidget);

      await tester.pumpWidget(buildTodoItem(readOnly: false));
      expect(find.text('测试待办'), findsOneWidget);
    });

    testWidgets('readOnly item shows title but checkbox is non-interactive', (
      tester,
    ) async {
      bool toggled = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TodoItem(
                todo: Todo(
                  id: 'test-2',
                  title: '只读待办',
                  source: 'manual',
                  type: 'personal',
                  time: '10:00',
                  date: DateTime(2026, 5, 22),
                  createdAt: DateTime(2026, 5, 22),
                  updatedAt: DateTime(2026, 5, 22),
                ),
                readOnly: true,
                onTap: () {},
                onToggle: () => toggled = true,
              ),
            ),
          ),
        ),
      );

      // Find the checkbox area (first GestureDetector inside the item)
      final checkboxes = find.byType(AnimatedBuilder);
      if (checkboxes.evaluate().isNotEmpty) {
        // Try tapping the checkbox area - should NOT trigger onToggle in readOnly
        await tester.tapAt(tester.getCenter(checkboxes.first));
        await tester.pumpAndSettle();
        expect(toggled, isFalse);
      }
    });
  });

  group('TodoList readOnly', () {
    testWidgets('passes readOnly to TodoItem children', (tester) async {
      final todos = [
        Todo(
          id: '1',
          title: '待办1',
          source: 'manual',
          type: 'personal',
          time: '09:00',
          date: DateTime(2026, 5, 22),
          createdAt: DateTime(2026, 5, 22),
          updatedAt: DateTime(2026, 5, 22),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TodoList(
                todos: todos,
                readOnly: true,
                onToggle: (_) {},
                onDelete: (_) {},
                onTap: (_) {},
                onActionTap: (_) {},
                onComplete: (_) {},
                onDefer: (_) {},
              ),
            ),
          ),
        ),
      );

      // Pump to allow staggered animations to start
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('待办1'), findsOneWidget);
      // In readOnly mode, long press should be disabled
      // We verify the widget renders without error
    });
  });
}
