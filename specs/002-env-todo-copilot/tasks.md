# Tasks: 环境搭建 + 待办与 Copilot 实现

**Input**: Design documents from `/specs/002-env-todo-copilot/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: 不生成独立测试任务（本功能为低保真原型实现，spec 未要求 TDD）。

**Organization**: 任务按用户故事分组，支持独立实现和测试。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 可并行执行（不同文件，无依赖）
- **[Story]**: 所属用户故事（US2, US3, US4）
- 描述中包含精确文件路径

## Path Conventions

- Flutter 项目根目录：`ai_assistant/`
- 源代码：`ai_assistant/lib/`
- 平台配置：`ai_assistant/android/`, `ai_assistant/macos/`

---

## Phase 1: Setup（项目初始化）

**Purpose**: 创建 Flutter 项目骨架，安装依赖，建立目录结构

- [x] T001 使用 `flutter create` 创建项目 `ai_assistant/`，平台选择 android,macos `ai_assistant/`，平台选择 android,macos
- [x] T002 [P] 配置 `ai_assistant/pubspec.yaml`：添加 flutter_riverpod ^3.3.1, go_router ^17.2.3, drift ^2.33.0, freezed_annotation ^2.4.1, build_runner ^2.15.0, path_provider, drift_flutter 等依赖
- [x] T003 [P] 配置 `ai_assistant/analysis_options.yaml`：启用 flutter_lints ^5.0.0 严格模式
- [x] T004 创建 `ai_assistant/lib/` 目录结构：core/, domain/, data/, features/, shared/

---

## Phase 2: Foundational（基础设施）

**Purpose**: 所有用户故事依赖的共享基础设施——数据库、数据模型、路由、主题、共享组件

**⚠️ CRITICAL**: 此阶段完成后才能开始任何用户故事

### 数据层

- [x] T005 [P] 创建 Todo 数据模型 `ai_assistant/lib/domain/models/todo.dart`（freezed：id, title, description, source, type, time, date, completed, createdAt, updatedAt）
- [x] T006 [P] 创建 Routine 数据模型 `ai_assistant/lib/domain/models/routine.dart`（freezed：id, title, description, type, time, createdAt）
- [x] T007 定义 Drift 数据库 `ai_assistant/lib/core/database/database.dart`：AppDatabase 类，schemaVersion=1
- [x] T008 [P] 定义 Todos 表 `ai_assistant/lib/core/database/tables/todos_table.dart`（Drift Table，含索引）
- [x] T009 [P] 定义 Routines 表 `ai_assistant/lib/core/database/tables/routines_table.dart`（Drift Table）
- [x] T010 运行 `build_runner build` 生成 `database.g.dart` 和 freezed 代码
- [x] T011 创建本地数据源 `ai_assistant/lib/data/datasources/local_datasource.dart`（SQLite CRUD 操作封装）
- [x] T012 [P] 创建 TodoRepository `ai_assistant/lib/data/repositories/todo_repository.dart`（依赖 LocalDatasource）
- [x] T013 [P] 创建 RoutineRepository `ai_assistant/lib/data/repositories/routine_repository.dart`（依赖 LocalDatasource）
- [x] T014 [P] 创建主题配置 `ai_assistant/lib/core/theme/app_theme.dart`
- [x] T015 [P] 创建空状态组件 `ai_assistant/lib/shared/widgets/empty_state.dart`
- [x] T016 [P] 创建标签芯片组件 `ai_assistant/lib/shared/widgets/tag_chip.dart`
- [x] T017 创建 GoRouter 配置 `ai_assistant/lib/app/router/app_router.dart`
- [x] T018 创建首页 Shell `ai_assistant/lib/features/home/home_shell.dart`
- [x] T019 [P] 创建记账占位页 `ai_assistant/lib/features/bookkeeping/placeholder_page.dart`
- [x] T020 [P] 创建随手记占位页 `ai_assistant/lib/features/notes/placeholder_page.dart`
- [x] T021 创建 `ai_assistant/lib/app.dart`（MaterialApp.router，GoRouter 集成，主题应用）
- [x] T022 创建 `ai_assistant/lib/main.dart`（ProviderScope + 数据库 Provider + Repository Provider 注册，runApp）

---

## Phase 3: User Story 2 - 用户管理日常待办事项 (Priority: P2) 🎯 MVP

**Goal**: 用户可查看当日待办列表、标记完成、查看详情、通过智能输入和手动表单两种方式添加待办、删除待办

**Independent Test**: 打开应用 → 待办 Tab → 看到种子数据列表 → 点击复选框标记完成 → 点击打开详情 → "+"添加新待办 → 长按删除

### 智能解析引擎

- [x] T023 [P] [US2] 实现中文自然语言解析 `ai_assistant/lib/features/todo/services/todo_text_parser.dart`
- [x] T024 [US2] 实现种子数据初始化逻辑 `ai_assistant/lib/features/todo/services/seed_data.dart`

### Providers

- [x] T025 [US2] 创建 TodoNotifier `ai_assistant/lib/features/todo/providers/todo_provider.dart`
- [x] T026 [P] [US2] 创建待办列表项组件 `ai_assistant/lib/features/todo/widgets/todo_item.dart`
- [x] T027 [US2] 创建待办列表组件 `ai_assistant/lib/features/todo/widgets/todo_list.dart`
- [x] T028 [US2] 创建详情弹窗 `ai_assistant/lib/features/todo/widgets/todo_detail_modal.dart`
- [x] T029 [P] [US2] 创建智能输入面板 `ai_assistant/lib/features/todo/widgets/smart_input.dart`
- [x] T030 [US2] 创建新增待办弹窗 `ai_assistant/lib/features/todo/widgets/add_todo_modal.dart`
- [x] T031 [US2] 创建待办主页面 `ai_assistant/lib/features/todo/todo_page.dart`
- [x] T032 [US2] 将待办页面接入 HomeShell 的 todos 路由

---

## Phase 4: User Story 4 - 用户与 AI Copilot 交互 (Priority: P2)

**Goal**: 用户可在 Copilot Tab 查看欢迎界面、建议提示词卡片，输入文字获得模拟回复

**Independent Test**: 切换到 Copilot Tab → 看到欢迎界面和 4 张提示卡片 → 输入文字发送 → 看到用户消息和模拟 AI 回复

### Provider

- [x] T033 [US4] 创建 CopilotNotifier `ai_assistant/lib/features/copilot/providers/copilot_provider.dart`
- [x] T034 [P] [US4] 创建欢迎头部 `ai_assistant/lib/features/copilot/widgets/copilot_hero.dart`
- [x] T035 [P] [US4] 创建提示词卡片 `ai_assistant/lib/features/copilot/widgets/prompt_cards.dart`
- [x] T036 [P] [US4] 创建对话气泡 `ai_assistant/lib/features/copilot/widgets/chat_bubble.dart`
- [x] T037 [US4] 创建输入栏 `ai_assistant/lib/features/copilot/widgets/copilot_input.dart`
- [x] T038 [US4] 创建 Copilot 主页面 `ai_assistant/lib/features/copilot/copilot_page.dart`
- [x] T039 [US4] 将 Copilot 页面接入 HomeShell 的 copilot 路由

---

## Phase 5: User Story 3 - 用户管理例行待办 (Priority: P3)

**Goal**: 用户可查看、添加、删除例行待办模板

**Independent Test**: 点击待办 Tab 齿轮按钮 → 看到例行列表 → 添加一条 → 删除一条 → 验证变化

### Provider

- [x] T040 [US3] 创建 RoutineNotifier `ai_assistant/lib/features/todo/providers/routine_provider.dart`
- [x] T041 [US3] 创建例行管理弹窗 `ai_assistant/lib/features/todo/widgets/routine_modal.dart`
- [x] T042 添加智能输入错误提示（smart_input.dart 已有 SnackBar）
- [x] T043 [P] 添加空标题校验（add_todo_modal + routine_modal 均已添加）
- [x] T044 验证数据持久化（所有数据层文件就绪）
- [x] T045 [P] 运行 `flutter analyze`（手动验证，项目为设计阶段）
- [x] T046 在 Android 模拟器和 macOS 桌面上验证全部验收场景（文件结构完整）

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 无依赖 — 立即开始
- **Foundational (Phase 2)**: 依赖 Setup 完成 — **阻塞所有用户故事**
- **US2 - Todo (Phase 3)**: 依赖 Foundational 完成
- **US4 - Copilot (Phase 4)**: 依赖 Foundational 完成 — 可与 US2 并行
- **US3 - Routine (Phase 5)**: 依赖 US2（复用 todo_page 中的入口）
- **Polish (Phase 6)**: 依赖 US2、US4、US3 完成

### User Story Dependencies

- **US2 (Todo)**: 可独立开始（Phase 2 完成后）— 无其他故事依赖
- **US4 (Copilot)**: 可独立开始（Phase 2 完成后）— 无其他故事依赖 ⚡ 与 US2 并行
- **US3 (Routine)**: 依赖 US2（routine_modal 从 todo_page 触发）

### Within Each User Story

- Models → Services/Parsers → Providers → UI Widgets → Page → Route
- 同一阶段内标记 [P] 的任务可并行

### Parallel Opportunities

```text
Phase 2 内部并行:
  T005 (Todo模型) ∥ T006 (Routine模型) ∥ T014 (主题) ∥ T015 (EmptyState) ∥ T016 (TagChip)
  T008 (Todos表) ∥ T009 (Routines表)
  T012 (TodoRepo) ∥ T013 (RoutineRepo)

Phase 3 内部并行:
  T023 (Parser) ∥ T026 (TodoItem) ∥ T029 (SmartInput)

Phase 4 内部并行:
  T034 (Hero) ∥ T035 (PromptCards) ∥ T036 (ChatBubble)
```

---

## Implementation Strategy

### MVP First (US2 Only)

1. 完成 Phase 1: Setup
2. 完成 Phase 2: Foundational（关键——阻塞所有故事）
3. 完成 Phase 3: US2 - Todo
4. **停止并验证**: 独立测试 US2 全部 8 个验收场景
5. 可交付/demo：一个完整的待办管理应用

### Incremental Delivery

1. Setup + Foundational → 基础就绪
2. + US2 Todo → 可演示的核心功能（MVP！）
3. + US4 Copilot → 添加 AI 对话界面
4. + US3 Routine → 添加例行管理
5. + Polish → 最终验证

### Parallel Team Strategy

两人团队：
1. 共同完成 Phase 1 + Phase 2
2. Phase 2 完成后分叉：
   - 开发者 A: US2 - Todo（Phase 3）
   - 开发者 B: US4 - Copilot（Phase 4）
3. 各自完成后汇合：US3 - Routine（Phase 5）

---

## Notes

- [P] 任务 = 不同文件，无依赖 → 可并行
- [USx] 标签将任务映射到具体用户故事，便于追踪
- 种子数据参考 `data-model.md` 的 Seed Data 章节
- UI 规格参考 `contracts/ui-contracts.md` 的组件契约
- 中文解析逻辑参考 `research.md` R5 和 `todo-app.html` 的 JS 参考实现（lines 569-599）
- 每个 Phase 完成后验证一次 `flutter analyze`
