import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../domain/models/todo.dart';
import '../ai_settings/ai_model_provider.dart';
import '../copilot/services/openai_compatible_client.dart';
import 'bookkeeping_page.dart';

class BookkeepingActionService {
  final BookkeepingStore? _store;
  final ExchangeService? _exchangeService;

  BookkeepingActionService({
    BookkeepingStore? store,
    ExchangeService? exchangeService,
  }) : _store = store,
       _exchangeService = exchangeService;

  Future<bool> createExpenseFromTodo({
    required Ref ref,
    required Todo todo,
  }) async {
    if (todo.action != 'bookkeeping') return false;
    final text = [
      todo.title,
      if ((todo.description ?? '').trim().isNotEmpty) todo.description!.trim(),
    ].join(' ');
    if (text.trim().isEmpty) return false;

    final store =
        _store ??
        BookkeepingStore(
          ref.read(databaseProvider),
          ref.read(datasourceProvider),
        );
    final exchangeService = _exchangeService ?? ExchangeService(store);
    final customCategories = await store.loadCustomCategories();
    final localParsed = _localParse(text, customCategories);
    final parsed = _isConfidentLocalParse(localParsed)
        ? localParsed
        : await _aiParse(ref, text, customCategories, localParsed) ??
              localParsed;
    if (parsed.amount <= 0) return false;

    final category = _categoryByName(parsed.categoryName, customCategories);
    final rates = await exchangeService.getRates();
    final amount = parsed.amount;
    final cny = amount * (rates.toCny[parsed.currency] ?? 1);
    final createdAt = DateTime.now();
    final dateTime = _todoDateTime(todo);
    final entry = LedgerEntry(
      id: 'todo-bookkeeping-${todo.id}',
      kind: LedgerKind.expense,
      categoryId: category.id,
      categoryName: ledgerCategoryDisplayNameForSelection(category),
      categoryEmoji: category.emoji,
      note: parsed.note.isEmpty ? todo.title : parsed.note,
      amount: amount,
      currency: parsed.currency,
      cnyAmount: cny,
      date: dateTime,
      aiGenerated: parsed.aiGenerated,
      createdAt: createdAt,
    );

    final entries = await store.loadEntries();
    final next = [entry, ...entries.where((item) => item.id != entry.id)]
      ..sort((a, b) => b.date.compareTo(a.date));
    await store.saveEntries(next);
    return true;
  }

  Future<_TodoLedgerParse?> _aiParse(
    Ref ref,
    String text,
    List<LedgerCategory> customCategories,
    _TodoLedgerParse localParsed,
  ) async {
    final config = ref.read(aiModelProvider).selected;
    if (config == null ||
        config.apiKey.trim().isEmpty ||
        config.baseUrl.trim().isEmpty ||
        config.model.trim().isEmpty) {
      return null;
    }
    final categories = [
      ...defaultExpenseLedgerCategories,
      ...customCategories.where((item) => item.kind == LedgerKind.expense),
    ].map((item) => item.name).join('、');
    try {
      final reply = await OpenAiCompatibleClient()
          .chat(
            config: config,
            messages: [
              LlmChatMessage(
                role: 'system',
                content:
                    '你是“代办动作-记账”的专用解析器，只返回紧凑 JSON，不要 Markdown。'
                    '任务：把用户代办文本转成一条支出账单。'
                    '字段：amount(number), currency(CNY/USD/EUR/JPY/HKD/GBP/KRW), categoryName, note。'
                    '强规则：1. 金额优先取带 元/块/¥/￥/人民币/RMB/CNY 的数字；'
                    '2. 不要把 1号线、2楼、3人、08:30、日期 当金额；'
                    '3. 如果有多个金额，取最像实际支付金额的那个；'
                    '4. categoryName 只能从这些分类中选：$categories；'
                    '5. 没有金额 amount=0。'
                    '例：上班地铁 1号线 南京交院站到天隆寺 4.75元 => {"amount":4.75,"currency":"CNY","categoryName":"交通","note":"上班地铁 南京交院站到天隆寺"}。',
              ),
              LlmChatMessage(role: 'user', content: text),
            ],
          )
          .timeout(const Duration(milliseconds: 800));
      final jsonText =
          RegExp(r'\{[\s\S]*\}').firstMatch(reply)?.group(0) ?? reply;
      final data = jsonDecode(jsonText) as Map<String, dynamic>;
      final aiAmount = (data['amount'] as num?)?.toDouble() ?? 0;
      return _TodoLedgerParse(
        amount: localParsed.amount > 0 ? localParsed.amount : aiAmount,
        currency: _validCurrency(data['currency'] as String?),
        categoryName:
            data['categoryName'] as String? ??
            _guessCategory(text, customCategories).name,
        note: (data['note'] as String? ?? text).trim(),
        aiGenerated: true,
      );
    } catch (_) {
      return null;
    }
  }

  _TodoLedgerParse _localParse(
    String text,
    List<LedgerCategory> customCategories,
  ) {
    return _TodoLedgerParse(
      amount: _extractAmount(text),
      currency: _detectCurrency(text),
      categoryName: _guessCategory(text, customCategories).name,
      note: text,
      aiGenerated: false,
    );
  }

  bool _isConfidentLocalParse(_TodoLedgerParse parsed) {
    return parsed.amount > 0 &&
        parsed.categoryName != '其他' &&
        parsed.categoryName != '自定义';
  }

  LedgerCategory _guessCategory(
    String text,
    List<LedgerCategory> customCategories,
  ) {
    final all = [
      ...defaultExpenseLedgerCategories,
      ...customCategories.where((item) => item.kind == LedgerKind.expense),
    ];
    for (final item in all) {
      if (text.contains(item.name)) return item;
    }
    if (RegExp('地铁').hasMatch(text)) return findDefaultLedgerCategory('地铁');
    if (RegExp('公交').hasMatch(text)) return findDefaultLedgerCategory('公交');
    if (RegExp('打车|滴滴|出租|网约车').hasMatch(text)) {
      return findDefaultLedgerCategory('打车');
    }
    if (RegExp('停车').hasMatch(text)) return findDefaultLedgerCategory('停车');
    if (RegExp('加油|油费').hasMatch(text)) return findDefaultLedgerCategory('加油');
    if (RegExp('高速|过路费').hasMatch(text)) {
      return findDefaultLedgerCategory('高速费');
    }
    if (RegExp('交通|车费').hasMatch(text)) return findDefaultLedgerCategory('交通');
    if (RegExp('早餐|早饭').hasMatch(text)) return findDefaultLedgerCategory('早餐');
    if (RegExp('午餐|午饭').hasMatch(text)) return findDefaultLedgerCategory('午餐');
    if (RegExp('晚餐|晚饭|夜宵').hasMatch(text)) {
      return findDefaultLedgerCategory('晚餐');
    }
    if (RegExp('咖啡').hasMatch(text)) return findDefaultLedgerCategory('咖啡');
    if (RegExp('奶茶|茶饮').hasMatch(text)) return findDefaultLedgerCategory('奶茶');
    if (RegExp('外卖|饿了么|美团').hasMatch(text)) {
      return findDefaultLedgerCategory('外卖');
    }
    if (RegExp('饭|餐|肯德基|麦当劳').hasMatch(text)) {
      return findDefaultLedgerCategory('三餐');
    }
    if (RegExp('买|购物|超市|淘宝|京东|拼多多').hasMatch(text)) {
      return findDefaultLedgerCategory('购物');
    }
    if (RegExp('零食|饮料|水果|蔬菜').hasMatch(text)) {
      if (text.contains('水果')) return findDefaultLedgerCategory('买菜');
      if (text.contains('蔬菜')) return findDefaultLedgerCategory('买菜');
      return findDefaultLedgerCategory('零食');
    }
    if (RegExp('药|医院|门诊|体检|医疗').hasMatch(text)) {
      return findDefaultLedgerCategory('医疗');
    }
    if (RegExp('书|课程|学习|培训').hasMatch(text)) {
      return findDefaultLedgerCategory('书籍');
    }
    if (RegExp('水费|电费|燃气|煤气|物业|话费|宽带|生活缴费').hasMatch(text)) {
      return findDefaultLedgerCategory('生活');
    }
    return findDefaultLedgerCategory('自定义');
  }

  LedgerCategory _categoryByName(
    String name,
    List<LedgerCategory> customCategories,
  ) {
    final all = [
      ...defaultExpenseLedgerCategories,
      ...customCategories.where((item) => item.kind == LedgerKind.expense),
    ];
    return all.firstWhere(
      (item) =>
          item.name == name ||
          item.id == name ||
          ledgerCategoryDisplayNameForSelection(item) == name,
      orElse: () => findDefaultLedgerCategory('自定义'),
    );
  }

  DateTime _todoDateTime(Todo todo) {
    final match = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(todo.time);
    final hour = (int.tryParse(match?.group(1) ?? '') ?? 9).clamp(0, 23);
    final minute = (int.tryParse(match?.group(2) ?? '') ?? 0).clamp(0, 59);
    return DateTime(
      todo.date.year,
      todo.date.month,
      todo.date.day,
      hour,
      minute,
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
    const codes = {'CNY', 'USD', 'EUR', 'JPY', 'HKD', 'GBP', 'KRW'};
    return codes.contains(normalized) ? normalized : 'CNY';
  }
}

class _TodoLedgerParse {
  final double amount;
  final String currency;
  final String categoryName;
  final String note;
  final bool aiGenerated;

  const _TodoLedgerParse({
    required this.amount,
    required this.currency,
    required this.categoryName,
    required this.note,
    required this.aiGenerated,
  });
}
