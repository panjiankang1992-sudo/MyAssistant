import 'package:ai_assistant/core/database/database.dart' hide QuickNote, Tag;
import 'package:ai_assistant/core/providers/core_providers.dart';
import 'package:ai_assistant/data/datasources/local_sync_datasource.dart';
import 'package:ai_assistant/domain/models/quick_note.dart';
import 'package:ai_assistant/domain/models/tag.dart';
import 'package:ai_assistant/features/bookkeeping/bookkeeping_page.dart';
import 'package:ai_assistant/features/notes/notes_page.dart';
import 'package:ai_assistant/features/notes/notes_store.dart';
import 'package:ai_assistant/features/sync/data_sync_service.dart';
import 'package:ai_assistant/features/sync/providers/sync_provider.dart';
import 'package:ai_assistant/shared/widgets/app_controls.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookkeepingStore', () {
    test('saves, loads, updates, and soft-deletes ledger entries', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = BookkeepingStore(db);
      final now = DateTime(2026, 5, 30, 10, 20);
      final category = defaultExpenseLedgerCategories.first;
      final entry = LedgerEntry(
        id: 'bill-1',
        kind: LedgerKind.expense,
        categoryId: category.id,
        categoryName: category.name,
        categoryEmoji: category.emoji,
        note: '午餐',
        amount: 28,
        currency: 'CNY',
        cnyAmount: 28,
        date: now,
        aiGenerated: false,
        createdAt: now,
      );

      await store.saveEntries([entry]);
      var loaded = await store.loadEntries();

      expect(loaded, hasLength(1));
      expect(loaded.single.note, '午餐');
      expect(loaded.single.amount, 28);

      await store.saveEntries([entry.copyWith(note: '午餐和咖啡', amount: 38)]);
      loaded = await store.loadEntries();

      expect(loaded.single.note, '午餐和咖啡');
      expect(loaded.single.amount, 38);

      await store.saveEntries(const []);
      loaded = await store.loadEntries();

      expect(loaded, isEmpty);
    });

    test('persists custom bill categories', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = BookkeepingStore(db);
      const category = LedgerCategory(
        id: 'coffee-custom',
        name: '咖啡豆',
        emoji: '☕',
        color: Color(0xFFEAF5FF),
        kind: LedgerKind.expense,
      );

      await store.saveCustomCategories([category]);
      final loaded = await store.loadCustomCategories();

      expect(loaded, hasLength(1));
      expect(loaded.single.name, '咖啡豆');
      expect(loaded.single.kind, LedgerKind.expense);
    });

    testWidgets('creates an entry from the add page', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dataSyncServiceProvider.overrideWith(
              (ref) => DataSyncService(
                engineLoader: () async => null,
                syncConfigured: () async => false,
                localSync: LocalSyncDatasource(db),
                notifier: ref.read(syncNotifierProvider.notifier),
              ),
            ),
          ],
          child: MaterialApp(home: BookkeepingPage(onAvatarTap: () {})),
        ),
      );
      await tester.pumpAndSettle();

      tester.widget<AppAddFab>(find.byType(AppAddFab)).onPressed();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '午餐');
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      final numberPad = find.byType(GridView).last;
      await tester.tap(
        find.descendant(of: numberPad, matching: find.text('2')),
      );
      await tester.tap(
        find.descendant(of: numberPad, matching: find.text('8')),
      );
      await tester.tap(find.text('完成记账'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final loaded = await BookkeepingStore(db).loadEntries();
      expect(loaded, hasLength(1));
      expect(loaded.single.note, '午餐');
      expect(loaded.single.amount, 28);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('NotesStore', () {
    test('saves and reloads notes with tags', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = NotesStore(db);
      final now = DateTime(2026, 5, 30, 9);
      final tag = Tag(
        id: 'tag-life',
        name: '生活',
        colorKey: 'lime',
        createdAt: now,
        updatedAt: now,
      );
      final note = QuickNote(
        id: 'note-1',
        title: '今天的想法',
        content: '记一下记账和随手记的验证。',
        summary: '验证',
        tags: [tag],
        date: now,
        createdAt: now,
        updatedAt: now,
        noteType: QuickNoteType.document,
      );

      await store.save([note]);
      final loaded = await store.load();

      expect(loaded, hasLength(1));
      expect(loaded.single.title, '今天的想法');
      expect(loaded.single.tags.single.name, '生活');
      expect(loaded.single.deleted, isFalse);
    });

    testWidgets('creates a note from the editor page', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dataSyncServiceProvider.overrideWith(
              (ref) => DataSyncService(
                engineLoader: () async => null,
                syncConfigured: () async => false,
                localSync: LocalSyncDatasource(db),
                notifier: ref.read(syncNotifierProvider.notifier),
              ),
            ),
          ],
          child: MaterialApp(home: NotesPage(onAvatarTap: () {})),
        ),
      );
      await tester.pumpAndSettle();

      tester.widget<AppAddFab>(find.byType(AppAddFab)).onPressed();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '今天的想法');
      await tester.enterText(find.byType(TextField).at(1), '内容记录');
      await tester.tap(find.byIcon(Icons.check_rounded).last);
      await tester.pumpAndSettle();

      final loaded = await NotesStore(db).load();
      expect(loaded, hasLength(1));
      expect(loaded.single.title, '今天的想法');
      expect(loaded.single.content, '内容记录');
      expect(loaded.single.deleted, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
