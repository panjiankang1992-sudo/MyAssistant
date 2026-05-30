import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart' hide Tag;
import '../../core/platform/app_performance.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/core_providers.dart';
import '../../data/datasources/local_datasource.dart';
import '../../domain/models/tag.dart';
import '../../shared/widgets/app_controls.dart';
import '../../shared/widgets/edge_swipe_pop.dart';
import '../../shared/widgets/profile_avatar_button.dart';
import '../../shared/widgets/tag_chip.dart';
import '../ai_settings/ai_model_provider.dart';
import '../copilot/services/openai_compatible_client.dart';
import '../sync/data_sync_service.dart';
import '../tags/tag_selector.dart';
import '../profile/profile_provider.dart';
import '../todo/widgets/week_calendar_strip.dart';

enum LedgerKind { expense, income }

class LedgerCategory {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final LedgerKind kind;

  const LedgerCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.kind,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'color': color.toARGB32(),
    'kind': kind.name,
  };

  factory LedgerCategory.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] == 'income'
        ? LedgerKind.income
        : LedgerKind.expense;
    return LedgerCategory(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? '自定义',
      emoji:
          json['emoji'] as String? ?? (kind == LedgerKind.income ? '💰' : '🔹'),
      color: Color((json['color'] as int?) ?? 0xFFEAF5FF),
      kind: kind,
    );
  }
}

class LedgerCategoryGroup {
  final LedgerCategory primary;
  final List<LedgerCategory> children;

  const LedgerCategoryGroup({required this.primary, required this.children});
}

class LedgerEntry {
  final String id;
  final LedgerKind kind;
  final String categoryId;
  final String categoryName;
  final String categoryEmoji;
  final String note;
  final double amount;
  final String currency;
  final double cnyAmount;
  final DateTime date;
  final bool aiGenerated;
  final List<Tag> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  const LedgerEntry({
    required this.id,
    required this.kind,
    required this.categoryId,
    required this.categoryName,
    required this.categoryEmoji,
    required this.note,
    required this.amount,
    required this.currency,
    required this.cnyAmount,
    required this.date,
    required this.aiGenerated,
    this.tags = const [],
    required this.createdAt,
    DateTime? updatedAt,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? createdAt;

  LedgerEntry copyWith({
    String? id,
    LedgerKind? kind,
    String? categoryId,
    String? categoryName,
    String? categoryEmoji,
    String? note,
    double? amount,
    String? currency,
    double? cnyAmount,
    DateTime? date,
    bool? aiGenerated,
    List<Tag>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryEmoji: categoryEmoji ?? this.categoryEmoji,
      note: note ?? this.note,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      cnyAmount: cnyAmount ?? this.cnyAmount,
      date: date ?? this.date,
      aiGenerated: aiGenerated ?? this.aiGenerated,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'categoryEmoji': categoryEmoji,
    'note': note,
    'amount': amount,
    'currency': currency,
    'cnyAmount': cnyAmount,
    'date': date.toIso8601String(),
    'aiGenerated': aiGenerated,
    'tags': tags.map((tag) => tag.toCompactJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
  };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return LedgerEntry(
      id: json['id'] as String? ?? const Uuid().v4(),
      kind: (json['kind'] as String?) == 'income'
          ? LedgerKind.income
          : LedgerKind.expense,
      categoryId: json['categoryId'] as String? ?? 'other',
      categoryName: json['categoryName'] as String? ?? '其他',
      categoryEmoji: json['categoryEmoji'] as String? ?? '🔹',
      note: json['note'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'CNY',
      cnyAmount: (json['cnyAmount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? now,
      aiGenerated: json['aiGenerated'] as bool? ?? false,
      tags: _decodeLedgerTags(json['tags']),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          now,
      deleted: json['deleted'] as bool? ?? false,
    );
  }
}

List<Tag> _decodeLedgerTags(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) {
        if (item is Map<String, dynamic>) return Tag.fromCompactJson(item);
        if (item is Map) {
          return Tag.fromCompactJson(Map<String, dynamic>.from(item));
        }
        return null;
      })
      .whereType<Tag>()
      .toList();
}

class ExchangeCache {
  final DateTime updatedAt;
  final Map<String, double> toCny;

  const ExchangeCache({required this.updatedAt, required this.toCny});

  Map<String, dynamic> toJson() => {
    'updatedAt': updatedAt.toIso8601String(),
    'toCny': toCny,
  };

  factory ExchangeCache.fromJson(Map<String, dynamic> json) {
    final raw = json['toCny'] as Map<String, dynamic>? ?? const {};
    return ExchangeCache(
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      toCny: {
        for (final item in raw.entries)
          item.key: (item.value as num?)?.toDouble() ?? 1,
      },
    );
  }
}

class BookkeepingStore {
  final AppDatabase _db;
  final LocalDatasource? _localDatasource;

  BookkeepingStore(this._db, [this._localDatasource]);

  static const _entriesStoreName = 'bookkeeping_entries_json';
  static const _categoriesStoreName = 'bookkeeping_categories_json';
  static const _exchangeStoreName = 'bookkeeping_exchange_json';

  bool get _useFileFallback =>
      LocalDatasource.usesFileFallback && _localDatasource != null;

  Future<List<LedgerEntry>> loadEntries() async {
    if (_useFileFallback) return _loadFallbackEntries();
    final rows = await (_db.select(
      _db.bills,
    )..where((t) => t.isDeleted.equals(false))).get();
    return rows
        .map(
          (row) => LedgerEntry.fromJson({
            'id': row.id,
            'kind': row.kind,
            'categoryId': row.categoryId,
            'categoryName': row.categoryName,
            'categoryEmoji': row.categoryEmoji,
            'note': row.note,
            'amount': row.amount,
            'currency': row.currency,
            'cnyAmount': row.cnyAmount,
            'date': row.date.toIso8601String(),
            'aiGenerated': row.aiGenerated,
            'tags': jsonDecode(row.tags),
            'createdAt': row.createdAt.toIso8601String(),
            'updatedAt': row.updatedAt.toIso8601String(),
            'deleted': row.isDeleted,
          }),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> saveEntries(List<LedgerEntry> entries) async {
    if (_useFileFallback) return _saveFallbackEntries(entries);
    final existing = await _db.select(_db.bills).get();
    final ids = entries.map((item) => item.id).toSet();
    for (final entry in entries) {
      final old = existing.where((row) => row.id == entry.id).firstOrNull;
      final updatedAt = entry.updatedAt.isBefore(entry.createdAt)
          ? DateTime.now()
          : entry.updatedAt;
      await _db
          .into(_db.bills)
          .insertOnConflictUpdate(
            BillsCompanion(
              id: Value(entry.id),
              kind: Value(entry.kind.name),
              categoryId: Value(entry.categoryId),
              categoryName: Value(entry.categoryName),
              categoryEmoji: Value(entry.categoryEmoji),
              note: Value(entry.note),
              amount: Value(entry.amount),
              currency: Value(entry.currency),
              cnyAmount: Value(entry.cnyAmount),
              date: Value(entry.date),
              aiGenerated: Value(entry.aiGenerated),
              tags: Value(LocalDatasource.encodeTags(entry.tags)),
              createdAt: Value(entry.createdAt),
              updatedAt: Value(updatedAt),
              version: Value((old?.version ?? 0) + 1),
              isDeleted: Value(entry.deleted),
            ),
          );
    }
    for (final row in existing) {
      if (!ids.contains(row.id) && !row.isDeleted) {
        await (_db.update(_db.bills)..where((t) => t.id.equals(row.id))).write(
          BillsCompanion(
            updatedAt: Value(DateTime.now()),
            version: Value(row.version + 1),
            isDeleted: const Value(true),
          ),
        );
      }
    }
  }

  Future<List<LedgerCategory>> loadCustomCategories() async {
    if (_useFileFallback) return _loadFallbackCategories();
    final rows = await (_db.select(
      _db.billCategories,
    )..where((t) => t.isDeleted.equals(false))).get();
    return rows
        .map(
          (row) => LedgerCategory.fromJson({
            'id': row.id,
            'name': row.name,
            'emoji': row.emoji,
            'color': row.color,
            'kind': row.kind,
          }),
        )
        .toList();
  }

  Future<void> saveCustomCategories(List<LedgerCategory> categories) async {
    if (_useFileFallback) return _saveFallbackCategories(categories);
    final existing = await _db.select(_db.billCategories).get();
    final ids = categories.map((item) => item.id).toSet();
    final now = DateTime.now();
    for (final category in categories) {
      final old = existing.where((row) => row.id == category.id).firstOrNull;
      await _db
          .into(_db.billCategories)
          .insertOnConflictUpdate(
            BillCategoriesCompanion(
              id: Value(category.id),
              name: Value(category.name),
              emoji: Value(category.emoji),
              color: Value(category.color.toARGB32()),
              kind: Value(category.kind.name),
              createdAt: Value(old?.createdAt ?? now),
              updatedAt: Value(now),
              version: Value((old?.version ?? 0) + 1),
              isDeleted: const Value(false),
            ),
          );
    }
    for (final row in existing) {
      if (!ids.contains(row.id) && !row.isDeleted) {
        await (_db.update(
          _db.billCategories,
        )..where((t) => t.id.equals(row.id))).write(
          BillCategoriesCompanion(
            updatedAt: Value(now),
            version: Value(row.version + 1),
            isDeleted: const Value(true),
          ),
        );
      }
    }
  }

  Future<ExchangeCache?> loadExchange() async {
    if (_useFileFallback) {
      final raw = await _localDatasource!.readLocalStoreText(
        _exchangeStoreName,
      );
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ExchangeCache.fromJson(decoded.cast<String, dynamic>());
    }
    final datasource = LocalDatasource(_db);
    final data = await datasource.getAppSettingJson('data', 'exchange_cache');
    return data == null ? null : ExchangeCache.fromJson(data);
  }

  Future<void> saveExchange(ExchangeCache cache) async {
    if (_useFileFallback) {
      await _localDatasource!.writeLocalStoreText(
        _exchangeStoreName,
        jsonEncode(cache.toJson()),
      );
      return;
    }
    await LocalDatasource(_db).upsertAppSettingJson(
      module: 'profile',
      dataType: 'data',
      id: 'exchange_cache',
      payload: cache.toJson(),
      updatedAt: cache.updatedAt,
    );
  }

  Future<List<LedgerEntry>> _loadFallbackEntries() async {
    final raw = await _localDatasource!.readLocalStoreText(_entriesStoreName);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final entries = decoded
        .whereType<Map>()
        .map((item) => LedgerEntry.fromJson(item.cast<String, dynamic>()))
        .where((item) => !item.deleted)
        .toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Future<void> _saveFallbackEntries(List<LedgerEntry> entries) async {
    final payload = entries
        .map((entry) => entry.toJson())
        .toList(growable: false);
    await _localDatasource!.writeLocalStoreText(
      _entriesStoreName,
      jsonEncode(payload),
    );
  }

  Future<List<LedgerCategory>> _loadFallbackCategories() async {
    final raw = await _localDatasource!.readLocalStoreText(
      _categoriesStoreName,
    );
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => LedgerCategory.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _saveFallbackCategories(List<LedgerCategory> categories) async {
    final payload = categories
        .map((category) => category.toJson())
        .toList(growable: false);
    await _localDatasource!.writeLocalStoreText(
      _categoriesStoreName,
      jsonEncode(payload),
    );
  }
}

class ExchangeService {
  final BookkeepingStore store;

  ExchangeService(this.store);

  Future<ExchangeCache> getRates() async {
    final cached = await store.loadExchange();
    final now = DateTime.now();
    if (cached != null &&
        cached.updatedAt.year == now.year &&
        cached.updatedAt.month == now.month &&
        cached.updatedAt.day == now.day) {
      return cached;
    }
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);
      final request = await client.getUrl(
        Uri.parse('https://open.er-api.com/v6/latest/CNY'),
      );
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      client.close(force: true);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('汇率请求失败');
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final rates = data['rates'] as Map<String, dynamic>? ?? const {};
      final toCny = <String, double>{'CNY': 1};
      for (final code in ['USD', 'EUR', 'JPY', 'HKD', 'GBP', 'KRW']) {
        final value = (rates[code] as num?)?.toDouble();
        if (value != null && value > 0) toCny[code] = 1 / value;
      }
      final next = ExchangeCache(updatedAt: now, toCny: toCny);
      await store.saveExchange(next);
      return next;
    } catch (_) {
      return cached ??
          ExchangeCache(
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            toCny: const {
              'CNY': 1,
              'USD': 7.2,
              'EUR': 7.8,
              'JPY': 0.046,
              'HKD': 0.92,
              'GBP': 9.1,
              'KRW': 0.0052,
            },
          );
    }
  }
}

const _expenseCategoryGroups = [
  LedgerCategoryGroup(
    primary: LedgerCategory(
      id: 'food',
      name: '餐饮',
      emoji: '🍽️',
      color: Color(0xFFF6EDE8),
      kind: LedgerKind.expense,
    ),
    children: [
      LedgerCategory(
        id: 'food_meals',
        name: '三餐',
        emoji: '🍱',
        color: Color(0xFFFFF1E6),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'food_breakfast',
        name: '早餐',
        emoji: '🥣',
        color: Color(0xFFFFF4E6),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'food_lunch',
        name: '午餐',
        emoji: '🍛',
        color: Color(0xFFFFEFE5),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'food_dinner',
        name: '晚餐',
        emoji: '🍲',
        color: Color(0xFFF8EFE4),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'food_coffee',
        name: '咖啡',
        emoji: '☕',
        color: Color(0xFFF2ECE6),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'food_milk_tea',
        name: '奶茶',
        emoji: '🧋',
        color: Color(0xFFFFEEF4),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'food_snack',
        name: '零食',
        emoji: '🍭',
        color: Color(0xFFFFF3E7),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'food_takeout',
        name: '外卖',
        emoji: '🥡',
        color: Color(0xFFFFEFE5),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'food_gathering',
        name: '聚餐',
        emoji: '🍻',
        color: Color(0xFFFFF1EB),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'food_groceries',
        name: '买菜',
        emoji: '🥬',
        color: Color(0xFFEAF8EF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'food_other',
        name: '其他',
        emoji: '🍽️',
        color: Color(0xFFF6EDE8),
        kind: LedgerKind.expense,
      ),
    ],
  ),
  LedgerCategoryGroup(
    primary: LedgerCategory(
      id: 'traffic',
      name: '交通',
      emoji: '🚌',
      color: Color(0xFFEDEBFA),
      kind: LedgerKind.expense,
    ),
    children: [
      LedgerCategory(
        id: 'traffic_taxi',
        name: '打车',
        emoji: '🚕',
        color: Color(0xFFEAF1FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'traffic_bus',
        name: '公交',
        emoji: '🚌',
        color: Color(0xFFEAF7FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'traffic_subway',
        name: '地铁',
        emoji: '🚇',
        color: Color(0xFFEDEBFA),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'traffic_fuel',
        name: '加油',
        emoji: '⛽',
        color: Color(0xFFFFEEF1),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'traffic_parking',
        name: '停车',
        emoji: '🅿️',
        color: Color(0xFFEFF4FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'traffic_toll',
        name: '高速费',
        emoji: '🛣️',
        color: Color(0xFFFFF4E6),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'traffic_train',
        name: '火车',
        emoji: '🚄',
        color: Color(0xFFEAF5FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'traffic_flight',
        name: '飞机',
        emoji: '✈️',
        color: Color(0xFFEAF7FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'traffic_bike',
        name: '共享单车',
        emoji: '🚲',
        color: Color(0xFFEAF8EF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'traffic_other',
        name: '其他',
        emoji: '🚌',
        color: Color(0xFFEDEBFA),
        kind: LedgerKind.expense,
      ),
    ],
  ),
  LedgerCategoryGroup(
    primary: LedgerCategory(
      id: 'shopping',
      name: '购物',
      emoji: '🛍️',
      color: Color(0xFFF8F1FF),
      kind: LedgerKind.expense,
    ),
    children: [
      LedgerCategory(
        id: 'shopping_daily',
        name: '日用品',
        emoji: '🧴',
        color: Color(0xFFF4F8FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'shopping_clothing',
        name: '衣服鞋帽',
        emoji: '👕',
        color: Color(0xFFF1F4FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'shopping_digital',
        name: '数码产品',
        emoji: '💻',
        color: Color(0xFFEFF1FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'shopping_home',
        name: '家居用品',
        emoji: '🛋️',
        color: Color(0xFFF6F2EA),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'shopping_online',
        name: '网购',
        emoji: '📦',
        color: Color(0xFFFFF4E6),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'shopping_gift',
        name: '礼物',
        emoji: '🎁',
        color: Color(0xFFFFEEF3),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'shopping_beauty',
        name: '美妆护肤',
        emoji: '💄',
        color: Color(0xFFFFEEF8),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'shopping_other',
        name: '其他',
        emoji: '🛍️',
        color: Color(0xFFF8F1FF),
        kind: LedgerKind.expense,
      ),
    ],
  ),
  LedgerCategoryGroup(
    primary: LedgerCategory(
      id: 'life',
      name: '生活',
      emoji: '🏠',
      color: Color(0xFFEFF4FF),
      kind: LedgerKind.expense,
    ),
    children: [
      LedgerCategory(
        id: 'life_rent',
        name: '房租',
        emoji: '🏘️',
        color: Color(0xFFEFF4FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'life_property',
        name: '物业',
        emoji: '🏢',
        color: Color(0xFFEAF5FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'life_water',
        name: '水费',
        emoji: '💧',
        color: Color(0xFFEAF7FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'life_electricity',
        name: '电费',
        emoji: '💡',
        color: Color(0xFFFFF7E8),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'life_gas',
        name: '燃气',
        emoji: '🔥',
        color: Color(0xFFFFF1E8),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'life_broadband',
        name: '宽带',
        emoji: '📶',
        color: Color(0xFFEFF7FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'life_housekeeping',
        name: '家政',
        emoji: '🧹',
        color: Color(0xFFF4F8FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'life_repair',
        name: '维修',
        emoji: '🧰',
        color: Color(0xFFFFF4E6),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'life_other',
        name: '其他',
        emoji: '🏠',
        color: Color(0xFFEFF4FF),
        kind: LedgerKind.expense,
      ),
    ],
  ),
  LedgerCategoryGroup(
    primary: LedgerCategory(
      id: 'medical',
      name: '医疗',
      emoji: '💊',
      color: Color(0xFFEAF8F2),
      kind: LedgerKind.expense,
    ),
    children: [
      LedgerCategory(
        id: 'medical_hospital',
        name: '医院',
        emoji: '🏥',
        color: Color(0xFFEAF8F2),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'medical_medicine',
        name: '药品',
        emoji: '💊',
        color: Color(0xFFFFEEF1),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'medical_checkup',
        name: '体检',
        emoji: '🩺',
        color: Color(0xFFEFF7FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'medical_insurance',
        name: '保险',
        emoji: '🛡️',
        color: Color(0xFFEFF7F2),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'medical_fitness',
        name: '健身',
        emoji: '🏋️',
        color: Color(0xFFEAF8EF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'medical_running',
        name: '跑步',
        emoji: '👟',
        color: Color(0xFFEAF1FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'medical_other',
        name: '其他',
        emoji: '💊',
        color: Color(0xFFEAF8F2),
        kind: LedgerKind.expense,
      ),
    ],
  ),
  LedgerCategoryGroup(
    primary: LedgerCategory(
      id: 'entertainment',
      name: '娱乐',
      emoji: '🎭',
      color: Color(0xFFFFF1E8),
      kind: LedgerKind.expense,
    ),
    children: [
      LedgerCategory(
        id: 'entertainment_movie',
        name: '电影',
        emoji: '🎬',
        color: Color(0xFFFFF0F7),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'entertainment_game',
        name: '游戏',
        emoji: '🎮',
        color: Color(0xFFEFF1FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'entertainment_ktv',
        name: 'KTV',
        emoji: '🎤',
        color: Color(0xFFFFEEF8),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'entertainment_bar',
        name: '酒吧',
        emoji: '🍸',
        color: Color(0xFFF8F1FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'entertainment_travel',
        name: '旅游',
        emoji: '🧳',
        color: Color(0xFFEAF7FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'entertainment_photo',
        name: '摄影',
        emoji: '📷',
        color: Color(0xFFFFF4E6),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'entertainment_books',
        name: '书籍',
        emoji: '📚',
        color: Color(0xFFEAF1FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'entertainment_music',
        name: '音乐',
        emoji: '🎧',
        color: Color(0xFFF0F3FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'entertainment_other',
        name: '其他',
        emoji: '🎭',
        color: Color(0xFFFFF1E8),
        kind: LedgerKind.expense,
      ),
    ],
  ),
  LedgerCategoryGroup(
    primary: LedgerCategory(
      id: 'social',
      name: '社交',
      emoji: '🤝',
      color: Color(0xFFFFF1EB),
      kind: LedgerKind.expense,
    ),
    children: [
      LedgerCategory(
        id: 'social_red_packet',
        name: '红包',
        emoji: '🧧',
        color: Color(0xFFFFEFEF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'social_cash_gift',
        name: '礼金',
        emoji: '💝',
        color: Color(0xFFFFEEF3),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'social_treat',
        name: '请客',
        emoji: '🍽️',
        color: Color(0xFFFFF1E6),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'social_party',
        name: '聚会',
        emoji: '🎉',
        color: Color(0xFFFFF4E6),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'social_love',
        name: '恋爱',
        emoji: '💗',
        color: Color(0xFFFFEEF8),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'social_other',
        name: '其他',
        emoji: '🤝',
        color: Color(0xFFFFF1EB),
        kind: LedgerKind.expense,
      ),
    ],
  ),
  LedgerCategoryGroup(
    primary: LedgerCategory(
      id: 'pet',
      name: '宠物',
      emoji: '🐱',
      color: Color(0xFFFFF0F0),
      kind: LedgerKind.expense,
    ),
    children: [
      LedgerCategory(
        id: 'pet_dog_food',
        name: '狗粮',
        emoji: '🐶',
        color: Color(0xFFFFF4E6),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'pet_cat_food',
        name: '猫粮',
        emoji: '🐱',
        color: Color(0xFFEAF7FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'pet_medical',
        name: '医疗',
        emoji: '🧰',
        color: Color(0xFFEAF8F2),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'pet_grooming',
        name: '洗护',
        emoji: '🧴',
        color: Color(0xFFF4F8FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'pet_toy',
        name: '玩具',
        emoji: '🧶',
        color: Color(0xFFF8F1FF),
        kind: LedgerKind.expense,
      ),
      LedgerCategory(
        id: 'pet_other',
        name: '其他',
        emoji: '🐱',
        color: Color(0xFFFFF0F0),
        kind: LedgerKind.expense,
      ),
    ],
  ),
  LedgerCategoryGroup(
    primary: LedgerCategory(
      id: 'custom_expense',
      name: '自定义',
      emoji: '➕',
      color: Color(0xFFEAF5FF),
      kind: LedgerKind.expense,
    ),
    children: [],
  ),
];

List<LedgerCategory> get _expensePrimaryCategories =>
    _expenseCategoryGroups.map((group) => group.primary).toList();

List<LedgerCategory> get _expenseCategories => [
  for (final group in _expenseCategoryGroups) group.primary,
  for (final group in _expenseCategoryGroups) ...group.children,
];

LedgerCategory get _customExpensePrimaryCategory =>
    _expenseCategoryGroups.last.primary;

const _incomeCategories = [
  LedgerCategory(
    id: 'salary',
    name: '工资',
    emoji: '💼',
    color: Color(0xFFE8F8EF),
    kind: LedgerKind.income,
  ),
  LedgerCategory(
    id: 'bonus',
    name: '奖金',
    emoji: '🏆',
    color: Color(0xFFFFF3E0),
    kind: LedgerKind.income,
  ),
  LedgerCategory(
    id: 'part_time',
    name: '兼职',
    emoji: '🧰',
    color: Color(0xFFEAF1FF),
    kind: LedgerKind.income,
  ),
  LedgerCategory(
    id: 'investment_income',
    name: '投资收益',
    emoji: '📈',
    color: Color(0xFFEAF8EF),
    kind: LedgerKind.income,
  ),
  LedgerCategory(
    id: 'stock',
    name: '股票',
    emoji: '📊',
    color: Color(0xFFEFF1FF),
    kind: LedgerKind.income,
  ),
  LedgerCategory(
    id: 'fund',
    name: '基金',
    emoji: '🐖',
    color: Color(0xFFFFF4E6),
    kind: LedgerKind.income,
  ),
  LedgerCategory(
    id: 'interest',
    name: '利息',
    emoji: '🏦',
    color: Color(0xFFEFF7FF),
    kind: LedgerKind.income,
  ),
  LedgerCategory(
    id: 'rent_income',
    name: '租金收入',
    emoji: '🏘️',
    color: Color(0xFFEFF4FF),
    kind: LedgerKind.income,
  ),
  LedgerCategory(
    id: 'refund',
    name: '退款',
    emoji: '↩️',
    color: Color(0xFFEAF1FF),
    kind: LedgerKind.income,
  ),
  LedgerCategory(
    id: 'red_packet_income',
    name: '红包收入',
    emoji: '🧧',
    color: Color(0xFFFFEFEF),
    kind: LedgerKind.income,
  ),
  LedgerCategory(
    id: 'other_income',
    name: '其他收入',
    emoji: '💰',
    color: Color(0xFFFFF7E8),
    kind: LedgerKind.income,
  ),
];

List<LedgerCategory> get defaultExpenseLedgerCategories => _expenseCategories;

LedgerCategory findDefaultLedgerCategory(String name) => _findCategory(name);

String ledgerCategoryDisplayNameForSelection(LedgerCategory category) {
  if (category.kind == LedgerKind.income) return category.name;
  final group = _expenseGroupForCategory(category);
  if (group == null) {
    return '${_customExpensePrimaryCategory.name}-${category.name}';
  }
  if (group.primary.id == category.id) return group.primary.name;
  return '${group.primary.name}-${category.name}';
}

class BookkeepingPage extends ConsumerStatefulWidget {
  final VoidCallback? onAvatarTap;

  const BookkeepingPage({super.key, this.onAvatarTap});

  @override
  ConsumerState<BookkeepingPage> createState() => _BookkeepingPageState();
}

class _BookkeepingPageState extends ConsumerState<BookkeepingPage> {
  late final BookkeepingStore _store;
  late final ExchangeService _exchangeService;
  var _entries = <LedgerEntry>[];
  var _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _store = BookkeepingStore(
      ref.read(databaseProvider),
      ref.read(datasourceProvider),
    );
    _exchangeService = ExchangeService(_store);
    _load();
  }

  Future<void> _load() async {
    final items = await _store.loadEntries();
    if (mounted) setState(() => _entries = items);
    await _store.saveEntries(items);
  }

  Future<void> _addEntry(LedgerEntry entry) async {
    final now = DateTime.now();
    final next = [entry.copyWith(updatedAt: now), ..._entries]
      ..sort((a, b) => b.date.compareTo(a.date));
    setState(() => _entries = next);
    unawaited(_persistEntries(next, entry, 'upsert'));
  }

  Future<void> _updateEntry(LedgerEntry entry) async {
    final now = DateTime.now();
    final next =
        _entries
            .map(
              (item) =>
                  item.id == entry.id ? entry.copyWith(updatedAt: now) : item,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    setState(() => _entries = next);
    unawaited(_persistEntries(next, entry, 'upsert'));
  }

  Future<void> _deleteEntry(LedgerEntry entry) async {
    final next = _entries
        .map(
          (item) => item.id == entry.id
              ? item.copyWith(deleted: true, updatedAt: DateTime.now())
              : item,
        )
        .where((item) => !item.deleted)
        .toList();
    setState(() => _entries = next);
    unawaited(_persistEntries(next, entry, 'delete'));
  }

  Future<void> _persistEntries(
    List<LedgerEntry> entries,
    LedgerEntry dirtyEntry,
    String operation,
  ) async {
    try {
      await _store.saveEntries(entries);
      unawaited(_markBillDirty(dirtyEntry, operation));
    } catch (error, stackTrace) {
      debugPrint('Failed to persist ledger entries: $error\n$stackTrace');
    }
  }

  Future<void> _markBillDirty(LedgerEntry entry, String operation) {
    return ref
        .read(dataSyncServiceProvider)
        .markDirty(
          DataSyncType.bill,
          entry.id,
          operation: operation,
          payload: {
            'amount': entry.amount,
            'category': _ledgerCategoryTitle(entry),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );
  }

  void _markBillCategoriesDirty() {
    ref
        .read(dataSyncServiceProvider)
        .markDirty(
          DataSyncType.bill,
          'ledger-categories',
          operation: 'categories',
        );
  }

  List<LedgerEntry> get _filtered {
    return _entries;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  double _sum(Iterable<LedgerEntry> entries, LedgerKind kind) => entries
      .where((item) => item.kind == kind)
      .fold(0.0, (sum, item) => sum + item.cnyAmount);

  ({double income, double expense}) _dailyTotals(DateTime date) {
    final day = _dateOnly(date);
    var income = 0.0;
    var expense = 0.0;
    for (final entry in _entries) {
      if (_dateOnly(entry.date) != day) continue;
      if (entry.kind == LedgerKind.income) {
        income += entry.cnyAmount;
      } else {
        expense += entry.cnyAmount;
      }
    }
    return (income: income, expense: expense);
  }

  double _dailyNet(DateTime date) {
    final totals = _dailyTotals(date);
    final income = totals.income;
    final expense = totals.expense;
    return income - expense;
  }

  String? _dailyAmountBadge(DateTime date) {
    final totals = _dailyTotals(date);
    final hasAmount =
        totals.income.abs() >= 0.005 || totals.expense.abs() >= 0.005;
    if (!hasAmount) return null;
    final net = totals.income - totals.expense;
    if (net.abs() < 0.005) return '0';
    return _compactAmount(net);
  }

  Color _dailyAmountColor(DateTime date) {
    final net = _dailyNet(date);
    if (net < -0.005) return AppColors.danger;
    if (net > 0.005) return AppColors.success;
    return Theme.of(context).colorScheme.appMutedText;
  }

  String _compactAmount(double value) {
    final abs = value.abs();
    final prefix = value > 0 ? '+' : '-';
    if (abs >= 10000) {
      return '$prefix${(abs / 10000).toStringAsFixed(1)}w';
    }
    if (abs >= 1000) {
      return '$prefix${abs.toStringAsFixed(0)}';
    }
    final rounded = abs.toStringAsFixed(abs < 100 ? 1 : 0);
    return '$prefix$rounded';
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filtered;
    final todayItems = visible
        .where((item) => _dateOnly(item.date) == _dateOnly(_selectedDate))
        .toList();
    final expense = _sum(todayItems, LedgerKind.expense);
    final income = _sum(todayItems, LedgerKind.income);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.appPage,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              selectedDate: _selectedDate,
              onDatePick: _pickDate,
              onStats: () => showStatsPage(context, entries: _entries),
              onAvatar: widget.onAvatarTap,
            ),
            WeekCalendarStrip(
              selectedDate: _selectedDate,
              badgeBuilder: _dailyAmountBadge,
              badgeColorBuilder: _dailyAmountColor,
              onDateSelected: (date) {
                setState(() => _selectedDate = date);
              },
            ),
            Expanded(
              child: _LedgerDayView(
                entries: todayItems,
                selectedDate: _selectedDate,
                expense: expense,
                income: income,
                onEntryTap: _showEntryDetail,
                onEntryDelete: _deleteEntry,
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AppAddFab(
        tooltip: '新增记账',
        onPressed: () => showAddLedgerPage(
          context,
          ref: ref,
          date: _selectedDate,
          exchangeService: _exchangeService,
          onSaved: _addEntry,
          onCategoriesChanged: _markBillCategoriesDirty,
        ),
      ),
    );
  }

  void _showEntryDetail(LedgerEntry entry) {
    showLedgerDetailPage(
      context,
      entry: entry,
      onEdit: _editEntry,
      onDelete: _deleteEntry,
    );
  }

  void _editEntry(LedgerEntry entry) {
    showAddLedgerPage(
      context,
      ref: ref,
      date: entry.date,
      exchangeService: _exchangeService,
      initialEntry: entry,
      onSaved: _updateEntry,
      onCategoriesChanged: _markBillCategoriesDirty,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      markerBuilder: (date) {
        final net = _dailyNet(date);
        if (net.abs() < 0.005) return null;
        return AppDateMarker(
          label: _compactAmount(net),
          color: net < 0 ? AppColors.danger : AppColors.success,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }
}

class _Header extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onDatePick;
  final VoidCallback onStats;
  final VoidCallback? onAvatar;

  const _Header({
    required this.selectedDate,
    required this.onDatePick,
    required this.onStats,
    required this.onAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _titleForDate(selectedDate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: scheme.appText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AppIconTapButton(
                      tooltip: '选择日期',
                      onPressed: onDatePick,
                      icon: Icons.calendar_month_outlined,
                      iconSize: 24,
                      foregroundColor: scheme.appMutedText,
                    ),
                    AppIconTapButton(
                      tooltip: '统计',
                      onPressed: onStats,
                      icon: Icons.pie_chart_rounded,
                      iconSize: 24,
                      foregroundColor: scheme.appMutedText,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '人生苦短，钱途漫漫，省钱是王道。',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: scheme.appMutedText,
                  ),
                ),
              ],
            ),
          ),
          ProfileAvatarButton(onTap: onAvatar),
        ],
      ),
    );
  }

  String _titleForDate(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) return '记账';
    return '${date.year}年${date.month}月${date.day}日 记账';
  }
}

class _LedgerDayView extends StatelessWidget {
  final List<LedgerEntry> entries;
  final DateTime selectedDate;
  final double expense;
  final double income;
  final ValueChanged<LedgerEntry> onEntryTap;
  final ValueChanged<LedgerEntry> onEntryDelete;

  const _LedgerDayView({
    required this.entries,
    required this.selectedDate,
    required this.expense,
    required this.income,
    required this.onEntryTap,
    required this.onEntryDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 104),
      children: [
        _SummaryCard(
          selectedDate: selectedDate,
          expense: expense,
          income: income,
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '${selectedDate.month}月${selectedDate.day}日 账单',
          trailing: Text(
            '共 ${entries.length} 笔',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          child: entries.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      '这一天还没有账单',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : Column(
                  children: entries
                      .map(
                        (entry) => _LedgerSwipeActions(
                          onEdit: () => onEntryTap(entry),
                          onDelete: () => _confirmDeleteEntry(context, entry),
                          child: _LedgerRow(
                            entry,
                            onTap: () => onEntryTap(entry),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteEntry(
    BuildContext context,
    LedgerEntry entry,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账单'),
        content: Text(
          '确定删除「${_ledgerCategoryTitle(entry)} ${_money(entry.cnyAmount)}」吗？',
        ),
        actions: [
          AppDialogActionButton(
            label: '取消',
            tone: AppActionButtonTone.neutral,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppDialogActionButton(
            label: '删除',
            tone: AppActionButtonTone.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (ok == true) onEntryDelete(entry);
  }
}

class _SummaryCard extends StatelessWidget {
  final DateTime selectedDate;
  final double expense;
  final double income;

  const _SummaryCard({
    required this.selectedDate,
    required this.expense,
    required this.income,
  });

  @override
  Widget build(BuildContext context) {
    final balance = income - expense;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: scheme.isDarkTheme ? 0.16 : 0.10),
          scheme.appSurface,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.appBorder.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selectedDate.month}月${selectedDate.day}日账单结余 ${_money(balance)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: scheme.appText,
            ),
          ),
          const Divider(height: 24),
          Row(
            children: [
              Text(
                '收支数据',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.appText,
                ),
              ),
              const Spacer(),
              Text('消费 ${_money(expense)}'),
              const SizedBox(width: 12),
              Text(
                '收入 ${_money(income)}',
                style: const TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void showLedgerDetailPage(
  BuildContext context, {
  required LedgerEntry entry,
  required ValueChanged<LedgerEntry> onEdit,
  required ValueChanged<LedgerEntry> onDelete,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭账单详情',
    barrierColor: Colors.black.withValues(alpha: 0.12),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _LedgerDetailPage(
        entry: entry,
        onEdit: onEdit,
        onDelete: onDelete,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      );
    },
  );
}

class _LedgerDetailPage extends StatelessWidget {
  final LedgerEntry entry;
  final ValueChanged<LedgerEntry> onEdit;
  final ValueChanged<LedgerEntry> onDelete;

  const _LedgerDetailPage({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账单'),
        content: Text(
          '确定删除「${_ledgerCategoryTitle(entry)} ${_money(entry.cnyAmount)}」吗？',
        ),
        actions: [
          AppDialogActionButton(
            label: '取消',
            tone: AppActionButtonTone.neutral,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppDialogActionButton(
            label: '删除',
            tone: AppActionButtonTone.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    Navigator.of(context).pop();
    onDelete(entry);
  }

  @override
  Widget build(BuildContext context) {
    final category = _ledgerCategoryForEntry(entry);
    final sign = entry.kind == LedgerKind.expense ? '-' : '+';
    final amountColor = entry.kind == LedgerKind.expense
        ? AppColors.danger
        : AppColors.success;
    final kindLabel = entry.kind == LedgerKind.expense ? '支出' : '收入';
    return EdgeSwipePop(
      child: Material(
        color: Theme.of(context).colorScheme.appPage,
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 128),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '详细信息',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.appText,
                          ),
                        ),
                      ),
                      AppRoundIconButton(
                        tooltip: '关闭',
                        icon: Icons.close_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 44),
                  Center(
                    child: _CategoryIcon(
                      category: category,
                      size: 150,
                      emoji: _resolvedLedgerEmoji(entry),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _LedgerDetailMainCard(
                    entry: entry,
                    category: category,
                    sign: sign,
                    amountColor: amountColor,
                    kindLabel: kindLabel,
                  ),
                  const SizedBox(height: 18),
                  _LedgerDetailInfoCard(entry: entry),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppFloatingActionBar(
                  actions: [
                    AppBottomAction(
                      label: '删除',
                      icon: Icons.delete_outline_rounded,
                      onPressed: () => _confirmDelete(context),
                      tone: AppActionButtonTone.danger,
                    ),
                    AppBottomAction(
                      label: '编辑账单',
                      icon: Icons.edit_rounded,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onEdit(entry);
                      },
                      tone: AppActionButtonTone.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerDetailMainCard extends StatelessWidget {
  final LedgerEntry entry;
  final LedgerCategory category;
  final String sign;
  final Color amountColor;
  final String kindLabel;

  const _LedgerDetailMainCard({
    required this.entry,
    required this.category,
    required this.sign,
    required this.amountColor,
    required this.kindLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: scheme.appSurface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: scheme.appBorder.withValues(alpha: 0.58)),
        boxShadow: scheme.isDarkTheme ? null : AppAnimations.elevatedShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryIcon(
                category: category,
                size: 42,
                emoji: _resolvedLedgerEmoji(entry),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _ledgerCategoryTitle(entry),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: scheme.appText,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _LedgerKindPill(label: kindLabel, color: amountColor),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            '$sign${entry.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              color: amountColor,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.appInput,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              entry.note.isEmpty ? '这笔账单暂时没有备注，当前重点展示金额、时间和分类信息。' : entry.note,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w700,
                color: scheme.appMutedText,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _LedgerDetailInfoTile(
                  title: '账单时间',
                  value: _formatLedgerDateTime(entry.date),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LedgerDetailInfoTile(
                  title: '商品概览',
                  value: entry.note.isEmpty ? '无商品明细' : entry.note,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerDetailInfoCard extends ConsumerWidget {
  final LedgerEntry entry;

  const _LedgerDetailInfoCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(profileProvider);
    final recorder = profile.name.trim().isEmpty ? '本地用户' : profile.name;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: scheme.appSurface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: scheme.appBorder.withValues(alpha: 0.58)),
        boxShadow: scheme.isDarkTheme ? null : AppAnimations.elevatedShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '详细信息',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '账单档案',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _LedgerDetailLine(label: '记账人', value: recorder),
          _LedgerDetailLine(label: '账单分类', value: _ledgerCategoryTitle(entry)),
          _LedgerDetailLine(
            label: '金额',
            value: '${entry.currency} ${entry.amount.toStringAsFixed(2)}',
          ),
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry.tags
                  .map(
                    (tag) => TagChip.fromTag(
                      label: tag.name,
                      colorKey: tag.colorKey,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _LedgerKindPill extends StatelessWidget {
  final String label;
  final Color color;

  const _LedgerKindPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: scheme.isDarkTheme ? 0.18 : 0.1),
          scheme.appSurface,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}

class _LedgerDetailInfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _LedgerDetailInfoTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.appInput,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.appBorder.withValues(alpha: 0.52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: scheme.appMutedText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: scheme.appText,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _LedgerDetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.appMutedText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: scheme.appText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showStatsPage(BuildContext context, {required List<LedgerEntry> entries}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭统计',
    barrierColor: Colors.black.withValues(alpha: 0.12),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _StatsPage(entries: entries);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      );
    },
  );
}

class _StatsPage extends StatefulWidget {
  final List<LedgerEntry> entries;

  const _StatsPage({required this.entries});

  @override
  State<_StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<_StatsPage> {
  final _queryController = TextEditingController();
  var _query = '';
  String? _category;
  int? _bucketIndex;
  var _period = _StatsPeriod.year;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<LedgerEntry> get _visible {
    return widget.entries.where((item) {
      if (!_matchesPeriod(item)) return false;
      if (_category != null && _ledgerPrimaryName(item) != _category) {
        return false;
      }
      if (_bucketIndex != null && !_matchesBucket(item, _bucketIndex!)) {
        return false;
      }
      return _matchesQuery(item);
    }).toList();
  }

  List<LedgerEntry> get _pieEntries {
    return widget.entries.where((item) {
      if (!_matchesPeriod(item)) return false;
      if (_bucketIndex != null && !_matchesBucket(item, _bucketIndex!)) {
        return false;
      }
      return _matchesQuery(item);
    }).toList();
  }

  List<LedgerEntry> get _periodChartEntries {
    return widget.entries.where((item) {
      if (!_matchesPeriod(item)) return false;
      if (_category != null && _ledgerPrimaryName(item) != _category) {
        return false;
      }
      return _matchesQuery(item);
    }).toList();
  }

  bool _matchesQuery(LedgerEntry item) {
    if (_query.isEmpty) return true;
    return _ledgerCategoryTitle(item).contains(_query) ||
        _ledgerPrimaryName(item).contains(_query) ||
        (_ledgerSecondaryName(item) ?? '').contains(_query) ||
        item.note.contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final income = _sumEntries(visible, LedgerKind.income);
    final expense = _sumEntries(visible, LedgerKind.expense);
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Material(
          color: AppColors.scaffoldBg,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 18, 10),
                  child: Row(
                    children: [
                      AppIconTapButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icons.arrow_back_ios_new_rounded,
                        size: 50,
                        iconSize: 22,
                        backgroundColor: AppColors.inputBg,
                        foregroundColor: AppColors.text,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SegmentedButton<_StatsPeriod>(
                          segments: const [
                            ButtonSegment(
                              value: _StatsPeriod.month,
                              label: Text('月视图'),
                            ),
                            ButtonSegment(
                              value: _StatsPeriod.year,
                              label: Text('年度视图'),
                            ),
                          ],
                          selected: {_period},
                          onSelectionChanged: (value) {
                            setState(() {
                              _period = value.first;
                              _bucketIndex = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: _showStatsFilter,
                        icon: const Icon(Icons.format_list_bulleted_rounded),
                        label: const Text('筛选'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: Row(
                    children: [
                      _StatsAmount(
                        label: '收',
                        value: income,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 18),
                      _StatsAmount(
                        label: '支',
                        value: expense,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 18),
                      _StatsAmount(
                        label: '损',
                        value: income - expense,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
                if (_category != null ||
                    _query.isNotEmpty ||
                    _bucketIndex != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        avatar: const Icon(Icons.filter_alt_rounded, size: 18),
                        label: Text(
                          [
                            ?_category,
                            if (_bucketIndex != null)
                              _bucketLabel(_bucketIndex!),
                            if (_query.isNotEmpty) '搜索：$_query',
                          ].join(' · '),
                        ),
                        onDeleted: () {
                          setState(() {
                            _category = null;
                            _bucketIndex = null;
                            _query = '';
                            _queryController.clear();
                          });
                        },
                      ),
                    ),
                  ),
                Expanded(
                  child: _StatsView(
                    entries: visible,
                    pieEntries: _pieEntries,
                    periodEntries: _periodChartEntries,
                    period: _period,
                    selectedCategory: _category,
                    selectedBucketIndex: _bucketIndex,
                    onCategorySelected: _selectCategory,
                    onBucketSelected: _selectBucket,
                    onCategoryDetails: _showCategoryDetail,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({DateTime start, DateTime end}) _periodRange(_StatsPeriod period) {
    final now = DateTime.now();
    return switch (period) {
      _StatsPeriod.month => (
        start: DateTime(now.year, now.month),
        end: DateTime(now.year, now.month + 1),
      ),
      _StatsPeriod.year => (
        start: DateTime(now.year),
        end: DateTime(now.year + 1),
      ),
    };
  }

  double _sumEntries(List<LedgerEntry> entries, LedgerKind kind) {
    return entries
        .where((item) => item.kind == kind)
        .fold(0.0, (sum, item) => sum + item.cnyAmount);
  }

  bool _matchesPeriod(LedgerEntry item) {
    final range = _periodRange(_period);
    final d = DateTime(item.date.year, item.date.month, item.date.day);
    return !d.isBefore(range.start) && d.isBefore(range.end);
  }

  bool _matchesBucket(LedgerEntry item, int index) {
    return _bucketIndexFor(item.date) == index;
  }

  int _bucketIndexFor(DateTime date) {
    return switch (_period) {
      _StatsPeriod.year => date.month - 1,
      _StatsPeriod.month => (date.day - 1) ~/ 5,
    };
  }

  String _bucketLabel(int index) {
    return switch (_period) {
      _StatsPeriod.year => '${index + 1}月',
      _StatsPeriod.month =>
        '${index * 5 + 1}-${math.min(index * 5 + 5, DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day)}日',
    };
  }

  void _selectCategory(String? category) {
    setState(() {
      _category = category;
      _query = '';
      _queryController.clear();
    });
  }

  void _selectBucket(int? index) {
    setState(() => _bucketIndex = index);
  }

  Future<void> _showCategoryDetail(String category) async {
    final items =
        _visible.where((item) => _ledgerPrimaryName(item) == category).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final income = _sumEntries(items, LedgerKind.income);
    final expense = _sumEntries(items, LedgerKind.expense);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭明细',
      barrierColor: Colors.black.withValues(alpha: 0.12),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Material(
              color: AppColors.scaffoldBg,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 14, 14, 10),
                      child: Row(
                        children: [
                          Text(
                            '$category 明细',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          AppRoundIconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icons.close_rounded,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                      child: Row(
                        children: [
                          _StatsAmount(
                            label: '收',
                            value: income,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 18),
                          _StatsAmount(
                            label: '支',
                            value: expense,
                            color: AppColors.danger,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final entry = items[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: _LedgerRow(entry),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  Future<void> _showStatsFilter() async {
    final categories =
        widget.entries
            .where((item) => item.kind == LedgerKind.expense)
            .map(_ledgerPrimaryName)
            .toSet()
            .toList()
          ..sort();
    final queryController = TextEditingController(text: _query);
    var category = _category;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭筛选',
      barrierColor: Colors.black.withValues(alpha: 0.12),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Material(
                  color: AppColors.surface,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AppIconTapButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icons.arrow_back_ios_new_rounded,
                                size: 50,
                                iconSize: 22,
                                backgroundColor: AppColors.inputBg,
                                foregroundColor: AppColors.text,
                              ),
                              const SizedBox(width: 14),
                              const Text(
                                '分类筛选',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: queryController,
                            decoration: InputDecoration(
                              hintText: '搜索分类或备注',
                              filled: true,
                              fillColor: AppColors.inputBg,
                              prefixIcon: const Icon(Icons.search_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  ChoiceChip(
                                    label: const Text('全部分类'),
                                    selected: category == null,
                                    onSelected: (_) =>
                                        setSheetState(() => category = null),
                                  ),
                                  ...categories.map(
                                    (item) => ChoiceChip(
                                      label: Text(item),
                                      selected: category == item,
                                      onSelected: (_) =>
                                          setSheetState(() => category = item),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: AppDialogActionButton(
                              label: '应用',
                              filled: true,
                              height: 52,
                              onPressed: () {
                                setState(() {
                                  _query = queryController.text.trim();
                                  _category = category;
                                });
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
    queryController.dispose();
  }
}

enum _StatsPeriod { month, year }

class _StatsView extends StatelessWidget {
  final List<LedgerEntry> entries;
  final List<LedgerEntry> pieEntries;
  final List<LedgerEntry> periodEntries;
  final _StatsPeriod period;
  final String? selectedCategory;
  final int? selectedBucketIndex;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<int?> onBucketSelected;
  final ValueChanged<String> onCategoryDetails;

  const _StatsView({
    required this.entries,
    required this.pieEntries,
    required this.periodEntries,
    required this.period,
    required this.selectedCategory,
    required this.selectedBucketIndex,
    required this.onCategorySelected,
    required this.onBucketSelected,
    required this.onCategoryDetails,
  });

  @override
  Widget build(BuildContext context) {
    final expense = _sum(entries, LedgerKind.expense);
    final majorChartGrouped = <String, double>{};
    for (final item in pieEntries.where((e) => e.kind == LedgerKind.expense)) {
      final major = _ledgerPrimaryName(item);
      majorChartGrouped[major] =
          (majorChartGrouped[major] ?? 0) + item.cnyAmount;
    }
    final subChartGrouped = <String, double>{};
    final subChartSource = pieEntries.where((item) {
      if (item.kind != LedgerKind.expense) return false;
      if (selectedCategory == null) return true;
      return _ledgerPrimaryName(item) == selectedCategory;
    });
    for (final item in subChartSource) {
      final sub = _ledgerSubCategoryChartName(item);
      subChartGrouped[sub] = (subChartGrouped[sub] ?? 0) + item.cnyAmount;
    }
    final grouped = <String, double>{};
    final emojis = <String, String>{};
    for (final item in entries.where((e) => e.kind == LedgerKind.expense)) {
      final key = selectedCategory == null
          ? _ledgerPrimaryName(item)
          : _ledgerSubCategoryChartName(item);
      grouped[key] = (grouped[key] ?? 0) + item.cnyAmount;
      emojis[key] = selectedCategory == null
          ? _findCategory(key).emoji
          : _resolvedLedgerEmoji(item);
    }
    final rows = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 104),
      children: [
        _StatsChartCard(
          title: '支出分类占比',
          height: 330,
          child: _DualCategoryDonutCharts(
            majorData: majorChartGrouped,
            subData: subChartGrouped,
            selectedMajor: selectedCategory,
            onMajorSelected: onCategorySelected,
          ),
        ),
        const SizedBox(height: 18),
        _StatsChartCard(
          title: period == _StatsPeriod.year ? '每月收支' : '本月收支',
          height: 240,
          child: _InteractivePeriodChart(
            entries: periodEntries,
            period: period,
            selectedIndex: selectedBucketIndex,
            onSelected: onBucketSelected,
          ),
        ),
        const SizedBox(height: 22),
        ...rows.map((row) {
          final cat = _findCategory(row.key);
          final pct = expense == 0 ? 0.0 : row.value / expense * 100;
          return _StatCategoryRow(
            label: row.key,
            category: cat,
            emoji: emojis[row.key],
            amount: row.value,
            percent: pct,
            onTap: () => onCategoryDetails(selectedCategory ?? row.key),
          );
        }),
      ],
    );
  }

  double _sum(List<LedgerEntry> items, LedgerKind kind) =>
      items.where((e) => e.kind == kind).fold(0, (s, e) => s + e.cnyAmount);
}

class _StatsAmount extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _StatsAmount({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '¥ ${value.toStringAsFixed(2)}',
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StatsChartCard extends StatelessWidget {
  final String title;
  final double height;
  final Widget child;

  const _StatsChartCard({
    required this.title,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: scheme.appSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.appBorder.withValues(alpha: 0.58)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 5, height: 24, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: SizedBox.expand(child: child)),
        ],
      ),
    );
  }
}

class _DualCategoryDonutCharts extends StatelessWidget {
  final Map<String, double> majorData;
  final Map<String, double> subData;
  final String? selectedMajor;
  final ValueChanged<String?> onMajorSelected;

  const _DualCategoryDonutCharts({
    required this.majorData,
    required this.subData,
    required this.selectedMajor,
    required this.onMajorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _StatsDonutPane(
            title: '大分类',
            data: majorData,
            selected: selectedMajor,
            onSelected: onMajorSelected,
            titleColor: scheme.appText,
          ),
        ),
        Container(
          width: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: scheme.appBorder.withValues(alpha: 0.72),
        ),
        Expanded(
          child: _StatsDonutPane(
            title: selectedMajor == null ? '子分类' : '$selectedMajor 子分类',
            data: subData,
            selected: null,
            onSelected: (_) {},
            titleColor: scheme.appText,
          ),
        ),
      ],
    );
  }
}

class _StatsDonutPane extends StatelessWidget {
  final String title;
  final Map<String, double> data;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final Color titleColor;

  const _StatsDonutPane({
    required this.title,
    required this.data,
    required this.selected,
    required this.onSelected,
    required this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: SizedBox.expand(
            child: _InteractiveDonutChart(
              data: data,
              selectedCategory: selected,
              onSelected: onSelected,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCategoryRow extends StatelessWidget {
  final String label;
  final LedgerCategory category;
  final String? emoji;
  final double amount;
  final double percent;
  final VoidCallback onTap;

  const _StatCategoryRow({
    required this.label,
    required this.category,
    this.emoji,
    required this.amount,
    required this.percent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: scheme.appSurface,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Row(
              children: [
                _CategoryIcon(category: category, size: 58, emoji: emoji),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${percent.toStringAsFixed(1)}%  |  ${_money(amount)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.appSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.appBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.appText,
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LedgerSwipeActions extends StatefulWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget child;

  const _LedgerSwipeActions({
    required this.onEdit,
    required this.onDelete,
    required this.child,
  });

  @override
  State<_LedgerSwipeActions> createState() => _LedgerSwipeActionsState();
}

class _LedgerSwipeActionsState extends State<_LedgerSwipeActions>
    with SingleTickerProviderStateMixin {
  static const double _actionWidth = 74.0;
  double _offset = 0;
  bool _dragging = false;
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation =
        Tween<double>(begin: 0, end: 0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        )..addListener(() {
          if (!_dragging) setState(() => _offset = _animation.value);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _animation = Tween<double>(
      begin: _offset,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Row(
            children: [
              if (_offset > 8)
                _LedgerSwipeButton(
                  icon: Icons.edit_rounded,
                  color: AppColors.primary,
                  onTap: () {
                    _animateTo(0);
                    widget.onEdit();
                  },
                ),
              const Spacer(),
              if (_offset < -8)
                _LedgerSwipeButton(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  onTap: () {
                    _animateTo(0);
                    widget.onDelete();
                  },
                ),
            ],
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => _dragging = true,
          onHorizontalDragUpdate: (details) {
            setState(() {
              _offset += details.delta.dx;
              if (_offset > _actionWidth) _offset = _actionWidth;
              if (_offset < -_actionWidth) _offset = -_actionWidth;
            });
          },
          onHorizontalDragEnd: (_) {
            _dragging = false;
            if (_offset.abs() > 42) {
              _animateTo(_offset > 0 ? _actionWidth : -_actionWidth);
            } else {
              _animateTo(0);
            }
          },
          child: Transform.translate(
            offset: Offset(_offset, 0),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _LedgerSwipeButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _LedgerSwipeButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _LedgerSwipeActionsState._actionWidth,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color.withValues(alpha: 0.26)),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final LedgerEntry entry;
  final VoidCallback? onTap;

  const _LedgerRow(this.entry, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = _ledgerCategoryForEntry(entry);
    final sign = entry.kind == LedgerKind.expense ? '-' : '+';
    final color = entry.kind == LedgerKind.expense
        ? AppColors.danger
        : AppColors.success;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              _CategoryIcon(
                category: cat,
                size: 50,
                emoji: _resolvedLedgerEmoji(entry),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _ledgerCategoryTitle(entry),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: scheme.appText,
                          ),
                        ),
                        if (entry.aiGenerated) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    if (entry.note.isNotEmpty)
                      Text(
                        '备注：${entry.note}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                        ).copyWith(color: scheme.appMutedText),
                      ),
                    if (entry.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: entry.tags
                            .take(3)
                            .map(
                              (tag) => TagChip.fromTag(
                                label: tag.name,
                                colorKey: tag.colorKey,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '$sign${_money(entry.cnyAmount)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final LedgerCategory category;
  final double size;
  final String? emoji;

  const _CategoryIcon({required this.category, required this.size, this.emoji});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = scheme.isDarkTheme
        ? Color.alphaBlend(
            category.color.withValues(alpha: 0.22),
            scheme.appSurface,
          )
        : category.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: category.color.withValues(
            alpha: scheme.isDarkTheme ? 0.42 : 0.75,
          ),
        ),
      ),
      child: Center(
        child: Text(
          emoji ?? category.emoji,
          style: TextStyle(fontSize: size * 0.36),
        ),
      ),
    );
  }
}

void showAddLedgerPage(
  BuildContext context, {
  required WidgetRef ref,
  required DateTime date,
  required ExchangeService exchangeService,
  required FutureOr<void> Function(LedgerEntry entry) onSaved,
  LedgerEntry? initialEntry,
  VoidCallback? onCategoriesChanged,
  String? initialVoiceText,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.12),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _AddLedgerPage(
        ref: ref,
        date: date,
        exchangeService: exchangeService,
        onSaved: onSaved,
        initialEntry: initialEntry,
        onCategoriesChanged: onCategoriesChanged,
        initialVoiceText: initialVoiceText,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      );
    },
  );
}

class _AddLedgerPage extends StatefulWidget {
  final WidgetRef ref;
  final DateTime date;
  final ExchangeService exchangeService;
  final FutureOr<void> Function(LedgerEntry entry) onSaved;
  final LedgerEntry? initialEntry;
  final VoidCallback? onCategoriesChanged;
  final String? initialVoiceText;

  const _AddLedgerPage({
    required this.ref,
    required this.date,
    required this.exchangeService,
    required this.onSaved,
    this.initialEntry,
    this.onCategoriesChanged,
    this.initialVoiceText,
  });

  @override
  State<_AddLedgerPage> createState() => _AddLedgerPageState();
}

class _AddLedgerPageState extends State<_AddLedgerPage>
    with TickerProviderStateMixin {
  final _noteController = TextEditingController();
  final _speech = stt.SpeechToText();
  var _kind = LedgerKind.expense;
  var _category = _expenseCategories.first;
  LedgerCategory? _expenseParent;
  var _amountText = '';
  var _currency = 'CNY';
  var _aiGenerated = false;
  var _tags = <Tag>[];
  var _customCategories = <LedgerCategory>[];
  var _saving = false;
  var _showAllCategories = false;
  var _speechReady = false;
  var _listening = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEntry;
    if (initial != null) {
      final resolvedCategory = _ledgerCategoryForEntry(initial);
      final group = initial.kind == LedgerKind.expense
          ? _expenseGroupForValue(initial.categoryId) ??
                _expenseGroupForValue(initial.categoryName) ??
                _expenseGroupForCategory(resolvedCategory)
          : null;
      _kind = initial.kind;
      _category = resolvedCategory;
      _expenseParent = group?.primary;
      _amountText = _formatAmount(initial.amount);
      _currency = initial.currency;
      _aiGenerated = initial.aiGenerated;
      _tags = List.from(initial.tags);
      _noteController.text = initial.note;
      _showAllCategories = initial.kind == LedgerKind.income;
    }
    final initialVoiceText = widget.initialVoiceText?.trim() ?? '';
    if (initialVoiceText.isNotEmpty && initial == null) {
      _noteController.text = initialVoiceText;
      _aiGenerated = true;
    }
    Future.microtask(() async {
      await _loadCustomCategories();
      if (initialVoiceText.isNotEmpty && mounted && initial == null) {
        await _parseLedgerText(initialVoiceText);
      }
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() => _listening = status == 'listening');
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    setState(() => _speechReady = available);
  }

  Future<void> _toggleVoiceInput() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      final text = _noteController.text.trim();
      if (text.isNotEmpty) await _parseLedgerText(text);
      return;
    }
    if (!_speechReady) {
      await _initSpeech();
    }
    if (!_speechReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前设备暂不可用语音识别，请检查麦克风/语音识别权限')),
        );
      }
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: _handleSpeechResult,
      listenOptions: stt.SpeechListenOptions(
        localeId: 'zh_CN',
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleSpeechResult(SpeechRecognitionResult result) async {
    final text = result.recognizedWords.trim();
    if (!mounted || text.isEmpty) return;
    setState(() {
      _noteController.text = text;
      _noteController.selection = TextSelection.collapsed(
        offset: _noteController.text.length,
      );
      _aiGenerated = true;
      if (result.finalResult) _listening = false;
    });
    if (result.finalResult) {
      await _parseLedgerText(text);
    }
  }

  Future<void> _loadCustomCategories() async {
    final items = await widget.exchangeService.store.loadCustomCategories();
    if (!mounted) return;
    setState(() {
      _customCategories = items;
      final initial = widget.initialEntry;
      if (initial != null) {
        _category = _categoriesFor(initial.kind).firstWhere(
          (item) => item.id == initial.categoryId,
          orElse: () => _category,
        );
        if (initial.kind == LedgerKind.expense && _expenseParent == null) {
          _expenseParent =
              _expenseGroupForCategory(_category)?.primary ??
              _customExpensePrimaryCategory;
        }
      }
    });
  }

  Future<void> _parseLedgerText(String text) async {
    final parsed = await _aiParse(text) ?? _localParse(text);
    if (!mounted) return;
    final cats = _categoriesFor(parsed.kind);
    final nextCategory = cats.firstWhere(
      (item) =>
          item.name == parsed.categoryName ||
          ledgerCategoryDisplayNameForSelection(item) == parsed.categoryName,
      orElse: () => cats.first,
    );
    setState(() {
      _kind = parsed.kind;
      _category = nextCategory;
      _expenseParent = parsed.kind == LedgerKind.expense
          ? (_expenseGroupForCategory(nextCategory)?.primary ??
                _customExpensePrimaryCategory)
          : null;
      _amountText = parsed.amount.toStringAsFixed(
        parsed.amount.truncateToDouble() == parsed.amount ? 0 : 2,
      );
      _currency = parsed.currency;
      _noteController.text = parsed.note;
      _aiGenerated = true;
    });
  }

  Future<_ParsedLedger?> _aiParse(String text) async {
    final config = widget.ref.read(aiModelProvider).selected;
    if (config == null ||
        config.apiKey.trim().isEmpty ||
        config.baseUrl.trim().isEmpty ||
        config.model.trim().isEmpty) {
      return null;
    }
    try {
      final expenseNames = _categoriesFor(
        LedgerKind.expense,
      ).map((item) => item.name).join('、');
      final incomeNames = _categoriesFor(
        LedgerKind.income,
      ).map((item) => item.name).join('、');
      final reply = await OpenAiCompatibleClient().chat(
        config: config,
        messages: [
          LlmChatMessage(
            role: 'system',
            content:
                '你是记账识别器，只返回 JSON。字段 kind(expense/income), amount(number), currency(CNY/USD/EUR/JPY/HKD/GBP/KRW), categoryName, note。默认 kind=expense。支出分类只能从这些名称中选：$expenseNames；收入分类只能从这些名称中选：$incomeNames。',
          ),
          LlmChatMessage(role: 'user', content: text),
        ],
      );
      final jsonText =
          RegExp(r'\{[\s\S]*\}').firstMatch(reply)?.group(0) ?? reply;
      final data = jsonDecode(jsonText) as Map<String, dynamic>;
      return _ParsedLedger(
        kind: data['kind'] == 'income' ? LedgerKind.income : LedgerKind.expense,
        amount: (data['amount'] as num?)?.toDouble() ?? _extractAmount(text),
        currency: _validCurrency(data['currency'] as String?),
        categoryName:
            data['categoryName'] as String? ?? _guessCategory(text).name,
        note: data['note'] as String? ?? text,
      );
    } catch (_) {
      return null;
    }
  }

  _ParsedLedger _localParse(String text) {
    return _ParsedLedger(
      kind: RegExp('收入|工资|奖金|兼职|投资收益|股票|基金|利息|租金|退款|红包收入').hasMatch(text)
          ? LedgerKind.income
          : LedgerKind.expense,
      amount: _extractAmount(text),
      currency: _detectCurrency(text),
      categoryName: _guessCategory(text).name,
      note: text,
    );
  }

  double _extractAmount(String text) {
    final unitMatch = RegExp(
      r'((?:[¥￥]\s*)\d+(?:\.\d+)?|\d+(?:\.\d+)?\s*(?:元|块|人民币|rmb|cny))',
      caseSensitive: false,
    ).allMatches(text).lastOrNull;
    if (unitMatch != null) {
      final amount = RegExp(r'\d+(?:\.\d+)?').firstMatch(unitMatch.group(0)!);
      return double.tryParse(amount?.group(0) ?? '') ?? 0;
    }

    final decimalMatch = RegExp(r'\d+\.\d+').allMatches(text).lastOrNull;
    if (decimalMatch != null) {
      return double.tryParse(decimalMatch.group(0) ?? '') ?? 0;
    }

    final match = RegExp(r'\d+(?:\.\d+)?').allMatches(text).lastOrNull;
    return double.tryParse(match?.group(0) ?? '') ?? 0;
  }

  String _detectCurrency(String text) {
    if (text.contains('美元') || text.toUpperCase().contains('USD')) return 'USD';
    if (text.contains('欧元') || text.toUpperCase().contains('EUR')) return 'EUR';
    if (text.contains('日元') || text.toUpperCase().contains('JPY')) return 'JPY';
    if (text.contains('港币') || text.toUpperCase().contains('HKD')) return 'HKD';
    if (text.contains('英镑') || text.toUpperCase().contains('GBP')) return 'GBP';
    if (text.contains('韩元') || text.toUpperCase().contains('KRW')) return 'KRW';
    return 'CNY';
  }

  String _validCurrency(String? value) {
    final normalized = (value ?? 'CNY').toUpperCase();
    return _currencyCodes.contains(normalized) ? normalized : 'CNY';
  }

  LedgerCategory _guessCategory(String text) {
    final all = [
      ..._expenseCategories,
      ..._incomeCategories,
      ..._customCategories,
    ];
    for (final item in all) {
      if (text.contains(item.name)) return item;
    }
    if (RegExp('红包收入').hasMatch(text)) return _findCategory('红包收入');
    if (RegExp('租金收入').hasMatch(text)) return _findCategory('租金收入');
    if (RegExp('早餐|早饭|包子|豆浆|油条').hasMatch(text)) return _findCategory('早餐');
    if (RegExp('外卖|饿了么|美团').hasMatch(text)) return _findCategory('外卖');
    if (RegExp('咖啡|奶茶|茶饮|瑞幸|星巴克').hasMatch(text)) {
      if (RegExp('奶茶|茶饮').hasMatch(text)) return _findCategory('奶茶');
      return _findCategory('咖啡');
    }
    if (RegExp('地铁').hasMatch(text)) return _findCategory('地铁');
    if (RegExp('公交').hasMatch(text)) return _findCategory('公交');
    if (RegExp('高铁|火车').hasMatch(text)) return _findCategory('火车');
    if (RegExp('机票|飞机|航班').hasMatch(text)) return _findCategory('飞机');
    if (RegExp('加油|油费').hasMatch(text)) return _findCategory('加油');
    if (RegExp('停车').hasMatch(text)) return _findCategory('停车');
    if (RegExp('高速|过路费').hasMatch(text)) return _findCategory('高速费');
    if (RegExp('单车|共享单车').hasMatch(text)) return _findCategory('共享单车');
    if (RegExp('交通|车费').hasMatch(text)) return _findCategory('交通');
    if (RegExp('打车|滴滴|出租|网约车').hasMatch(text)) return _findCategory('打车');
    if (RegExp('午餐|午饭').hasMatch(text)) return _findCategory('午餐');
    if (RegExp('晚餐|晚饭|夜宵').hasMatch(text)) return _findCategory('晚餐');
    if (RegExp('买菜|菜场|蔬菜|水果').hasMatch(text)) return _findCategory('买菜');
    if (RegExp('聚餐|请吃饭').hasMatch(text)) return _findCategory('聚餐');
    if (RegExp('零食|饮料').hasMatch(text)) return _findCategory('零食');
    if (RegExp('饭|餐|食堂|餐厅').hasMatch(text)) return _findCategory('三餐');
    if (RegExp('超市|商场|淘宝|京东|拼多多|购物').hasMatch(text)) {
      return _findCategory('购物');
    }
    if (RegExp('日用品|纸巾|洗衣液').hasMatch(text)) return _findCategory('日用品');
    if (RegExp('衣服|鞋|裤|帽|服饰').hasMatch(text)) return _findCategory('衣服鞋帽');
    if (RegExp('手机|电脑|耳机|数码|软件|订阅').hasMatch(text)) {
      return _findCategory('数码产品');
    }
    if (RegExp('家居|家具').hasMatch(text)) return _findCategory('家居用品');
    if (RegExp('网购|淘宝|京东|拼多多').hasMatch(text)) return _findCategory('网购');
    if (RegExp('美妆|护肤|口红').hasMatch(text)) return _findCategory('美妆护肤');
    if (RegExp('房租|租房|房贷').hasMatch(text)) return _findCategory('房租');
    if (RegExp('物业').hasMatch(text)) return _findCategory('物业');
    if (RegExp('水费').hasMatch(text)) return _findCategory('水费');
    if (RegExp('电费').hasMatch(text)) return _findCategory('电费');
    if (RegExp('燃气|煤气').hasMatch(text)) return _findCategory('燃气');
    if (RegExp('宽带|网费').hasMatch(text)) return _findCategory('宽带');
    if (RegExp('家政|保洁').hasMatch(text)) return _findCategory('家政');
    if (RegExp('维修|修理').hasMatch(text)) return _findCategory('维修');
    if (RegExp('医院|门诊').hasMatch(text)) return _findCategory('医院');
    if (RegExp('药|药品').hasMatch(text)) return _findCategory('药品');
    if (RegExp('体检').hasMatch(text)) return _findCategory('体检');
    if (RegExp('保险').hasMatch(text)) return _findCategory('保险');
    if (RegExp('健身|运动|瑜伽').hasMatch(text)) return _findCategory('健身');
    if (RegExp('跑步').hasMatch(text)) return _findCategory('跑步');
    if (RegExp('电影|演唱会|剧场').hasMatch(text)) return _findCategory('电影');
    if (RegExp('游戏').hasMatch(text)) return _findCategory('游戏');
    if (RegExp('KTV|ktv').hasMatch(text)) return _findCategory('KTV');
    if (RegExp('酒吧').hasMatch(text)) return _findCategory('酒吧');
    if (RegExp('旅游|旅行|酒店|民宿|门票').hasMatch(text)) return _findCategory('旅游');
    if (RegExp('摄影|相机').hasMatch(text)) return _findCategory('摄影');
    if (RegExp('书|课程|学习|培训').hasMatch(text)) return _findCategory('书籍');
    if (RegExp('音乐|会员').hasMatch(text)) return _findCategory('音乐');
    if (RegExp('红包').hasMatch(text)) return _findCategory('红包');
    if (RegExp('礼金').hasMatch(text)) return _findCategory('礼金');
    if (RegExp('请客').hasMatch(text)) return _findCategory('请客');
    if (RegExp('聚会').hasMatch(text)) return _findCategory('聚会');
    if (RegExp('恋爱|约会').hasMatch(text)) return _findCategory('恋爱');
    if (RegExp('狗粮').hasMatch(text)) return _findCategory('狗粮');
    if (RegExp('猫粮').hasMatch(text)) return _findCategory('猫粮');
    if (RegExp('宠物').hasMatch(text)) return _findCategory('宠物');
    if (RegExp('工资|薪资|薪水').hasMatch(text)) return _findCategory('工资');
    if (RegExp('奖金|年终奖').hasMatch(text)) return _findCategory('奖金');
    if (RegExp('兼职|副业|接单').hasMatch(text)) return _findCategory('兼职');
    if (RegExp('股票').hasMatch(text)) return _findCategory('股票');
    if (RegExp('基金').hasMatch(text)) return _findCategory('基金');
    if (RegExp('利息').hasMatch(text)) return _findCategory('利息');
    if (RegExp('理财|收益|分红|投资收益').hasMatch(text)) return _findCategory('投资收益');
    if (RegExp('租金').hasMatch(text)) return _findCategory('租金收入');
    if (RegExp('退款|退回').hasMatch(text)) return _findCategory('退款');
    if (RegExp('红包收入').hasMatch(text)) return _findCategory('红包收入');
    if (RegExp('收入|到账|转账').hasMatch(text)) return _incomeCategories.first;
    return _customExpensePrimaryCategory;
  }

  void _tapNumber(String value) {
    setState(() {
      if (value == 'del') {
        if (_amountText.isNotEmpty) {
          _amountText = _amountText.substring(0, _amountText.length - 1);
        }
      } else if (value == '=') {
        _amountText = _formatAmount(_evaluateAmount(_amountText));
      } else if (value == '+' || value == '-') {
        if (_amountText.isNotEmpty &&
            !_amountText.endsWith('+') &&
            !_amountText.endsWith('-')) {
          _amountText += value;
        }
      } else if (value == '.') {
        final segment = _amountText.split(RegExp(r'[+-]')).last;
        if (!segment.contains('.')) _amountText += '.';
      } else {
        _amountText += value;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = _evaluateAmount(_amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效金额')));
      return;
    }
    setState(() => _saving = true);
    try {
      final rate = _currency == 'CNY'
          ? 1.0
          : (await widget.exchangeService.getRates()).toCny[_currency] ?? 1;
      final cny = amount * rate;
      final now = DateTime.now();
      final initial = widget.initialEntry;
      final entryDate = initial?.date;
      final entry = LedgerEntry(
        id: initial?.id ?? const Uuid().v4(),
        kind: _kind,
        categoryId: _category.id,
        categoryName: ledgerCategoryDisplayNameForSelection(_category),
        categoryEmoji: _category.emoji,
        note: _noteController.text.trim(),
        amount: amount,
        currency: _currency,
        cnyAmount: cny,
        tags: _tags,
        date: DateTime(
          entryDate?.year ?? widget.date.year,
          entryDate?.month ?? widget.date.month,
          entryDate?.day ?? widget.date.day,
          entryDate?.hour ?? now.hour,
          entryDate?.minute ?? now.minute,
        ),
        aiGenerated: _aiGenerated,
        createdAt: initial?.createdAt ?? now,
      );
      await widget.onSaved(entry);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('记账失败：$e')));
    }
  }

  List<LedgerCategory> _categoriesFor(LedgerKind kind) {
    final base = kind == LedgerKind.income
        ? _incomeCategories
        : _expenseCategories;
    return [...base, ..._customCategories.where((item) => item.kind == kind)];
  }

  double? _evaluateAmount(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;
    final matches = RegExp(r'([+-]?)(\d+(?:\.\d+)?)').allMatches(normalized);
    var total = 0.0;
    var found = false;
    for (final match in matches) {
      found = true;
      final sign = match.group(1) == '-' ? -1.0 : 1.0;
      final value = double.tryParse(match.group(2) ?? '');
      if (value == null) return null;
      total += sign * value;
    }
    return found ? total : null;
  }

  String _formatAmount(double? amount) {
    if (amount == null) return '';
    return amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
  }

  Future<void> _showCurrencyPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _currencyCodes.map((code) {
                return ListTile(
                  leading: Text(
                    _currencyFlag(code),
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text('$code ${_currencyName(code)}'),
                  trailing: code == _currency
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(code),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) setState(() => _currency = picked);
  }

  Future<void> _addCustomCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新增分类'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入分类名称'),
          ),
          actions: [
            AppDialogActionButton(
              label: '取消',
              tone: AppActionButtonTone.neutral,
              onPressed: () => Navigator.of(context).pop(),
            ),
            AppDialogActionButton(
              label: '保存',
              filled: true,
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final category = LedgerCategory(
      id: const Uuid().v4(),
      name: name,
      emoji: _kind == LedgerKind.income ? '💰' : '🔹',
      color: _kind == LedgerKind.income
          ? const Color(0xFFFFF7E8)
          : const Color(0xFFEAF5FF),
      kind: _kind,
    );
    final next = [..._customCategories, category];
    setState(() {
      _customCategories = next;
      _category = category;
      if (_kind == LedgerKind.expense) {
        _expenseParent = _customExpensePrimaryCategory;
      }
    });
    await widget.exchangeService.store.saveCustomCategories(next);
    widget.onCategoriesChanged?.call();
  }

  Widget _buildCategoryPicker() {
    if (_kind == LedgerKind.expense) return _buildExpenseCategoryPicker();
    return _buildFlatCategoryWrap(
      categories: _categoriesFor(LedgerKind.income),
      includeAddTile: true,
    );
  }

  Widget _buildExpenseCategoryPicker() {
    final parent = _expenseParent;
    if (parent == null) {
      return _buildFlatCategoryWrap(
        categories: _expensePrimaryCategories,
        includeAddTile: false,
        onCategoryTap: (cat) {
          setState(() {
            _expenseParent = cat;
            _category = cat;
            _showAllCategories = false;
          });
        },
      );
    }

    final group = _expenseCategoryGroups.firstWhere(
      (item) => item.primary.id == parent.id,
      orElse: () => _expenseCategoryGroups.last,
    );
    final subCategories = parent.id == _customExpensePrimaryCategory.id
        ? _customCategories
              .where((item) => item.kind == LedgerKind.expense)
              .toList()
        : group.children;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppIconTapButton(
              tooltip: '返回大分类',
              onPressed: () => setState(() => _expenseParent = null),
              icon: Icons.arrow_back_ios_new_rounded,
              size: 38,
              iconSize: 17,
              backgroundColor: Theme.of(context).colorScheme.appSurface,
              foregroundColor: Theme.of(context).colorScheme.appText,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${parent.name} 小分类',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.appText,
                ),
              ),
            ),
            Text(
              '可不选',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.appMutedText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildFlatCategoryWrap(
          categories: [parent, ...subCategories],
          includeAddTile: parent.id == _customExpensePrimaryCategory.id,
          labelFor: (cat) => cat.id == parent.id ? '不选小类' : cat.name,
          onCategoryTap: (cat) => setState(() => _category = cat),
        ),
      ],
    );
  }

  Widget _buildFlatCategoryWrap({
    required List<LedgerCategory> categories,
    required bool includeAddTile,
    String Function(LedgerCategory category)? labelFor,
    ValueChanged<LedgerCategory>? onCategoryTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = constraints.maxWidth < 340
            ? 5
            : constraints.maxWidth < 520
            ? 6
            : 7;
        final rawWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final tileWidth = rawWidth.clamp(54.0, 72.0);
        final defaultSlots = columns * 3;
        final hasHiddenItems = categories.length + 1 > defaultSlots;
        final visibleCategoryCount = _showAllCategories || !hasHiddenItems
            ? categories.length
            : math.max(0, defaultSlots - 1);
        final visibleCats = categories.take(visibleCategoryCount);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            ...visibleCats.map((cat) {
              final selected = cat.id == _category.id;
              return _CategoryPickTile(
                width: tileWidth,
                category: cat,
                label: labelFor?.call(cat),
                selected: selected,
                onTap: () => onCategoryTap == null
                    ? setState(() => _category = cat)
                    : onCategoryTap(cat),
              );
            }),
            if (includeAddTile && (_showAllCategories || !hasHiddenItems))
              _AddCategoryTile(width: tileWidth, onTap: _addCustomCategory)
            else if (hasHiddenItems && !_showAllCategories)
              _MoreCategoryTile(
                width: tileWidth,
                onTap: () => setState(() => _showAllCategories = true),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.appPage,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 10),
              child: Row(
                children: [
                  if (widget.initialEntry != null) ...[
                    Text(
                      '编辑账单',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: scheme.appText,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Row(
                      children: [
                        _KindTab(
                          label: '消费支出',
                          selected: _kind == LedgerKind.expense,
                          onTap: () => setState(() {
                            _kind = LedgerKind.expense;
                            _showAllCategories = false;
                            _expenseParent = null;
                            _category = _expensePrimaryCategories.first;
                          }),
                        ),
                        _KindTab(
                          label: '收入账单',
                          selected: _kind == LedgerKind.income,
                          onTap: () => setState(() {
                            _kind = LedgerKind.income;
                            _showAllCategories = false;
                            _expenseParent = null;
                            _category = _categoriesFor(LedgerKind.income).first;
                          }),
                        ),
                      ],
                    ),
                  ),
                  AppRoundIconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icons.close_rounded,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    children: [
                      _buildCategoryPicker(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _noteController,
                              decoration: InputDecoration(
                                hintText: '备注，例如：地铁 6 元、午餐 28 元',
                                filled: true,
                                fillColor: scheme.appSurface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: scheme.appBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: scheme.appBorder,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          AppRoundIconButton(
                            tooltip: _listening ? '停止语音输入' : '语音输入',
                            onPressed: () => unawaited(_toggleVoiceInput()),
                            icon: _listening
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            foregroundColor: _listening
                                ? AppColors.danger
                                : AppColors.primary,
                          ),
                        ],
                      ),
                      AnimatedSwitcher(
                        duration: AppPerformance.lowLatencyMode
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        child: _listening
                            ? Padding(
                                key: const ValueKey('ledger-listening'),
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _noteController.text.trim().isEmpty
                                      ? '正在听...'
                                      : '正在听：${_noteController.text.trim()}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.appMutedText,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('ledger-listening-hidden'),
                              ),
                      ),
                      const SizedBox(height: 14),
                      TagSelector(
                        selectedTags: _tags,
                        onChanged: (tags) => setState(() => _tags = tags),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.appSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: scheme.appBorder.withValues(alpha: 0.58),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '金额',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.appText,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_currency == "CNY" ? "¥" : _currency} ${_amountText.isEmpty ? "0.00" : _amountText}',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: scheme.appText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LedgerSaveButton(
                        label: _saving
                            ? '保存中'
                            : widget.initialEntry == null
                            ? '完成记账'
                            : '保存修改',
                        icon: _saving
                            ? Icons.hourglass_top_rounded
                            : Icons.check_rounded,
                        onPressed: _save,
                      ),
                      const SizedBox(height: 12),
                      _NumberPad(
                        currency: _currency,
                        onCurrencyTap: _showCurrencyPicker,
                        onTap: _tapNumber,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerSaveButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _LedgerSaveButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onPressed(),
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParsedLedger {
  final LedgerKind kind;
  final double amount;
  final String currency;
  final String categoryName;
  final String note;

  const _ParsedLedger({
    required this.kind,
    required this.amount,
    required this.currency,
    required this.categoryName,
    required this.note,
  });
}

class _CategoryPickTile extends StatelessWidget {
  final double width;
  final LedgerCategory category;
  final String? label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryPickTile({
    required this.width,
    required this.category,
    this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: width,
        padding: EdgeInsets.symmetric(vertical: width < 72 ? 8 : 10),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  category.color.withValues(
                    alpha: scheme.isDarkTheme ? 0.28 : 0.72,
                  ),
                  scheme.appSurface,
                )
              : scheme.appSurface,
          borderRadius: BorderRadius.circular(width < 72 ? 15 : 18),
          border: Border.all(
            color: selected ? scheme.primary : scheme.appBorder,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              category.emoji,
              style: TextStyle(fontSize: (width * 0.29).clamp(17.0, 22.0)),
            ),
            const SizedBox(height: 3),
            Text(
              label ?? category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PingFang SC',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.appText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCategoryTile extends StatelessWidget {
  final double width;
  final VoidCallback onTap;

  const _AddCategoryTile({required this.width, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(vertical: width < 72 ? 8 : 10),
        decoration: BoxDecoration(
          color: scheme.appSurface,
          borderRadius: BorderRadius.circular(width < 72 ? 15 : 18),
          border: Border.all(color: scheme.appBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: (width * 0.29).clamp(17.0, 22.0),
            ),
            const SizedBox(height: 4),
            Text(
              '自定义',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.appText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreCategoryTile extends StatelessWidget {
  final double width;
  final VoidCallback onTap;

  const _MoreCategoryTile({required this.width, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(vertical: width < 72 ? 8 : 10),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.08),
            scheme.appSurface,
          ),
          borderRadius: BorderRadius.circular(width < 72 ? 15 : 18),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.more_horiz_rounded,
              size: (width * 0.29).clamp(17.0, 22.0),
              color: scheme.primary,
            ),
            const SizedBox(height: 4),
            Text(
              '更多',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _KindTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: selected ? scheme.primary : scheme.appMutedText,
            decoration: selected ? TextDecoration.underline : null,
            decorationThickness: 2,
          ),
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  final String currency;
  final VoidCallback onCurrencyTap;
  final ValueChanged<String> onTap;

  const _NumberPad({
    required this.currency,
    required this.onCurrencyTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keys = [
      '1',
      '2',
      '3',
      'del',
      '4',
      '5',
      '6',
      '+',
      '7',
      '8',
      '9',
      '-',
      '.',
      '0',
      'currency',
      '=',
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.15,
      ),
      itemBuilder: (context, index) {
        final key = keys[index];
        return GestureDetector(
          onTap: () {
            if (key == 'currency') {
              onCurrencyTap();
              return;
            }
            onTap(key);
          },
          child: Container(
            decoration: BoxDecoration(
              color: key == 'del' ? const Color(0xFFFF5B45) : scheme.appSurface,
              borderRadius: BorderRadius.circular(16),
              border: key == 'del'
                  ? null
                  : Border.all(color: scheme.appBorder.withValues(alpha: 0.52)),
            ),
            child: Center(
              child: key == 'del'
                  ? const Icon(Icons.backspace_outlined, color: Colors.white)
                  : key == 'currency'
                  ? Text(
                      '${_currencyFlag(currency)} $currency',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: scheme.appText,
                      ),
                    )
                  : Text(
                      key,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: scheme.appText,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _InteractiveDonutChart extends StatelessWidget {
  final Map<String, double> data;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;

  const _InteractiveDonutChart({
    required this.data,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final hit = _hitDonut(data, box.size, details.localPosition);
        onSelected(hit);
      },
      child: TweenAnimationBuilder<double>(
        key: ValueKey(selectedCategory),
        tween: Tween(begin: 0, end: selectedCategory == null ? 0 : 1),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) {
          return CustomPaint(
            painter: _DonutChartPainter(
              data,
              selectedCategory: selectedCategory,
              progress: progress,
            ),
          );
        },
      ),
    );
  }

  String? _hitDonut(Map<String, double> values, Size size, Offset local) {
    final total = values.values.fold(0.0, (s, v) => s + v);
    if (total <= 0) return null;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.26;
    final distance = (local - center).distance;
    if (distance < radius - 24 || distance > radius + 24) return null;
    var angle = math.atan2(local.dy - center.dy, local.dx - center.dx);
    angle = (angle + math.pi / 2) % (math.pi * 2);
    var start = 0.0;
    final rows = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final item in rows) {
      final sweep = item.value / total * math.pi * 2;
      if (angle >= start && angle <= start + sweep) return item.key;
      start += sweep;
    }
    return null;
  }
}

class _InteractivePeriodChart extends StatelessWidget {
  final List<LedgerEntry> entries;
  final _StatsPeriod period;
  final int? selectedIndex;
  final ValueChanged<int?> onSelected;

  const _InteractivePeriodChart({
    required this.entries,
    required this.period,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final hit = _hitBucket(box.size, details.localPosition);
        onSelected(hit);
      },
      child: TweenAnimationBuilder<double>(
        key: ValueKey(selectedIndex),
        tween: Tween(begin: 0, end: selectedIndex == null ? 0 : 1),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) {
          return CustomPaint(
            painter: _PeriodBarPainter(
              entries: entries,
              period: period,
              selectedIndex: selectedIndex,
              progress: progress,
            ),
          );
        },
      ),
    );
  }

  int? _hitBucket(Size size, Offset local) {
    final buckets = _periodBuckets(entries, period);
    final maxValue = [
      ...buckets.income,
      ...buckets.expense,
    ].fold(1.0, math.max);
    final slot = size.width / buckets.count;
    final base = size.height - 32;
    for (var i = 0; i < buckets.count; i++) {
      final value = math.max(buckets.income[i], buckets.expense[i]);
      if (value <= 0) continue;
      final center = slot * i + slot / 2;
      final height = value / maxValue * (size.height - 44);
      final rect = Rect.fromLTRB(
        center - 30,
        base - height - 14,
        center + 30,
        base + 10,
      );
      if (rect.contains(local)) return i;
    }
    return null;
  }
}

({int count, List<double> income, List<double> expense}) _periodBuckets(
  List<LedgerEntry> entries,
  _StatsPeriod period,
) {
  final count = period == _StatsPeriod.year ? 12 : 6;
  final income = List<double>.filled(count, 0);
  final expense = List<double>.filled(count, 0);
  for (final item in entries) {
    final index = period == _StatsPeriod.year
        ? item.date.month - 1
        : (item.date.day - 1) ~/ 5;
    if (index < 0 || index >= count) continue;
    if (item.kind == LedgerKind.income) {
      income[index] += item.cnyAmount;
    } else {
      expense[index] += item.cnyAmount;
    }
  }
  return (count: count, income: income, expense: expense);
}

class _PeriodBarPainter extends CustomPainter {
  final List<LedgerEntry> entries;
  final _StatsPeriod period;
  final int? selectedIndex;
  final double progress;

  _PeriodBarPainter({
    required this.entries,
    required this.period,
    required this.selectedIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final buckets = _periodBuckets(entries, period);
    final income = buckets.income;
    final expense = buckets.expense;
    final count = buckets.count;

    final maxValue = [...income, ...expense].fold(1.0, math.max);
    final hasData = income.any((v) => v > 0) || expense.any((v) => v > 0);
    if (!hasData) {
      _paintEmpty(canvas, size, '暂无收支数据');
      return;
    }
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final slot = size.width / count;
    for (var i = 0; i < count; i++) {
      final center = slot * i + slot / 2;
      final selected = selectedIndex == i;
      final dimmed = selectedIndex != null && !selected;
      final boost = selected ? 1 + 0.08 * progress : 1.0;
      final barWidth = selected ? 16 + 5 * progress : 16.0;
      final expenseHeight = expense[i] / maxValue * (size.height - 44) * boost;
      final incomeHeight = income[i] / maxValue * (size.height - 44) * boost;
      final base = size.height - 32;
      final red = Paint()
        ..color = AppColors.danger.withValues(alpha: dimmed ? 0.22 : 1);
      final green = Paint()
        ..color = AppColors.success.withValues(alpha: dimmed ? 0.22 : 1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center + 2,
            base - expenseHeight,
            barWidth,
            expenseHeight,
          ),
          const Radius.circular(8),
        ),
        red,
      );
      if (incomeHeight > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              center - 20 - (barWidth - 16),
              base - incomeHeight,
              barWidth,
              incomeHeight,
            ),
            const Radius.circular(8),
          ),
          green,
        );
      }
      final value = math.max(income[i], expense[i]);
      if (value > 0) {
        final labelPainter = TextPainter(
          text: TextSpan(
            text: value.toStringAsFixed(0),
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        final top = base - math.max(incomeHeight, expenseHeight) - 16;
        labelPainter.paint(
          canvas,
          Offset(center - labelPainter.width / 2, top.clamp(0, size.height)),
        );
      }
      final label = period == _StatsPeriod.year ? '${i + 1}月' : '${i * 5 + 1}日';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(center - tp.width / 2, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _PeriodBarPainter oldDelegate) => true;
}

void _paintEmpty(Canvas canvas, Size size, String text) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(
      (size.width - painter.width) / 2,
      (size.height - painter.height) / 2,
    ),
  );
}

class _DonutChartPainter extends CustomPainter {
  final Map<String, double> data;
  final String? selectedCategory;
  final double progress;

  _DonutChartPainter(
    this.data, {
    required this.selectedCategory,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.values.fold(0.0, (s, v) => s + v);
    if (total <= 0) {
      _paintEmpty(canvas, size, '暂无分类数据');
      return;
    }
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(
      center: center,
      radius: math.min(size.width, size.height) * 0.26,
    );
    final colors = [
      AppColors.purple,
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.danger,
    ];
    var start = -math.pi / 2;
    var i = 0;
    final rows = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final item in rows) {
      final sweep = item.value / total * math.pi * 2;
      final mid = start + sweep / 2;
      final selected = item.key == selectedCategory;
      final dimmed = selectedCategory != null && !selected;
      final offset = selected
          ? Offset(math.cos(mid), math.sin(mid)) * (10 * progress)
          : Offset.zero;
      final arcRect = rect.shift(offset);
      final color = colors[i % colors.length].withValues(
        alpha: dimmed ? 0.22 : 1,
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 34 + 8 * progress : 34
        ..strokeCap = StrokeCap.butt
        ..color = color;
      canvas.drawArc(arcRect, start, sweep, false, paint);
      if (i < 5) {
        final edge = Offset(
          center.dx + offset.dx + math.cos(mid) * rect.width * 0.5,
          center.dy + offset.dy + math.sin(mid) * rect.height * 0.5,
        );
        final labelEnd = Offset(
          center.dx + offset.dx + math.cos(mid) * rect.width * 0.68,
          center.dy + offset.dy + math.sin(mid) * rect.height * 0.68,
        );
        final line = Paint()
          ..color = color
          ..strokeWidth = 2;
        canvas.drawLine(edge, labelEnd, line);
        final label =
            '${item.key} ${(item.value / total * 100).toStringAsFixed(1)}%';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: color,
              fontSize: selected ? 11 + progress : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: 90);
        final leftSide = math.cos(mid) < 0;
        final dx = leftSide ? labelEnd.dx - tp.width - 6 : labelEnd.dx + 6;
        final dy = (labelEnd.dy - tp.height / 2).clamp(
          0.0,
          size.height - tp.height,
        );
        tp.paint(canvas, Offset(dx.clamp(0.0, size.width - tp.width), dy));
      }
      start += sweep;
      i++;
    }
    final text = TextPainter(
      text: const TextSpan(
        text: '消费排名\n占比',
        style: TextStyle(
          color: AppColors.text,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}

const _ledgerCategoryAliasIds = <String, String>{
  '交通出行': 'traffic',
  '购物消费': 'shopping',
  '居家生活': 'life',
  '健康医疗': 'medical',
  '娱乐休闲': 'entertainment',
  '人情社交': 'social',
  '咖啡茶饮': 'food_coffee',
  '蔬菜': 'food_groceries',
  '水果': 'food_groceries',
  '日用': 'shopping_daily',
  '服饰': 'shopping_clothing',
  '衣服': 'shopping_clothing',
  '数码': 'shopping_digital',
  '家居': 'shopping_home',
  '住房': 'life_rent',
  '生活缴费': 'life_other',
  '水电燃气': 'life_other',
  '通讯': 'life_broadband',
  '学习': 'entertainment_books',
  '电影演出': 'entertainment_movie',
  '运动健身': 'medical_fitness',
  '旅行': 'entertainment_travel',
  '美妆': 'shopping_beauty',
  '礼物': 'shopping_gift',
  '汽车': 'traffic_other',
  '办公': 'shopping_daily',
  '未识别': 'custom_expense',
  '其他': 'custom_expense',
  '副业': 'part_time',
  '投资': 'investment_income',
  '理财收益': 'investment_income',
  '租金': 'rent_income',
  '红包收入': 'red_packet_income',
  '红包': 'social_red_packet',
  '15': 'custom_expense',
  '质': 'custom_expense',
  '落茨': 'custom_expense',
  '覃皇耆宁/】宁-星星抖首创业': 'custom_expense',
  '彗享亘亡吾.{〉>"吏车】贾′用': 'custom_expense',
  '贺': 'shopping_gift',
};

({String primary, String? secondary}) _splitLedgerCategoryName(String name) {
  final normalized = name.trim();
  final parts = normalized
      .split(RegExp(r'\s*[-－—]\s*'))
      .where((part) => part.trim().isNotEmpty)
      .map((part) => part.trim())
      .toList();
  if (parts.length >= 2) {
    return (primary: parts.first, secondary: parts.sublist(1).join('-'));
  }
  return (primary: normalized, secondary: null);
}

LedgerCategoryGroup? _expenseGroupForCategory(LedgerCategory category) {
  return _expenseGroupForValue(category.id) ??
      _expenseGroupForValue(category.name);
}

LedgerCategoryGroup? _expenseGroupForValue(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  final parsed = _splitLedgerCategoryName(normalized);
  if (parsed.secondary == null && (normalized == '其他' || normalized == '未识别')) {
    return _expenseCategoryGroups.last;
  }
  final lookupValues = <String>{
    normalized,
    parsed.primary,
    if (parsed.secondary != null) parsed.secondary!,
    if (_ledgerCategoryAliasIds[normalized] != null)
      _ledgerCategoryAliasIds[normalized]!,
    if (_ledgerCategoryAliasIds[parsed.primary] != null)
      _ledgerCategoryAliasIds[parsed.primary]!,
    if (parsed.secondary != null &&
        _ledgerCategoryAliasIds[parsed.secondary!] != null)
      _ledgerCategoryAliasIds[parsed.secondary!]!,
  };
  for (final group in _expenseCategoryGroups) {
    if (lookupValues.contains(group.primary.id) ||
        lookupValues.contains(group.primary.name)) {
      return group;
    }
    for (final child in group.children) {
      if (lookupValues.contains(child.id) ||
          lookupValues.contains(child.name)) {
        return group;
      }
    }
  }
  return null;
}

LedgerCategory? _expenseChildForValue(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  final parsed = _splitLedgerCategoryName(normalized);
  if (parsed.secondary == null && (normalized == '其他' || normalized == '未识别')) {
    return null;
  }
  final lookupValues = <String>{
    normalized,
    if (parsed.secondary != null) parsed.secondary!,
    if (_ledgerCategoryAliasIds[normalized] != null)
      _ledgerCategoryAliasIds[normalized]!,
    if (parsed.secondary != null &&
        _ledgerCategoryAliasIds[parsed.secondary!] != null)
      _ledgerCategoryAliasIds[parsed.secondary!]!,
  };
  for (final group in _expenseCategoryGroups) {
    for (final child in group.children) {
      if (lookupValues.contains(child.id) ||
          lookupValues.contains(child.name)) {
        return child;
      }
    }
  }
  return null;
}

LedgerCategory _findCategory(String name) {
  final normalized = name.trim();
  final parsed = _splitLedgerCategoryName(normalized);
  final aliasId = _ledgerCategoryAliasIds[normalized];
  if (parsed.secondary == null) {
    for (final group in _expenseCategoryGroups) {
      if (group.primary.name == normalized ||
          group.primary.id == normalized ||
          group.primary.id == aliasId) {
        return group.primary;
      }
    }
  }
  final expenseChild = _expenseChildForValue(normalized);
  if (expenseChild != null) return expenseChild;
  final lookupValues = <String>{
    normalized,
    parsed.primary,
    if (parsed.secondary != null) parsed.secondary!,
    if (_ledgerCategoryAliasIds[normalized] != null)
      _ledgerCategoryAliasIds[normalized]!,
    if (_ledgerCategoryAliasIds[parsed.primary] != null)
      _ledgerCategoryAliasIds[parsed.primary]!,
    if (parsed.secondary != null &&
        _ledgerCategoryAliasIds[parsed.secondary!] != null)
      _ledgerCategoryAliasIds[parsed.secondary!]!,
  };
  for (final item in [..._expenseCategories, ..._incomeCategories]) {
    if (lookupValues.contains(item.name) || lookupValues.contains(item.id)) {
      return item;
    }
  }
  if (parsed.primary == _customExpensePrimaryCategory.name) {
    return LedgerCategory(
      id: 'custom_expense_display',
      name: parsed.secondary ?? _customExpensePrimaryCategory.name,
      emoji: _customExpensePrimaryCategory.emoji,
      color: _customExpensePrimaryCategory.color,
      kind: LedgerKind.expense,
    );
  }
  return _customExpensePrimaryCategory;
}

String _ledgerPrimaryName(LedgerEntry entry) {
  if (entry.kind == LedgerKind.income) return entry.categoryName;
  final parsed = _splitLedgerCategoryName(entry.categoryName);
  final group =
      _expenseGroupForValue(entry.categoryId) ??
      _expenseGroupForValue(entry.categoryName);
  if (parsed.secondary != null) {
    final primaryGroup = _expenseGroupForValue(parsed.primary);
    return primaryGroup?.primary.name ?? parsed.primary;
  }
  return group?.primary.name ?? _customExpensePrimaryCategory.name;
}

String? _ledgerSecondaryName(LedgerEntry entry) {
  if (entry.kind == LedgerKind.income) return null;
  final parsed = _splitLedgerCategoryName(entry.categoryName);
  if (parsed.secondary != null && parsed.secondary!.trim().isNotEmpty) {
    return parsed.secondary!.trim();
  }
  final group =
      _expenseGroupForValue(entry.categoryId) ??
      _expenseGroupForValue(entry.categoryName);
  if (group != null &&
      (entry.categoryId == group.primary.id ||
          entry.categoryName.trim() == group.primary.name ||
          entry.categoryName.trim() == group.primary.id)) {
    return null;
  }
  final child =
      _expenseChildForValue(entry.categoryId) ??
      _expenseChildForValue(entry.categoryName);
  if (child != null) return child.name;
  final primary = _ledgerPrimaryName(entry);
  final normalized = entry.categoryName.trim();
  if (normalized.isEmpty || normalized == primary) return null;
  if (_ledgerCategoryAliasIds[normalized] == 'custom_expense') return null;
  return normalized;
}

String _ledgerCategoryTitle(LedgerEntry entry) {
  if (entry.kind == LedgerKind.income) return entry.categoryName;
  final primary = _ledgerPrimaryName(entry);
  final secondary = _ledgerSecondaryName(entry);
  if (secondary == null || secondary.isEmpty || secondary == primary) {
    return primary;
  }
  return '$primary-$secondary';
}

String _ledgerSubCategoryChartName(LedgerEntry entry) {
  return _ledgerSecondaryName(entry) ?? '未选小类';
}

LedgerCategory _ledgerCategoryForEntry(LedgerEntry entry) {
  if (entry.kind == LedgerKind.income) return _findCategory(entry.categoryName);
  return _findCategory(
    _ledgerSecondaryName(entry) ?? _ledgerPrimaryName(entry),
  );
}

String _resolvedLedgerEmoji(LedgerEntry entry) {
  final stored = entry.categoryEmoji.trim();
  final resolved = _ledgerCategoryForEntry(entry);
  if (stored.isEmpty || (stored == '🔹' && resolved.id != 'custom_expense')) {
    return resolved.emoji;
  }
  return stored;
}

const _currencyCodes = ['CNY', 'USD', 'EUR', 'JPY', 'HKD', 'GBP', 'KRW'];

String _currencyFlag(String code) {
  return switch (code) {
    'CNY' => '🇨🇳',
    'USD' => '🇺🇸',
    'EUR' => '🇪🇺',
    'JPY' => '🇯🇵',
    'HKD' => '🇭🇰',
    'GBP' => '🇬🇧',
    'KRW' => '🇰🇷',
    _ => '🏳️',
  };
}

String _currencyName(String code) {
  return switch (code) {
    'CNY' => '人民币',
    'USD' => '美元',
    'EUR' => '欧元',
    'JPY' => '日元',
    'HKD' => '港币',
    'GBP' => '英镑',
    'KRW' => '韩元',
    _ => '',
  };
}

String _money(double value) => '¥ ${value.toStringAsFixed(2)}';

String _formatLedgerDateTime(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
}
