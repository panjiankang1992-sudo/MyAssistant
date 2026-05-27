import 'dart:convert';

import 'package:intl/intl.dart';

import '../../domain/models/ai_model_config.dart';
import '../../domain/models/quick_note.dart';
import '../../domain/models/tag.dart';
import '../copilot/services/openai_compatible_client.dart';
import 'builtin_skill_registry.dart';

class NoteAnalysisSkillResult {
  final QuickNote analysisDocument;
  final List<QuickNote> sourceNotes;

  const NoteAnalysisSkillResult({
    required this.analysisDocument,
    required this.sourceNotes,
  });
}

class NoteAnalysisDraft {
  final String category;
  final String subcategory;
  final String title;
  final String summary;
  final List<String> facts;
  final List<String> actions;
  final List<String> materials;
  final List<String> sourceNoteIds;

  const NoteAnalysisDraft({
    required this.category,
    required this.subcategory,
    required this.title,
    required this.summary,
    required this.facts,
    required this.actions,
    required this.materials,
    required this.sourceNoteIds,
  });
}

class NoteAnalysisSkill {
  final OpenAiCompatibleClient llmClient;

  NoteAnalysisSkill({OpenAiCompatibleClient? llmClient})
    : llmClient = llmClient ?? OpenAiCompatibleClient();

  Future<List<NoteAnalysisSkillResult>> run({
    required List<QuickNote> notes,
    required List<QuickNote> existingAnalysisDocs,
    required Set<String> analyzedSourceIds,
    required AiModelConfig? config,
  }) async {
    final rawNotes = notes
        .where(
          (note) =>
              !note.deleted &&
              !note.archived &&
              !note.isAnalysis &&
              (note.noteType == QuickNoteType.document ||
                  _isMeaningfulDiary(note)),
        )
        .toList();
    final pending = rawNotes
        .where((note) => !note.analyzed || !analyzedSourceIds.contains(note.id))
        .toList();
    if (pending.isEmpty) return [];

    final canUseAi =
        config != null &&
        config.apiKey.trim().isNotEmpty &&
        config.baseUrl.trim().isNotEmpty &&
        config.model.trim().isNotEmpty &&
        _estimatedInputSize(pending, existingAnalysisDocs) <= 60000;
    final drafts = canUseAi
        ? await _tryAiAnalyzeBatch(
            pending: pending,
            rawNotes: rawNotes,
            existingAnalysisDocs: existingAnalysisDocs,
            config: config,
          )
        : _localAnalyzeBatch(pending, existingAnalysisDocs);
    final effectiveDrafts = drafts.isEmpty
        ? _localAnalyzeBatch(pending, existingAnalysisDocs)
        : drafts;

    return effectiveDrafts.map((draft) {
      final existing = _findExistingDoc(existingAnalysisDocs, draft);
      final sourceIds = {...?existing?.sourceNoteIds, ...draft.sourceNoteIds};
      final sourceNotes =
          rawNotes.where((note) => sourceIds.contains(note.id)).toList()
            ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      return NoteAnalysisSkillResult(
        sourceNotes: sourceNotes,
        analysisDocument: _analysisDocumentFor(
          draft: draft,
          sourceNotes: sourceNotes,
          existing: existing,
        ),
      );
    }).toList();
  }

  Future<List<NoteAnalysisDraft>> _tryAiAnalyzeBatch({
    required List<QuickNote> pending,
    required List<QuickNote> rawNotes,
    required List<QuickNote> existingAnalysisDocs,
    required AiModelConfig? config,
  }) async {
    if (config == null) return const [];
    try {
      final reply = await llmClient.chat(
        config: config,
        messages: [
          LlmChatMessage(
            role: 'system',
            content: BuiltinSkillRegistry.noteAnalysis.prompt,
          ),
          LlmChatMessage(
            role: 'user',
            content: _batchInput(
              pending: pending,
              existingAnalysisDocs: existingAnalysisDocs,
            ),
          ),
        ],
      );
      return _decodeDrafts(reply, rawNotes);
    } catch (_) {
      return const [];
    }
  }

  int _estimatedInputSize(
    List<QuickNote> pending,
    List<QuickNote> existingAnalysisDocs,
  ) {
    final raw = pending.fold<int>(0, (sum, note) => sum + note.content.length);
    final summaries = existingAnalysisDocs.fold<int>(
      0,
      (sum, doc) =>
          sum +
          (doc.summary.isEmpty ? _summaryFromContent(doc.content) : doc.summary)
              .length,
    );
    return raw + summaries;
  }

  String _batchInput({
    required List<QuickNote> pending,
    required List<QuickNote> existingAnalysisDocs,
  }) {
    final rawText = pending
        .map(
          (note) =>
              'ID: ${note.id}\n'
              '标题: ${note.title}\n'
              '日期: ${DateFormat('yyyy-MM-dd HH:mm').format(note.updatedAt)}\n'
              '标签: ${note.tags.map((t) => t.name).join(', ')}\n'
              '内容:\n${note.content}\n---',
        )
        .join('\n');
    final existingText = existingAnalysisDocs
        .map(
          (doc) =>
              '文档ID: ${doc.id}\n'
              '分类: ${doc.category}/${doc.subcategory}\n'
              '标题: ${doc.title}\n'
              '摘要: ${doc.summary.isEmpty ? _summaryFromContent(doc.content) : doc.summary}\n'
              '来源ID: ${doc.sourceNoteIds.join(', ')}\n'
              '更新时间: ${DateFormat('yyyy-MM-dd HH:mm').format(doc.updatedAt)}\n'
              '---',
        )
        .join('\n');
    return '未归纳文档和有意义日记：\n${rawText.isEmpty ? "无新增文档或有效日记" : rawText}\n\n'
        '既有归纳文档，请读取并在同主题下编辑、合并、去重，不要忽略人工编辑内容：\n'
        '${existingText.isEmpty ? "无既有归纳文档" : existingText}';
  }

  List<NoteAnalysisDraft> _decodeDrafts(String raw, List<QuickNote> rawNotes) {
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw.trim());
    final decoded = jsonDecode(match?.group(0) ?? raw);
    final docs = decoded is Map<String, dynamic>
        ? decoded['documents'] as List<dynamic>? ?? const []
        : const [];
    final validSourceIds = rawNotes.map((note) => note.id).toSet();
    return docs
        .whereType<Map>()
        .map((rawDoc) {
          final doc = rawDoc.cast<String, dynamic>();
          final sourceIds = (doc['sourceNoteIds'] as List<dynamic>? ?? const [])
              .map((item) => '$item'.trim())
              .where(validSourceIds.contains)
              .toList();
          return NoteAnalysisDraft(
            category: _validCategory(doc['category'] as String?),
            subcategory: _compact(
              doc['subcategory'] as String?,
              fallback: '归纳',
            ),
            title: _compact(doc['title'] as String?, fallback: '未命名归纳'),
            summary: _compact(doc['summary'] as String?, fallback: '已完成归纳整理。'),
            facts: _stringList(doc['facts']),
            actions: _stringList(doc['actions']),
            materials: _stringList(doc['materials']),
            sourceNoteIds: sourceIds,
          );
        })
        .where((draft) => draft.sourceNoteIds.isNotEmpty)
        .toList();
  }

  List<NoteAnalysisDraft> _localAnalyzeBatch(
    List<QuickNote> pending,
    List<QuickNote> existingAnalysisDocs,
  ) {
    final groups = <String, List<QuickNote>>{};
    for (final note in pending) {
      final category = _inferCategory(note.title, note.content, note.tags);
      final subcategory = _inferSubcategory(note);
      groups.putIfAbsent('$category::$subcategory', () => []).add(note);
    }
    return groups.entries.map((entry) {
      final parts = entry.key.split('::');
      final notes = entry.value;
      final existing = existingAnalysisDocs.where((doc) {
        return doc.category == parts.first && doc.subcategory == parts.last;
      }).toList();
      final title = parts[1];
      final facts = <String>[];
      final actions = <String>[];
      final materials = <String>[];
      for (final doc in existing) {
        for (final item in _splitPoints(doc.content)) {
          facts.add(item);
        }
      }
      for (final note in notes) {
        for (final item in _splitPoints(note.content)) {
          if (_looksAction(item)) {
            actions.add(item);
          } else if (_looksMaterial(item)) {
            materials.add(item);
          } else {
            facts.add(item);
          }
        }
      }
      final allPoints = [...facts, ...actions, ...materials];
      return NoteAnalysisDraft(
        category: parts.first,
        subcategory: parts.last,
        title: title,
        summary: _summaryOf(allPoints, notes),
        facts: _dedupe(facts),
        actions: _dedupe(actions),
        materials: _dedupe(materials),
        sourceNoteIds: {
          ...existing.expand((doc) => doc.sourceNoteIds),
          ...notes.map((note) => note.id),
        }.toList(),
      );
    }).toList();
  }

  QuickNote _analysisDocumentFor({
    required NoteAnalysisDraft draft,
    required List<QuickNote> sourceNotes,
    QuickNote? existing,
  }) {
    final now = DateTime.now();
    final sourceIds = {
      ...?existing?.sourceNoteIds,
      ...sourceNotes.map((note) => note.id),
    }.toList();
    final previousContent = existing == null
        ? ''
        : '\n\n## 既有归纳\n${existing.content.trim()}';
    final content =
        '## 摘要\n${draft.summary}\n\n'
        '## 拆解\n${_sectionText(draft.facts, empty: "暂无可拆解信息。")}\n\n'
        '## 合并后的行动\n${_sectionText(draft.actions, empty: "暂无明确行动。")}\n\n'
        '## 可复用素材\n${_sectionText(draft.materials, empty: "暂无可复用素材。")}\n\n'
        '## 来源\n${_sourceText(sourceNotes)}'
        '$previousContent';
    return QuickNote(
      id: existing?.id ?? _documentId(draft.category, draft.subcategory),
      title: draft.title,
      content: content,
      summary: draft.summary,
      tags: _mergeTags(sourceNotes),
      date: sourceNotes.isEmpty
          ? DateTime(now.year, now.month, now.day)
          : sourceNotes.last.date,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      analyzed: true,
      isAnalysis: true,
      category: draft.category,
      subcategory: draft.subcategory,
      sourceNoteIds: sourceIds,
    );
  }

  QuickNote? _findExistingDoc(
    List<QuickNote> existingAnalysisDocs,
    NoteAnalysisDraft draft,
  ) {
    final id = _documentId(draft.category, draft.subcategory);
    return existingAnalysisDocs.where((doc) {
      return doc.id == id ||
          (doc.category == draft.category &&
              doc.subcategory == draft.subcategory);
    }).firstOrNull;
  }

  String _documentId(String category, String subcategory) {
    final key = '$category-$subcategory'
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5_-]'), '');
    return 'analysis-topic-$key';
  }

  String _sectionText(List<String> items, {required String empty}) {
    final cleaned = _dedupe(items);
    if (cleaned.isEmpty) return empty;
    return cleaned.map((item) => '- $item').join('\n');
  }

  String _sourceText(List<QuickNote> sourceNotes) {
    if (sourceNotes.isEmpty) return '- 暂无来源';
    return sourceNotes
        .map((note) {
          final time = DateFormat('yyyy-MM-dd HH:mm').format(note.updatedAt);
          return '- $time ${note.title}: ${_plain(note.content)}';
        })
        .join('\n');
  }

  List<Tag> _mergeTags(List<QuickNote> notes) {
    final map = <String, Tag>{};
    for (final note in notes) {
      for (final tag in note.tags) {
        map[tag.id] = tag;
      }
    }
    return map.values.take(8).toList();
  }

  String _inferCategory(String title, String content, List<Tag> tags) {
    final text = '$title $content ${tags.map((t) => t.name).join(" ")}';
    if (RegExp(
      'Flutter|AI|LLM|接口|代码|部署|GitHub|bug|模型|同步',
      caseSensitive: false,
    ).hasMatch(text)) {
      return '技术';
    }
    if (RegExp('会议|项目|客户|方案|排期|工作|日报').hasMatch(text)) {
      return '工作';
    }
    if (RegExp('钱|账|发票|消费|收入|支出|预算').hasMatch(text)) {
      return '财务';
    }
    if (RegExp('学|读|课程|书|资料').hasMatch(text)) {
      return '学习';
    }
    if (RegExp('健康|运动|睡眠|医疗|药').hasMatch(text)) {
      return '健康';
    }
    if (RegExp('买|购物|清单|牛奶|咖啡|地铁|猫粮|家务|餐饮').hasMatch(text)) {
      return '生活';
    }
    if (RegExp('灵感|想法|复盘|日记').hasMatch(text)) {
      return '灵感';
    }
    return '日常';
  }

  String _inferSubcategory(QuickNote note) {
    final text = '${note.title} ${note.content}';
    if (note.noteType == QuickNoteType.diary) return '日记洞察';
    if (RegExp('买|购物|清单|牛奶|咖啡|猫粮').hasMatch(text)) return '购物备忘';
    if (RegExp('地铁|公交|打车|交通').hasMatch(text)) return '出行交通';
    if (RegExp('会议|项目|排期').hasMatch(text)) return '项目推进';
    if (RegExp('Flutter|代码|接口|bug|部署|同步').hasMatch(text)) return '工程技术';
    if (RegExp('灵感|想法|整理|文档').hasMatch(text)) return '笔记习惯';
    if (RegExp('餐|咖啡|早餐|午餐|晚餐').hasMatch(text)) return '饮食记录';
    return '综合归纳';
  }

  bool _looksAction(String item) {
    return RegExp('要|需要|记得|提醒|安排|确认|购买|补|整理|处理|完成|看').hasMatch(item);
  }

  bool _isMeaningfulDiary(QuickNote note) {
    if (note.noteType != QuickNoteType.diary) return false;
    final text = _plain(note.content)
        .replaceAll(RegExp(r'[#>*`\[\]\-_=|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.length < 12) return false;
    if (RegExp(r'^\d{4}[-_\.年]\d{1,2}[-_\.月]\d{1,2}(日)?$').hasMatch(text)) {
      return false;
    }
    final invalidPatterns = [
      RegExp(r'^(无|暂无|今天无事|没什么|空|test|测试)$', caseSensitive: false),
      RegExp(r'^(todo|日记|随手记|记录)$', caseSensitive: false),
    ];
    if (invalidPatterns.any((pattern) => pattern.hasMatch(text))) return false;
    return RegExp(
      '想|计划|需要|完成|问题|方案|复盘|今天|明天|工作|生活|学习|项目|购物|健康|情绪|灵感|决定|记录|总结|发现',
    ).hasMatch(text);
  }

  bool _looksMaterial(String item) {
    return RegExp('想法|灵感|方案|资料|文档|内容|原则|经验').hasMatch(item);
  }

  List<String> _splitPoints(String content) {
    final text = _plain(content);
    final candidates = text
        .split(RegExp(r'[。；;\n]'))
        .expand((line) => line.split(RegExp(r'[,，、]')))
        .map((item) => item.trim())
        .where((item) => item.length >= 2)
        .toList();
    return candidates.isEmpty
        ? [text].where((item) => item.isNotEmpty).toList()
        : candidates;
  }

  List<String> _dedupe(List<String> items) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      final normalized = item.replaceAll(RegExp(r'\s+'), '');
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      result.add(item);
    }
    return result.take(12).toList();
  }

  List<String> _stringList(Object? value) {
    return (value as List<dynamic>? ?? const [])
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .take(12)
        .toList();
  }

  String _validCategory(String? value) {
    const values = {'日常', '工作', '技术', '生活', '学习', '财务', '健康', '灵感'};
    final trimmed = value?.trim();
    return values.contains(trimmed) ? trimmed! : '日常';
  }

  String _compact(String? value, {required String fallback}) {
    final text = (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return fallback;
    return text.length > 28 ? text.substring(0, 28) : text;
  }

  String _summaryOf(List<String> points, List<QuickNote> notes) {
    if (points.isEmpty) return '已读取 ${notes.length} 条文档/日记，完成主题归纳。';
    final merged = _dedupe(points).take(3).join('；');
    return '已读取 ${notes.length} 条文档/日记，拆解并合并为：$merged。';
  }

  String _summaryFromContent(String content) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
    final text = lines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '暂无摘要';
    return text.length > 160 ? '${text.substring(0, 160)}...' : text;
  }

  String _plain(String raw) {
    return raw
        .split('\n')
        .where((line) {
          final trimmed = line.trim();
          return !trimmed.startsWith('[图片]') &&
              !trimmed.startsWith('[附件]') &&
              !trimmed.startsWith('【网页快照】') &&
              !trimmed.startsWith('/');
        })
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
