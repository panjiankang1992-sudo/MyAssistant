# UI Component Contracts

**Feature**: 002-env-todo-copilot
**Purpose**: Define component interfaces for consistent UI assembly

---

## Layout Shell

### BottomNavigationBar

```
┌──────────────────────────────────────────────┐
│  [ ✓ 待办 ]  [ ¥ 记账 ]  [ ✎ 随手记 ]  [ ✦ Copilot ]  │
└──────────────────────────────────────────────┘
```

**Contract**:
- 4 tabs, fixed position at bottom
- Active tab: accent color + icon lift animation
- Inactive tab: tertiary text color
- Switching tabs updates AppBar title accordingly

### AppBar

- Title reflects current tab: "今日待办" / "记账" / "随手记" / "Copilot"
- Todo tab additionally shows rotating poetry line below title
- Right side: avatar button → slides out profile panel

---

## Todo Module

### Todo List (todo_list.dart)

**Input**: `List<Todo>` filtered to today's date
**States**:
- **Empty**: icon + "暂无待办事项" + "点击右下角 + 添加" hint
- **Populated**: scrollable list of `TodoItem` widgets

### Todo Item (todo_item.dart)

**Contract**:
```
┌───────────────────────────────────────────────────┐
│ [○]  缴纳本月物业费         [💰]                    │
│       推荐 · 帐单 · 09:00                          │
└───────────────────────────────────────────────────┘
```

- **Tap**: opens DetailModal
- **Checkbox tap**: toggles completion (prevents event bubbling)
- **Long press**: shows context menu (delete)
- **Action button** (right): type-sensitive (bill → 一键记账, work → 开始, personal → 操作)
- **Completed state**: opacity 0.55, title line-through + italic, checkbox filled green

### Tag Chips

| Tag | Type | Colors |
|-----|------|--------|
| 推荐 | source:recommend | bg:#e8f2fd, text:#0071e3 |
| 例行 | source:routine | bg:#fef3e0, text:#ff9500 |
| 消息 | source:message | bg:#eaf5ea, text:#34c759 |
| 日历 | source:calendar | bg:#f0e6ff, text:#7c3aed |
| 帐单 | type:bill | bg:#fce4ec, text:#e91e63 |
| 工作 | type:work | bg:#e8f2fd, text:#0071e3 |
| 个人 | type:personal | bg:#f3e8ff, text:#af52de |
| 健康 | type:health | bg:#e8faf3, text:#1abc9c |

### Detail Modal (todo_detail_modal.dart)

**Contract**: Bottom sheet modal with:
- Handle bar
- Title (h2)
- Source & Type tags row
- Description section (hidden if empty)
- Time section
- Action buttons row: "关闭" (secondary) + action button (primary, type-sensitive)

### Add Todo Modal (add_todo_modal.dart)

**Contract**: Bottom sheet with two tabs:

1. **Smart Input Tab** (default):
   - Text input row with voice mic button
   - Analyzing state (dot spinner + "正在分析…")
   - Preview card: title, type, time, date, source, description
   - Confirm / Reset buttons

2. **Manual Input Tab**:
   - Form fields: title (required), description, type (dropdown), date (picker), time (picker), source (dropdown)
   - Save / Cancel buttons

### Smart Input Parser

**Input**: Natural language Chinese string
**Output**: `ParsedTodo { title, type, time, date, source, description }`

**Classification rules**:
| Keywords | Type |
|----------|------|
| 会议/开会/汇报/周报/项目/客户/产品/方案/评审/排期 | work |
| 帐单/缴费/物业/房租/还钱/付款/报销/水电 | bill |
| 健身/跑步/游泳/体检/医院/药 | health |
| 买/购物/聚会/吃饭/电影/旅行/生日/礼物 | personal |

**Time extraction**:
| Pattern | Result |
|---------|--------|
| `\d{1,2}[点:：]\d{0,2}` | Extracted time |
| 早上 (no explicit time) | 08:00 |
| 上午 (no explicit time) | 10:00 |
| 中午 | 12:00 |
| 下午 (no explicit time) | 15:00 |
| 晚上 (no explicit time) | 19:00 |

**Date extraction**:
| Pattern | Result |
|---------|--------|
| 今天 | today |
| 明天 | today + 1 |
| 后天 | today + 2 |
| 下周X | next weekday X |
| 周X | this/next weekday X |

### Routine Modal (routine_modal.dart)

**Contract**: Bottom sheet with:
- Routine list with delete buttons
- "添加例行待办" button → opens add routine sub-modal
- Close button

---

## Copilot Module

### Hero Section (copilot_hero.dart)

```
        [ ✦ ]
     你好，[用户名]
   我能帮你做些什么？
```

- Icon: gradient circle
- Greeting: personalized (hardcoded "李明" for Phase 2)
- Subtitle: muted text

### Prompt Cards (prompt_cards.dart)

**Contract**: 4 suggestion cards with icon + text, tappable:
| Icon | Text |
|------|------|
| 📊 | 分析本月消费趋势，给出省钱建议 |
| 📋 | 总结我本周的工作内容，生成周报 |
| 📅 | 根据待办事项安排明天的日程 |
| 💡 | 提醒我有哪些即将到期的待办 |

### Chat Area

**Contract**: Scrollable list of `ChatBubble` widgets
- User messages: right-aligned, accent background
- Assistant messages: left-aligned, card background
- Thinking state: dot animation placeholder
- Empty state: show hero + prompt cards

### Input Bar (copilot_input.dart)

```
┌─────────────────────────────────────────────┐
│ [Model Select ▼]  [输入你的问题…        ] [↑] │
└─────────────────────────────────────────────┘
```

- Model selector: dropdown with Claude Opus / Sonnet / Haiku (UI only, no effect)
- Text input: placeholder "输入你的问题…"
- Send button: sends message → appends to chat with mock response

### Mock Response Logic

```
User sends message
  → Append user bubble to chat
  → Show 1-2s typing indicator
  → Append assistant bubble with preset response:
     "这是一个模拟回复。完整的 AI 对话功能将在后续版本中实现。"
```

---

## Shared Components

### Empty State (empty_state.dart)

**Contract**: Centered column with:
- Large emoji icon (48px)
- Primary text
- Optional secondary hint text

### Placeholder Page

**Contract**: Used for 记账 and 随手记 tabs:
- Centered: large icon + "功能开发中" text

### Profile Panel (slide-out drawer)

**Contract**: Right-side panel with backdrop:
- Avatar + name + email
- Menu items: 个人信息 / 通知设置 / 主题设置 / 数据管理 / 帮助与反馈

### Toast (toast.dart)

**Contract**: Overlay positioned at top center:
- Dark background, white text
- Auto-dismiss after 1.8s
- Slide/fade animation
