# Implementation Plan: 环境搭建 + 待办与 Copilot 实现

**Branch**: `002-env-todo-copilot` | **Date**: 2026-05-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-env-todo-copilot/spec.md`

## Summary

本项目为 AI 个人助手应用的首个可运行版本。分为两阶段：Phase 1 完成 Flutter 跨平台开发环境搭建（Android + macOS），Phase 2 基于低保真原型实现待办管理（Todo）和 Copilot 交互两个核心模块的 UI。待办数据本地持久化（Drift/SQLite），Copilot 使用本地模拟回复（不接入真实 AI 后端）。

## Technical Context

**Language/Version**: Dart 3.11.5+ (Flutter 3.41.7 stable)

**Primary Dependencies**: flutter_riverpod ^3.0.0, go_router ^14.0.0, drift ^2.18.0, freezed_annotation ^2.4.1, build_runner ^2.4.0

**Storage**: 本地 SQLite (Drift ORM + drift_dev 代码生成)

**Testing**: flutter_test (widget + unit tests)

**Target Platform**: Android 模拟器 (API 34+), macOS 桌面 (Ventura 13+)

**Project Type**: 跨平台移动 + 桌面应用（单代码库，Flutter Platform Channel 预留原生扩展位）

**Performance Goals**: 首屏渲染 <2s, 60fps 滚动, Copilot 模拟回复 <1s

**Constraints**: 纯本地应用（Phase 2 无后端），数据本地持久化，离线可用

**Scale/Scope**: 4 个 Tab（待办/记账/随手记/Copilot），2 个核心实体（Todo、Routine），14 项功能需求

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

> 项目宪章（constitution.md）当前为模板状态，未定义具体的核心原则。本次规划按标准 Flutter 项目最佳实践执行，待宪章填充后重新评估。

| Gate | Status | Notes |
|------|--------|-------|
| Constitution defined | ⚠️ Skipped | 宪章为模板，无具体原则 |
| Architecture compliance | N/A | 遵循 Flutter 社区标准分层架构 |
| Testing requirements | N/A | 按项目惯例执行 widget test + unit test |

**Gate Result**: PASS (无阻塞违规)

## Project Structure

### Documentation (this feature)

```text
specs/002-env-todo-copilot/
├── spec.md              # Feature specification
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (UI component contracts)
│   └── ui-contracts.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
ai_assistant/
├── lib/
│   ├── main.dart                           # 应用入口 + ProviderScope
│   ├── app.dart                            # MaterialApp + GoRouter 配置
│   │
│   ├── core/                               # 核心基础设施
│   │   ├── database/                       # Drift 数据库
│   │   │   ├── database.dart               # AppDatabase 定义
│   │   │   ├── tables/                     # 表定义
│   │   │   │   ├── todos_table.dart
│   │   │   │   └── routines_table.dart
│   │   │   └── database.g.dart             # drift_dev 生成
│   │   └── theme/                          # 主题配置
│   │       └── app_theme.dart
│   │
│   ├── domain/                             # 领域层（纯 Dart）
│   │   └── models/
│   │       ├── todo.dart                   # Todo 数据模型 (freezed)
│   │       └── routine.dart                # Routine 数据模型 (freezed)
│   │
│   ├── data/                               # 数据层
│   │   ├── repositories/
│   │   │   ├── todo_repository.dart
│   │   │   └── routine_repository.dart
│   │   └── datasources/
│   │       └── local_datasource.dart       # SQLite CRUD 操作
│   │
│   ├── features/                           # 功能模块
│   │   ├── home/                           # 首页 Shell（BottomNavigationBar）
│   │   │   └── home_shell.dart
│   │   ├── todo/                           # 待办模块
│   │   │   ├── todo_page.dart              # 待办主页面
│   │   │   ├── widgets/
│   │   │   │   ├── todo_list.dart          # 待办列表
│   │   │   │   ├── todo_item.dart          # 单条待办组件
│   │   │   │   ├── todo_detail_modal.dart  # 详情弹窗
│   │   │   │   ├── add_todo_modal.dart     # 新增弹窗（智能+手动）
│   │   │   │   ├── smart_input.dart        # 智能输入面板
│   │   │   │   └── routine_modal.dart      # 例行管理弹窗
│   │   │   └── providers/
│   │   │       ├── todo_provider.dart       # Riverpod providers
│   │   │       └── routine_provider.dart
│   │   ├── copilot/                        # Copilot 模块
│   │   │   ├── copilot_page.dart
│   │   │   ├── widgets/
│   │   │   │   ├── copilot_hero.dart       # 欢迎头部
│   │   │   │   ├── prompt_cards.dart       # 建议提示词卡片
│   │   │   │   ├── chat_bubble.dart        # 对话气泡
│   │   │   │   └── copilot_input.dart      # 输入栏（模型选择+发送）
│   │   │   └── providers/
│   │   │       └── copilot_provider.dart
│   │   ├── bookkeeping/                    # 记账（占位）
│   │   │   └── placeholder_page.dart
│   │   └── notes/                          # 随手记（占位）
│   │       └── placeholder_page.dart
│   │
│   └── shared/                             # 共享 UI 组件
│       └── widgets/
│           ├── empty_state.dart            # 空状态组件
│           └── tag_chip.dart               # 标签芯片
│
├── test/
│   ├── domain/
│   │   └── models/
│   │       └── todo_test.dart
│   ├── features/
│   │   └── todo/
│   │       └── todo_page_test.dart
│   └── core/
│       └── database/
│           └── database_test.dart
│
├── pubspec.yaml
└── analysis_options.yaml
```

**Structure Decision**: 采用 Flutter 社区标准的 feature-first 分层架构。`lib/features/` 按 Tab 模块划分，每个模块内 widgets/ + providers/ 自包含。`lib/core/` 存放数据库和主题等横向基础设施。`lib/domain/` 和 `lib/data/` 做数据层解耦，为后续接入服务端 API 预留接口抽象。

## Complexity Tracking

| Decision | Rationale | Simpler Alternative Rejected |
|----------|-----------|------------------------------|
| Drift ORM 而非直接 sqflite | 类型安全、代码生成、与 Riverpod 天然适配、后续服务端同步时实体定义可复用 | 直接 sqflite（无类型安全，手写 SQL 易出错） |
| freezed 数据模型 | 不可变模型、copyWith、JSON 序列化、与 Riverpod 配合良好 | 手写 Dart 类（样板代码多，容易遗漏 equality/hashCode） |
| 单体 lib/ 架构（无 packages） | Phase 2 仅有 2 个核心模块，拆分包过早 | monorepo with packages（过度工程化，管理成本高） |
