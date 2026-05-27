import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'builtin_skill.dart';

class BuiltinSkillRegistry {
  static const noteAnalysis = BuiltinSkill(
    id: 'note_archive_analysis',
    name: '随手记归纳分析',
    summary: '读取未归纳的文档和有意义日记，拆解信息点、合并相近主题、格式化为可编辑归纳文档',
    description:
        '借鉴 Obsidian + LLM 的 vault 工作流：日记和文档原文保持不变，处理文档和有意义日记，'
        '先拆解为事实、行动和素材，再把相近主题合并为结构化文档，方便后续搜索、整理和二次编辑。',
    inputSchema: 'raw_notes: [{id,title,content,tags,date,updatedAt}]',
    outputSchema:
        'documents: [{category,subcategory,title,summary,facts,actions,materials,sourceNoteIds}]',
    prompt:
        '你是随手记归纳助手。保留日记和文档原文，只生成可编辑的归纳文档。'
        '读取文档类输入笔记，并从日记中过滤空内容、模板和无意义碎片，只保留有信息量的日记。'
        '先拆解为事实、行动、素材，再合并相近主题并格式化。'
        '既有归纳文档默认只提供摘要用于判断是否命中；若命中同主题，可更新原文档。'
        '只返回 JSON，不要 Markdown。顶层字段 documents。每个文档字段：'
        'category, subcategory, title, summary, facts, actions, materials, sourceNoteIds。'
        'category 只能从 日常, 工作, 技术, 生活, 学习, 财务, 健康, 灵感 中选择。'
        'subcategory 用 2 到 6 个中文字，适合作为二级文件夹。'
        'facts/actions/materials 都是中文字符串数组。sourceNoteIds 必须来自输入 ID。',
    icon: Icons.auto_fix_high_rounded,
    color: AppColors.primary,
  );

  static const appData = BuiltinSkill(
    id: 'app_data',
    name: '应用数据总览',
    summary: '读取个人信息、待办、记账、随手记、标签、动作、来源和模型配置摘要',
    description: '为 Copilot 提供本地应用数据上下文，只读取必要摘要，不直接修改数据，并按用户友好的格式输出。',
    inputSchema: 'user_query',
    outputSchema: 'markdown_summary',
    prompt:
        '读取本应用本地数据摘要，并基于真实数据回答。查询类回答使用 Markdown 表格；'
        '不要暴露 source/action 等内部枚举值。',
    icon: Icons.storage_rounded,
    color: AppColors.success,
  );

  static const todoQuery = BuiltinSkill(
    id: 'todo_query',
    name: '代办查询',
    summary: '按日期查询代办列表，使用红黄绿灯展示逾期、待处理、已完成状态',
    description: '读取本地代办和例行生成项，输出时间、标题、标签、来源、动作和完成率。',
    inputSchema: 'date_or_range + optional filters(tags, source, action)',
    outputSchema: 'markdown_table(status_light,time,title,tags,source,action)',
    prompt:
        '查询代办时必须使用红黄绿灯：🔴 逾期，🟡 待处理，🟢 已完成。'
        '列表使用 Markdown 表格，并把 routine/bookkeeping 等内部值转成中文。',
    icon: Icons.check_circle_rounded,
    color: AppColors.primary,
  );

  static const todoStats = BuiltinSkill(
    id: 'todo_stats',
    name: '代办统计分析',
    summary: '统计代办总量、完成率、逾期、标签、来源和动作分布',
    description: '用于回答今天、本周或指定范围内的代办状态分析。',
    inputSchema: 'date_or_range + optional group_by',
    outputSchema: 'markdown_summary + markdown_table',
    prompt: '先给出红黄绿灯摘要，再用表格展示分组数据和异常项。',
    icon: Icons.traffic_rounded,
    color: AppColors.warning,
  );

  static const ledgerQuery = BuiltinSkill(
    id: 'ledger_query',
    name: '记账查询',
    summary: '按日期查询账单流水，展示收入、支出、净额和分类明细',
    description: '读取本地记账数据，输出当天或指定日期的账单列表。',
    inputSchema: 'date_or_range + optional category/type',
    outputSchema: 'markdown_table(time,category,type,amount,note)',
    prompt: '金额保留两位小数，收入使用正向表达，支出使用负向表达，分类展示图标和中文名。',
    icon: Icons.receipt_long_rounded,
    color: AppColors.primary,
  );

  static const ledgerStats = BuiltinSkill(
    id: 'ledger_stats',
    name: '收支统计分析',
    summary: '按分类、日期或周期统计收入、支出、净额和占比',
    description: '用于回答消费结构、收入支出趋势、分类排名等问题。',
    inputSchema: 'period(day/week/month/year) + optional filters',
    outputSchema: 'markdown_summary + category_rank_table',
    prompt: '先展示收入、支出、净额，再按分类给出排行和占比。',
    icon: Icons.pie_chart_rounded,
    color: AppColors.success,
  );

  static const noteQuery = BuiltinSkill(
    id: 'note_query',
    name: '随手记查询',
    summary: '查询日记、文档、归纳文档和最近更新摘要',
    description: '读取本地随手记数据，区分日记、文档和归纳文档，并展示标签与更新时间。',
    inputSchema: 'date_or_keyword + optional note_type',
    outputSchema: 'markdown_table(date,type,title,tags)',
    prompt: '默认读取摘要；需要编辑时再读取全文。输出时区分日记、文档、归纳。',
    icon: Icons.edit_note_rounded,
    color: AppColors.primary,
  );

  static const planning = BuiltinSkill(
    id: 'planning',
    name: '计划拆解',
    summary: '基于应用数据把目标拆解为可执行步骤',
    description: '把用户目标整理成短步骤、优先级和下一步动作。',
    inputSchema: 'goal + optional app_data',
    outputSchema: 'action_plan',
    prompt: '把目标拆成可执行步骤，输出要简洁、中文、可落地。',
    icon: Icons.route_rounded,
    color: AppColors.warning,
  );

  static const todoImport = BuiltinSkill(
    id: 'todo_import',
    name: '代办导入',
    summary: '智能识别 CSV、JSON、Markdown 清单、纯文本等数据源，转换为代办字段并调用内部代办导入工具',
    description:
        '读取用户提供的数据源摘要，自动判断标题、详情、日期、时间、标签、来源、动作和完成状态，'
        '输出标准 Todo 导入数据；缺失时间时使用当天合理默认值，无法识别的字段写入详情。',
    inputSchema: 'source_path_or_text + optional mapping_hint',
    outputSchema:
        'todos: [{title,description,date,time,tags,source,action,completed}]',
    prompt:
        '你是代办导入助手。先判断数据源格式，再抽取为标准代办数组。'
        '字段包括 title, description, date, time, tags, source, action, completed。'
        '日期和时间必须规范化；标签去重；不要丢弃无法映射的信息，把它追加到 description。'
        '确认后调用应用内部代办导入工具执行写入。',
    icon: Icons.playlist_add_check_rounded,
    color: AppColors.success,
  );

  static const bookkeepingImport = BuiltinSkill(
    id: 'bookkeeping_import',
    name: '记账导入',
    summary: '智能识别账单、流水、CSV、表格文本等数据源，转换为收入/支出账单并调用内部记账导入工具',
    description: '分析金额、币种、收支方向、分类、日期、备注和标签；遇到自然语言流水时自动判断消费/收入类型。',
    inputSchema: 'source_path_or_text + optional mapping_hint',
    outputSchema: 'entries: [{type,amount,currency,date,category,note,tags}]',
    prompt:
        '你是记账导入助手。先判断数据源格式，再抽取为标准账单数组。'
        '字段包括 type(expense/income), amount, currency, date, category, note, tags。'
        '金额必须保留原值精度；日期必须规范化；分类应匹配应用已有分类，无法匹配时使用“其他”。'
        '确认后调用应用内部记账导入工具执行写入。',
    icon: Icons.receipt_long_rounded,
    color: AppColors.primary,
  );

  static const noteImport = BuiltinSkill(
    id: 'note_import',
    name: '随手记导入',
    summary: '智能识别 Markdown、TXT、网页快照、图片附件说明等数据源，分别导入为日记或文档',
    description:
        '保留 Markdown 正文、标题、标签、附件线索、创建/修改日期；标题或文件名是日期时导入到日记，'
        '并以文件名日期作为创建和修改时间；其他资料导入到文档。',
    inputSchema: 'source_path_or_text + optional mapping_hint',
    outputSchema:
        'notes: [{noteType(diary/document),title,content,summary,date,createdAt,updatedAt,tags,category,attachments}]',
    prompt:
        '你是随手记导入助手。先判断数据源格式，再抽取为标准随手记数组。'
        '保留 Markdown、代码块、表格和引用。标题或文件名包含日期时 noteType=diary，导入到日记，'
        'createdAt 和 updatedAt 都使用该日期当天 00:00；其他内容 noteType=document，导入到文档。'
        '生成摘要、标签和分类；确认后调用应用内部随手记导入工具执行写入。',
    icon: Icons.note_add_rounded,
    color: AppColors.primary,
  );

  static const all = [
    appData,
    todoQuery,
    todoStats,
    ledgerQuery,
    ledgerStats,
    noteQuery,
    planning,
    noteAnalysis,
    todoImport,
    bookkeepingImport,
    noteImport,
  ];

  static String copilotSystemText() {
    return all.map((skill) => '- ${skill.copilotLine}').join('\n');
  }
}
