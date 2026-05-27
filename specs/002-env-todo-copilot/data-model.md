# Data Model: 待办与 Copilot

**Feature**: 002-env-todo-copilot
**Source**: spec.md → Key Entities + Functional Requirements

---

## Entity: Todo（待办）

代表用户的一条待办事项，是核心业务实体。

| Field | Type | Required | Description | Validation |
|-------|------|----------|-------------|------------|
| id | String (UUID) | Yes | 唯一标识符 | UUID v4 |
| title | String | Yes | 待办标题 | 非空，≤200 字符 |
| description | String? | No | 详细描述 | ≤2000 字符 |
| source | Enum | Yes | 来源标签 | recommend / routine / message / calendar |
| type | Enum | Yes | 类型标签 | bill / work / personal / health |
| time | String | Yes | 时间 (HH:mm) | 格式 09:00~23:59 或 --:-- |
| date | DateTime | Yes | 日期（仅日期部分） | 有效日期 |
| completed | bool | Yes | 完成状态 | true/false，默认 false |
| createdAt | DateTime | Yes | 创建时间 | 自动生成 |
| updatedAt | DateTime | Yes | 最后更新时间 | 自动生成 |

### State Transitions

```
         create
  (none) ──────→ pending (completed=false)
                      │
                toggle │  ← toggle
                      ↓
                  done (completed=true)
                      │
                delete │
                      ↓
                  (removed)
```

### Validation Rules

- **title**: 去除首尾空白后不能为空
- **type**: 必须为 `bill` | `work` | `personal` | `health` 之一
- **source**: 必须为 `recommend` | `routine` | `message` | `calendar` 之一
- **time**: 格式 `HH:mm`（00:00-23:59），或占位值 `--:--`
- **date**: 有效日期，建议范围为当日前后 365 天

### Database Mapping (Drift)

```dart
// lib/core/database/tables/todos_table.dart
class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get source => text()();        // 'recommend'|'routine'|'message'|'calendar'
  TextColumn get type => text()();           // 'bill'|'work'|'personal'|'health'
  TextColumn get time => text()();           // 'HH:mm'
  DateTimeColumn get date => dateTime()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

## Entity: Routine（例行待办模板）

代表可复用的例行待办模板，不直接出现在待办列表中。

| Field | Type | Required | Description | Validation |
|-------|------|----------|-------------|------------|
| id | int (auto-increment) | Yes | 唯一标识符 | 自增 |
| title | String | Yes | 模板标题 | 非空，≤200 字符 |
| description | String? | No | 模板描述（如执行频率） | ≤2000 字符 |
| type | Enum | Yes | 类型标签 | bill / work / personal / health |
| time | String | Yes | 默认时间 (HH:mm) | 格式 09:00~23:59 或 --:-- |
| createdAt | DateTime | Yes | 创建时间 | 自动生成 |

### Validation Rules

- **title**: 去除首尾空白后不能为空
- **type**: 同 Todo
- **time**: 同 Todo

### Database Mapping (Drift)

```dart
// lib/core/database/tables/routines_table.dart
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get type => text()();           // 'bill'|'work'|'personal'|'health'
  TextColumn get time => text()();           // 'HH:mm'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

## Entity: ChatMessage（Copilot 对话消息）

代表 Copilot 对话中的一条消息，本 Phase 仅使用本地模拟数据。

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String (UUID) | Yes | 唯一标识符 |
| role | Enum | Yes | user / assistant |
| content | String | Yes | 消息文本内容 |
| type | Enum | Yes | thinking / toolCall / result / error / text |
| timestamp | DateTime | Yes | 消息时间戳 |

> **Note**: Phase 2 中 ChatMessage 不持久化到数据库（内存存储），后续 Phase 接入真实 AI 后端时再决定是否持久化。

---

## Entity Relationships

```
┌─────────────┐          ┌─────────────┐
│    Todo     │          │   Routine   │
├─────────────┤          ├─────────────┤
│ id (UUID)   │          │ id (int)    │
│ title       │          │ title       │
│ description │          │ description │
│ source      │          │ type        │
│ type        │          │ time        │
│ time        │          │ createdAt   │
│ date        │          └─────────────┘
│ completed   │
│ createdAt   │              独立实体，无外键关系
│ updatedAt   │              Routine 是模板，不直接关联 Todo
└─────────────┘

┌──────────────────┐
│   ChatMessage    │
├──────────────────┤
│ id (UUID)        │
│ role             │
│ content          │
│ type             │
│ timestamp        │
└──────────────────┘
     内存存储，不持久化
```

---

## Seed Data

应用首次启动时插入示例待办数据，方便演示和测试：

```dart
final seedTodos = [
  Todo(title: '缴纳本月物业费', description: '线上缴费，支付宝可支付', source: 'recommend', type: 'bill', time: '09:00', date: today),
  Todo(title: '周报撰写与提交', description: '汇总本周工作进展与下周计划', source: 'routine', type: 'work', time: '14:30', date: today),
  Todo(title: '回复客户邮件', description: '关于项目二期方案反馈', source: 'message', type: 'work', time: '11:00', date: today),
  Todo(title: '购买生日礼物', description: '给妈妈选一件羊绒衫', source: 'recommend', type: 'personal', time: '16:00', date: today),
  Todo(title: '健身房上肢训练', description: '引体向上 4组，卧推 4组', source: 'routine', type: 'health', time: '18:30', date: today),
  Todo(title: '季度预算评审会', description: '准备Q3预算数据和PPT', source: 'calendar', type: 'work', time: '10:00', date: tomorrow),
];

final seedRoutines = [
  Routine(title: '周报撰写', description: '每周五下午提交周报', type: 'work', time: '14:30'),
  Routine(title: '健身房训练', description: '周一三五上肢，周二四六下肢', type: 'health', time: '18:30'),
];
```
