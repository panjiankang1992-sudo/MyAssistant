import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/security/keychain_service.dart';
import '../../core/providers/core_providers.dart';
import '../../data/datasources/webdav_datasource.dart';
import '../../domain/models/tag.dart';
import '../../shared/widgets/app_controls.dart';
import '../../shared/widgets/edge_swipe_pop.dart';
import '../../shared/widgets/profile_avatar_button.dart';
import '../../shared/widgets/tag_chip.dart';
import '../ai_settings/ai_model_provider.dart';
import '../copilot/services/openai_compatible_client.dart';
import '../sync/data_sync_service.dart';
import '../tags/tag_selector.dart';
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
  });

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
  Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory('${dir.path}/bookkeeping');
    if (!await folder.exists()) await folder.create(recursive: true);
    return File('${folder.path}/$name');
  }

  Future<List<LedgerEntry>> loadEntries() async {
    final file = await _file('entries.json');
    if (!await file.exists()) return _seedEntries();
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final items = data['entries'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(LedgerEntry.fromJson)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> saveEntries(List<LedgerEntry> entries) async {
    final file = await _file('entries.json');
    await file.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'entries': entries.map((item) => item.toJson()).toList()}),
    );
  }

  Future<List<LedgerCategory>> loadCustomCategories() async {
    final file = await _file('categories.json');
    if (!await file.exists()) return const [];
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final items = data['categories'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(LedgerCategory.fromJson)
        .toList();
  }

  Future<void> saveCustomCategories(List<LedgerCategory> categories) async {
    final file = await _file('categories.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'categories': categories.map((item) => item.toJson()).toList(),
      }),
    );
  }

  Future<ExchangeCache?> loadExchange() async {
    final file = await _file('exchange.json');
    if (!await file.exists()) return null;
    return ExchangeCache.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<void> saveExchange(ExchangeCache cache) async {
    final file = await _file('exchange.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(cache.toJson()),
    );
  }

  List<LedgerEntry> _seedEntries() {
    final now = DateTime.now();
    return [
      _seed('餐饮', '🍱', 19.9, now, '午餐'),
      _seed('交通', '🚌', 4.75, now, '地铁'),
      _seed('购物', '🛍️', 32.38, now.subtract(const Duration(days: 1)), '日用品'),
    ];
  }

  LedgerEntry _seed(
    String category,
    String emoji,
    double amount,
    DateTime date,
    String note,
  ) {
    final now = DateTime.now();
    return LedgerEntry(
      id: const Uuid().v4(),
      kind: LedgerKind.expense,
      categoryId: category,
      categoryName: category,
      categoryEmoji: emoji,
      note: note,
      amount: amount,
      currency: 'CNY',
      cnyAmount: amount,
      date: DateTime(date.year, date.month, date.day, now.hour, now.minute),
      aiGenerated: false,
      createdAt: now,
    );
  }
}

class BookkeepingCloudSync {
  Future<void> sync(BookkeepingStore store) async {
    final client = await _client();
    if (client == null) return;
    final (:webdav, :username) = client;
    try {
      await webdav.createDirectory('MyAssistant/$username');
    } catch (_) {}
    try {
      await webdav.createDirectory('MyAssistant/$username/bills');
    } catch (_) {}

    final localEntries = await store.loadEntries();
    final localCategories = await store.loadCustomCategories();
    final cloudEntries = await _pullEntries(webdav, username);
    final cloudCategories = await _pullCategories(webdav, username);

    final mergedEntries = _mergeEntries(localEntries, cloudEntries);
    final mergedCategories = _mergeCategories(localCategories, cloudCategories);
    await store.saveEntries(mergedEntries);
    await store.saveCustomCategories(mergedCategories);
    await _pushEntries(webdav, username, mergedEntries);
    await _pushCategories(webdav, username, mergedCategories);
  }

  Future<({WebDavDatasource webdav, String username})?> _client() async {
    final keychain = KeychainService();
    final lastUrl = await keychain.getLastServerUrl();
    if (lastUrl == null || lastUrl.isEmpty) return null;
    final creds = await keychain.getCredentials(lastUrl);
    if (creds == null) return null;
    final webdav = WebDavDatasource();
    await webdav.initialize(
      baseUrl: lastUrl,
      username: creds['username']!,
      password: creds['password']!,
    );
    return (webdav: webdav, username: creds['username']!);
  }

  Future<List<LedgerEntry>> _pullEntries(
    WebDavDatasource webdav,
    String username,
  ) async {
    try {
      final bytes = await webdav.getFile(
        'MyAssistant/$username/bills/ledger_entries.json',
      );
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final items = data['entries'] as List<dynamic>? ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(LedgerEntry.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<LedgerCategory>> _pullCategories(
    WebDavDatasource webdav,
    String username,
  ) async {
    try {
      final bytes = await webdav.getFile(
        'MyAssistant/$username/bills/ledger_categories.json',
      );
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final items = data['categories'] as List<dynamic>? ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(LedgerCategory.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _pushEntries(
    WebDavDatasource webdav,
    String username,
    List<LedgerEntry> entries,
  ) async {
    final data = jsonEncode({
      'updatedAt': DateTime.now().toIso8601String(),
      'entries': entries.map((item) => item.toJson()).toList(),
    });
    await webdav.putFile(
      'MyAssistant/$username/bills/ledger_entries.json',
      Uint8List.fromList(utf8.encode(data)),
      contentType: 'application/json',
    );
  }

  Future<void> _pushCategories(
    WebDavDatasource webdav,
    String username,
    List<LedgerCategory> categories,
  ) async {
    final data = jsonEncode({
      'updatedAt': DateTime.now().toIso8601String(),
      'categories': categories.map((item) => item.toJson()).toList(),
    });
    await webdav.putFile(
      'MyAssistant/$username/bills/ledger_categories.json',
      Uint8List.fromList(utf8.encode(data)),
      contentType: 'application/json',
    );
  }

  List<LedgerEntry> _mergeEntries(
    List<LedgerEntry> local,
    List<LedgerEntry> cloud,
  ) {
    final byId = <String, LedgerEntry>{};
    for (final item in [...cloud, ...local]) {
      final old = byId[item.id];
      if (old == null || item.createdAt.isAfter(old.createdAt)) {
        byId[item.id] = item;
      }
    }
    return byId.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  List<LedgerCategory> _mergeCategories(
    List<LedgerCategory> local,
    List<LedgerCategory> cloud,
  ) {
    final byId = <String, LedgerCategory>{};
    for (final item in [...cloud, ...local]) {
      byId[item.id] = item;
    }
    return byId.values.toList();
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

const _expenseCategories = [
  LedgerCategory(
    id: 'food',
    name: '餐饮',
    emoji: '🍜',
    color: Color(0xFFF6EDE8),
    kind: LedgerKind.expense,
  ),
  LedgerCategory(
    id: 'shopping',
    name: '购物',
    emoji: '🛍',
    color: Color(0xFFF8F1FF),
    kind: LedgerKind.expense,
  ),
  LedgerCategory(
    id: 'traffic',
    name: '交通',
    emoji: '🚌',
    color: Color(0xFFEDEBFA),
    kind: LedgerKind.expense,
  ),
  LedgerCategory(
    id: 'snack',
    name: '零食',
    emoji: '🍭',
    color: Color(0xFFFFF3E7),
    kind: LedgerKind.expense,
  ),
  LedgerCategory(
    id: 'vegetable',
    name: '蔬菜',
    emoji: '🥬',
    color: Color(0xFFEAF8EF),
    kind: LedgerKind.expense,
  ),
  LedgerCategory(
    id: 'fruit',
    name: '水果',
    emoji: '🍓',
    color: Color(0xFFFFEFF2),
    kind: LedgerKind.expense,
  ),
  LedgerCategory(
    id: 'entertainment',
    name: '娱乐',
    emoji: '🎭',
    color: Color(0xFFFFF1E8),
    kind: LedgerKind.expense,
  ),
  LedgerCategory(
    id: 'car',
    name: '汽车',
    emoji: '🚕',
    color: Color(0xFFEAF1FF),
    kind: LedgerKind.expense,
  ),
  LedgerCategory(
    id: 'beauty',
    name: '美妆',
    emoji: '💄',
    color: Color(0xFFFFEEF8),
    kind: LedgerKind.expense,
  ),
  LedgerCategory(
    id: 'daily',
    name: '日用',
    emoji: '🧴',
    color: Color(0xFFF4F8FF),
    kind: LedgerKind.expense,
  ),
  LedgerCategory(
    id: 'study',
    name: '学习',
    emoji: '📚',
    color: Color(0xFFEAF1FF),
    kind: LedgerKind.expense,
  ),
  LedgerCategory(
    id: 'medical',
    name: '医疗',
    emoji: '💊',
    color: Color(0xFFEAF8F2),
    kind: LedgerKind.expense,
  ),
  LedgerCategory(
    id: 'pet',
    name: '宠物',
    emoji: '🐱',
    color: Color(0xFFFFF0F0),
    kind: LedgerKind.expense,
  ),
  LedgerCategory(
    id: 'other',
    name: '其他',
    emoji: '🔹',
    color: Color(0xFFEAF5FF),
    kind: LedgerKind.expense,
  ),
];

const _incomeCategories = [
  LedgerCategory(
    id: 'salary',
    name: '工资',
    emoji: '💼',
    color: Color(0xFFE8F8EF),
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
    id: 'bonus',
    name: '奖金',
    emoji: '🎁',
    color: Color(0xFFFFF3E0),
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
    id: 'investment',
    name: '投资',
    emoji: '📈',
    color: Color(0xFFEAF8EF),
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
    id: 'gift',
    name: '红包',
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

class BookkeepingPage extends ConsumerStatefulWidget {
  final VoidCallback? onAvatarTap;

  const BookkeepingPage({super.key, this.onAvatarTap});

  @override
  ConsumerState<BookkeepingPage> createState() => _BookkeepingPageState();
}

class _BookkeepingPageState extends ConsumerState<BookkeepingPage> {
  final _store = BookkeepingStore();
  final _fabSpeech = stt.SpeechToText();
  late final ExchangeService _exchangeService;
  var _entries = <LedgerEntry>[];
  var _selectedDate = DateTime.now();
  var _fabSpeechReady = false;
  var _fabListening = false;
  var _fabVoiceText = '';

  @override
  void initState() {
    super.initState();
    _exchangeService = ExchangeService(_store);
    _load();
  }

  @override
  void dispose() {
    _fabSpeech.cancel();
    super.dispose();
  }

  Future<void> _startFabVoiceInput() async {
    if (_fabListening) return;
    if (!_fabSpeechReady) {
      _fabSpeechReady = await _fabSpeech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _fabListening = status == 'listening');
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _fabListening = false);
        },
      );
    }
    if (!_fabSpeechReady) return;
    setState(() {
      _fabListening = true;
      _fabVoiceText = '';
    });
    await _fabSpeech.listen(
      onResult: (result) {
        if (!mounted) return;
        final text = result.recognizedWords.trim();
        if (text.isNotEmpty) setState(() => _fabVoiceText = text);
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: 'zh_CN',
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _finishFabVoiceInput() async {
    if (_fabListening) await _fabSpeech.stop();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    final text = _fabVoiceText.trim();
    setState(() => _fabListening = false);
    showAddLedgerPage(
      context,
      ref: ref,
      date: _selectedDate,
      exchangeService: _exchangeService,
      onSaved: _addEntry,
      onCategoriesChanged: _markBillCategoriesDirty,
      initialVoiceText: text.isEmpty ? null : text,
    );
  }

  Future<void> _load() async {
    final items = await _store.loadEntries();
    if (mounted) setState(() => _entries = items);
    await _store.saveEntries(items);
  }

  Future<void> _addEntry(LedgerEntry entry) async {
    final next = [entry, ..._entries]..sort((a, b) => b.date.compareTo(a.date));
    setState(() => _entries = next);
    await _store.saveEntries(next);
    await _markBillDirty(entry, 'upsert');
  }

  Future<void> _updateEntry(LedgerEntry entry) async {
    final next =
        _entries.map((item) => item.id == entry.id ? entry : item).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    setState(() => _entries = next);
    await _store.saveEntries(next);
    await _markBillDirty(entry, 'upsert');
  }

  Future<void> _deleteEntry(LedgerEntry entry) async {
    final next = _entries.where((item) => item.id != entry.id).toList();
    setState(() => _entries = next);
    await _store.saveEntries(next);
    await _markBillDirty(entry, 'delete');
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
            'category': entry.categoryName,
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

  double _dailyNet(DateTime date) {
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
    return income - expense;
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

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
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
      floatingActionButton: _GradientAddButton(
        listening: _fabListening,
        onPressed: () => showAddLedgerPage(
          context,
          ref: ref,
          date: _selectedDate,
          exchangeService: _exchangeService,
          onSaved: _addEntry,
          onCategoriesChanged: _markBillCategoriesDirty,
        ),
        onLongPressStart: _startFabVoiceInput,
        onLongPressEnd: _finishFabVoiceInput,
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
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: '选择日期',
                      onPressed: onDatePick,
                      icon: const Icon(
                        Icons.calendar_month_outlined,
                        size: 24,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    IconButton(
                      tooltip: '统计',
                      onPressed: onStats,
                      icon: const Icon(
                        Icons.pie_chart_rounded,
                        size: 24,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  '人生苦短，钱途漫漫，省钱是王道。',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
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
          '确定删除「${entry.categoryName} ${_money(entry.cnyAmount)}」吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: AppColors.danger)),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEEFF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selectedDate.month}月${selectedDate.day}日账单结余 ${_money(balance)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Text('收支数据', style: TextStyle(fontWeight: FontWeight.w700)),
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
          '确定删除「${entry.categoryName} ${_money(entry.cnyAmount)}」吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: AppColors.danger)),
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
    final category = _findCategory(entry.categoryName);
    final sign = entry.kind == LedgerKind.expense ? '-' : '+';
    final amountColor = entry.kind == LedgerKind.expense
        ? AppColors.danger
        : AppColors.success;
    final kindLabel = entry.kind == LedgerKind.expense ? '支出' : '收入';
    return EdgeSwipePop(
      child: Material(
        color: AppColors.scaffoldBg,
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 128),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '详细信息',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.text,
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
                      emoji: entry.categoryEmoji,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppAnimations.elevatedShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryIcon(
                category: category,
                size: 42,
                emoji: entry.categoryEmoji,
              ),
              const SizedBox(width: 12),
              Text(
                entry.categoryName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
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
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              entry.note.isEmpty ? '这笔账单暂时没有备注，当前重点展示金额、时间和分类信息。' : entry.note,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
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

class _LedgerDetailInfoCard extends StatelessWidget {
  final LedgerEntry entry;

  const _LedgerDetailInfoCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppAnimations.elevatedShadow(),
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
          const _LedgerDetailLine(label: '记账人', value: '禹宇天'),
          _LedgerDetailLine(label: '账单分类', value: entry.categoryName),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
      if (_category != null && item.categoryName != _category) return false;
      if (_bucketIndex != null && !_matchesBucket(item, _bucketIndex!)) {
        return false;
      }
      if (_query.isEmpty) return true;
      return item.categoryName.contains(_query) || item.note.contains(_query);
    }).toList();
  }

  List<LedgerEntry> get _pieEntries {
    return widget.entries.where((item) {
      if (!_matchesPeriod(item)) return false;
      if (_bucketIndex != null && !_matchesBucket(item, _bucketIndex!)) {
        return false;
      }
      if (_query.isEmpty) return true;
      return item.categoryName.contains(_query) || item.note.contains(_query);
    }).toList();
  }

  List<LedgerEntry> get _periodChartEntries {
    return widget.entries.where((item) {
      if (!_matchesPeriod(item)) return false;
      if (_category != null && item.categoryName != _category) return false;
      if (_query.isEmpty) return true;
      return item.categoryName.contains(_query) || item.note.contains(_query);
    }).toList();
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
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.inputBg,
                          fixedSize: const Size(50, 50),
                        ),
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
        _visible.where((item) => item.categoryName == category).toList()
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
        widget.entries.map((item) => item.categoryName).toSet().toList()
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
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.inputBg,
                                  fixedSize: const Size(50, 50),
                                ),
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
                            height: 52,
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _query = queryController.text.trim();
                                  _category = category;
                                });
                                Navigator.of(context).pop();
                              },
                              child: const Text('应用'),
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
    final chartGrouped = <String, double>{};
    for (final item in pieEntries.where((e) => e.kind == LedgerKind.expense)) {
      chartGrouped[item.categoryName] =
          (chartGrouped[item.categoryName] ?? 0) + item.cnyAmount;
    }
    final grouped = <String, double>{};
    final emojis = <String, String>{};
    for (final item in entries.where((e) => e.kind == LedgerKind.expense)) {
      grouped[item.categoryName] =
          (grouped[item.categoryName] ?? 0) + item.cnyAmount;
      emojis[item.categoryName] = item.categoryEmoji;
    }
    final rows = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 104),
      children: [
        _StatsChartCard(
          title: '分类统计 - 综合',
          height: 280,
          child: _InteractiveDonutChart(
            data: chartGrouped,
            selectedCategory: selectedCategory,
            onSelected: onCategorySelected,
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
            category: cat,
            emoji: emojis[row.key],
            amount: row.value,
            percent: pct,
            onTap: () => onCategoryDetails(row.key),
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
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
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

class _StatCategoryRow extends StatelessWidget {
  final LedgerCategory category;
  final String? emoji;
  final double amount;
  final double percent;
  final VoidCallback onTap;

  const _StatCategoryRow({
    required this.category,
    this.emoji,
    required this.amount,
    required this.percent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: AppColors.surface,
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
                    category.name,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
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
    final cat = _findCategory(entry.categoryName);
    final sign = entry.kind == LedgerKind.expense ? '-' : '+';
    final color = entry.kind == LedgerKind.expense
        ? AppColors.danger
        : AppColors.success;
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
                emoji: entry.categoryEmoji,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.categoryName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
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
                        entry.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: category.color,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: category.color.withValues(alpha: 0.75)),
      ),
      child: Center(
        child: Text(
          emoji ?? category.emoji,
          style: TextStyle(fontSize: size * 0.45),
        ),
      ),
    );
  }
}

class _GradientAddButton extends StatelessWidget {
  final bool listening;
  final VoidCallback onPressed;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;

  const _GradientAddButton({
    required this.listening,
    required this.onPressed,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onPressed,
        onLongPressStart: (_) => onLongPressStart(),
        onLongPressEnd: (_) => onLongPressEnd(),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF0A84FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            listening ? Icons.mic_rounded : Icons.add_rounded,
            color: Colors.white,
            size: 30,
          ),
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
  required ValueChanged<LedgerEntry> onSaved,
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
  final ValueChanged<LedgerEntry> onSaved;
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
  late final AnimationController _pulseController;
  final _speech = stt.SpeechToText();
  final _noteController = TextEditingController();
  var _kind = LedgerKind.expense;
  var _category = _expenseCategories.first;
  var _amountText = '';
  var _currency = 'CNY';
  var _aiGenerated = false;
  var _speechReady = false;
  var _listening = false;
  var _voiceText = '';
  var _tags = <Tag>[];
  var _customCategories = <LedgerCategory>[];
  var _showVoicePrompt = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEntry;
    if (initial != null) {
      _kind = initial.kind;
      _category = LedgerCategory(
        id: initial.categoryId,
        name: initial.categoryName,
        emoji: initial.categoryEmoji,
        color: _findCategory(initial.categoryName).color,
        kind: initial.kind,
      );
      _amountText = _formatAmount(initial.amount);
      _currency = initial.currency;
      _aiGenerated = initial.aiGenerated;
      _tags = List.from(initial.tags);
      _noteController.text = initial.note;
      _showVoicePrompt = false;
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: 0.92,
      upperBound: 1.08,
    )..repeat(reverse: true);
    final initialVoiceText = widget.initialVoiceText?.trim() ?? '';
    if (initialVoiceText.isNotEmpty && initial == null) {
      _voiceText = initialVoiceText;
      _noteController.text = initialVoiceText;
      _showVoicePrompt = false;
      _aiGenerated = true;
    }
    Future.microtask(() async {
      await _initSpeech();
      await _loadCustomCategories();
      if (initialVoiceText.isNotEmpty && mounted && initial == null) {
        await _parseLedgerText(initialVoiceText);
      }
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    _pulseController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(
      onStatus: (status) {
        if (mounted) setState(() => _listening = status == 'listening');
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (mounted) setState(() => _speechReady = ok);
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
      }
    });
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      return;
    }
    if (!_speechReady) await _initSpeech();
    if (!_speechReady) return;
    setState(() {
      _listening = true;
      _voiceText = '';
    });
    await _speech.listen(
      onResult: _onSpeech,
      listenOptions: stt.SpeechListenOptions(
        localeId: 'zh_CN',
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _onSpeech(SpeechRecognitionResult result) async {
    final text = result.recognizedWords.trim();
    if (text.isEmpty || !mounted) return;
    setState(() => _voiceText = text);
    if (!result.finalResult) return;
    await _parseLedgerText(text);
  }

  Future<void> _parseLedgerText(String text) async {
    final parsed = await _aiParse(text) ?? _localParse(text);
    final cats = _categoriesFor(parsed.kind);
    setState(() {
      _kind = parsed.kind;
      _category = cats.firstWhere(
        (item) => item.name == parsed.categoryName,
        orElse: () => cats.first,
      );
      _amountText = parsed.amount.toStringAsFixed(
        parsed.amount.truncateToDouble() == parsed.amount ? 0 : 2,
      );
      _currency = parsed.currency;
      _noteController.text = parsed.note;
      _aiGenerated = true;
      _listening = false;
      _showVoicePrompt = false;
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
      final reply = await OpenAiCompatibleClient().chat(
        config: config,
        messages: [
          const LlmChatMessage(
            role: 'system',
            content:
                '你是记账识别器，只返回 JSON。字段 kind(expense/income), amount(number), currency(CNY/USD/EUR/JPY/HKD/GBP/KRW), categoryName, note。默认 kind=expense。支出分类只能是 餐饮、购物、交通、零食、学习、医疗、其他；收入分类只能是 工资、奖金、退款。',
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
      kind: text.contains('收入') || text.contains('工资') || text.contains('退款')
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
    if (RegExp('地铁|公交|打车|交通').hasMatch(text)) return _findCategory('交通');
    if (RegExp('饭|餐|咖啡|奶茶|早餐|午餐|晚餐').hasMatch(text)) return _findCategory('餐饮');
    if (RegExp('买|购物|超市').hasMatch(text)) return _findCategory('购物');
    if (RegExp('工资|收入').hasMatch(text)) return _incomeCategories.first;
    return _expenseCategories.last;
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
    final amount = _evaluateAmount(_amountText);
    if (amount == null || amount <= 0) return;
    final rates = await widget.exchangeService.getRates();
    final cny = amount * (rates.toCny[_currency] ?? 1);
    final now = DateTime.now();
    final initial = widget.initialEntry;
    final entryDate = initial?.date;
    final entry = LedgerEntry(
      id: initial?.id ?? const Uuid().v4(),
      kind: _kind,
      categoryId: _category.id,
      categoryName: _category.name,
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
    widget.onSaved(entry);
    if (mounted) Navigator.of(context).pop();
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('保存'),
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
    });
    await widget.exchangeService.store.saveCustomCategories(next);
    widget.onCategoriesChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cats = _categoriesFor(_kind);
    return Material(
      color: AppColors.scaffoldBg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 10),
              child: Row(
                children: [
                  if (widget.initialEntry != null) ...[
                    const Text(
                      '编辑账单',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
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
                            _category = _categoriesFor(
                              LedgerKind.expense,
                            ).first;
                          }),
                        ),
                        _KindTab(
                          label: '收入账单',
                          selected: _kind == LedgerKind.income,
                          onTap: () => setState(() {
                            _kind = LedgerKind.income;
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
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ...cats.map((cat) {
                            final selected = cat.id == _category.id;
                            return _CategoryPickTile(
                              category: cat,
                              selected: selected,
                              onTap: () => setState(() => _category = cat),
                            );
                          }),
                          _AddCategoryTile(onTap: _addCustomCategory),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _noteController,
                              decoration: InputDecoration(
                                hintText: '备注，例如：地铁、午餐',
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ],
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              '金额',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            Text(
                              '${_currency == "CNY" ? "¥" : _currency} ${_amountText.isEmpty ? "0.00" : _amountText}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _NumberPad(
                        currency: _currency,
                        onCurrencyTap: _showCurrencyPicker,
                        onTap: _tapNumber,
                      ),
                    ],
                  ),
                  if (_showVoicePrompt)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => setState(() => _showVoicePrompt = false),
                        child: Align(
                          alignment: const Alignment(0, 0.58),
                          child: GestureDetector(
                            onTap: _toggleVoice,
                            child: ScaleTransition(
                              scale: _pulseController,
                              child: _VoiceLedgerButton(
                                listening: _listening,
                                speechReady: _speechReady,
                                text: _voiceText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            AppFloatingActionBar(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              actions: [
                AppBottomAction(
                  label: widget.initialEntry == null ? '完成记账' : '保存修改',
                  icon: Icons.check_rounded,
                  onPressed: _save,
                  tone: AppActionButtonTone.primary,
                ),
              ],
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
  final LedgerCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryPickTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? category.color : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 4),
            Text(
              category.name,
              style: const TextStyle(
                fontFamily: 'PingFang SC',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCategoryTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddCategoryTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 30),
            SizedBox(height: 4),
            Text('自定义', style: TextStyle(fontWeight: FontWeight.w700)),
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
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.primary : AppColors.textSecondary,
            decoration: selected ? TextDecoration.underline : null,
            decorationThickness: 2,
          ),
        ),
      ),
    );
  }
}

class _VoiceLedgerButton extends StatelessWidget {
  final bool listening;
  final bool speechReady;
  final String text;

  const _VoiceLedgerButton({
    required this.listening,
    required this.speechReady,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: listening
                    ? const [Color(0xFFFF5F6D), Color(0xFFFFC371)]
                    : const [Color(0xFF8B5CF6), Color(0xFF0A84FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            listening
                ? '正在听...'
                : speechReady
                ? '语音记账'
                : '点击启用语音',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text.isEmpty ? '点击麦克风开始说话' : text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
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
              color: key == 'del' ? const Color(0xFFFF5B45) : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: key == 'del'
                  ? const Icon(Icons.backspace_outlined, color: Colors.white)
                  : key == 'currency'
                  ? Text(
                      '${_currencyFlag(currency)} $currency',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : Text(
                      key,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
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

LedgerCategory _findCategory(String name) {
  return [..._expenseCategories, ..._incomeCategories].firstWhere(
    (item) => item.name == name || item.id == name,
    orElse: () => _expenseCategories.last,
  );
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
