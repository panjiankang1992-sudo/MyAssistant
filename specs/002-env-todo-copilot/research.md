# Research: 环境搭建 + 待办与 Copilot

**Feature**: 002-env-todo-copilot
**Date**: 2026-05-16

---

## R1: Flutter 版本与核心依赖选择

**Decision**: Flutter 3.41.7 (Dart 3.7.x), flutter_riverpod 3.3.1, go_router 17.2.3, drift 2.33.0

**Rationale**: 
- Flutter 3.41.7 是当前最新稳定 hotfix，修复了 macOS App Store 上传和 iOS 模拟器的 native assets 阻塞问题（flutter/flutter#178623, flutter/flutter#178602），这些修复是 drift 2.33.0 正常工作的前提（drift#3710）
- flutter_riverpod 3.3.1 是 Riverpod 3.x 最新稳定版，支持 `@riverpod` 代码生成注解
- go_router 17.2.3 是当前最新，`StatefulShellRoute.indexedStack` 原生支持多标签底部导航的状态保持
- drift 2.33.0 已迁移到 sqlite3 3.x，在 Flutter 3.41+ 上完全兼容

**Alternatives considered**:
- go_router 14.x (旧版 API 已弃用 → 拒绝)
- Riverpod 2.x (功能已冻结，3.x 是当前主流)
- sqflite 替代 drift (缺少类型安全和代码生成 → 拒绝)

**Source**: pub.dev + drift#3710 + Flutter CHANGELOG

---

## R2: 底部导航架构模式

**Decision**: `StatefulShellRoute.indexedStack` + `StatefulNavigationShell`

**Rationale**:
- go_router 17.x 的原生方案，无需手动管理 selectedIndex
- 每个 Tab 保留独立导航栈（如待办详情在 Tab 0 栈内导航）
- `StatefulNavigationShell` 内置状态管理，goBranch() 处理 Tab 切换
- 与 Riverpod 的解耦模式：GoRouter 定义为 `Provider<GoRouter>`，通过 `RouterRefreshNotifier(ChangeNotifier)` 桥接

**Alternatives considered**:
- 手动 IndexedStack + 条件渲染（内存浪费、状态丢失 → 拒绝）
- Navigator 2.0 手动路由（已过时 → 拒绝）

**Source**: CodeWithAndrea + DEV Community 2026 tutorials

---

## R3: Riverpod + GoRouter 集成模式

**Decision**: `ref.read` in redirect + `refreshListenable` bridge

**Rationale**:
- GoRouter 的 `redirect` 回调中必须使用 `ref.read`（不能用 `ref.watch`），否则导致不可控重建将用户踢出
- `RouterRefreshNotifier extends ChangeNotifier` 作为桥接层，将 Riverpod 的 `ref.listen` 转换为 GoRouter 可识别的 `ChangeNotifier`
- GoRouter 放在 `Provider<GoRouter>` 中使 redirect 能访问 `ref`

**Implementation pattern**:
```dart
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    refreshListenable: RouterRefreshNotifier(ref, authProvider),
    redirect: (context, state) {
      final auth = ref.read(authProvider); // ✅ ref.read, not ref.watch
      // ...
    },
    routes: [...],
  );
});
```

**Source**: "Building a Bulletproof Auth System with Flutter, Riverpod, GoRouter" (Apr 2026)

---

## R4: 项目架构选择

**Decision**: Feature-First + Clean Architecture (Presentation/Domain/Data 三层)

**Rationale**:
- Feature-First：每个 Tab 模块（todo/copilot/bookkeeping/notes）自包含，可独立开发/删除
- Domain 层纯 Dart（无 Flutter 依赖），定义 Repository 接口和 Entity
- Data 层实现 Repository，注入 Drift 数据库操作
- Presentation 层 Provider 调用 Domain Repository，UI Widget 消费 Provider
- Phase 2 仅 2 个核心模块，跳过 UseCase 层避免过度工程化

**Source**: Flutter community consensus 2026 + ssoad/flutter_riverpod_clean_architecture

---

## R5: 中文自然语言解析策略

**Decision**: 轻量级正则 + 关键词匹配（不引入 NLP 库）

**Rationale**:
- 现有低保真原型 (`prototypes/todo-app.html` lines 569-599) 已包含完整的 `parseTodoText()` JS 实现，可直接移植到 Dart
- 覆盖所有 spec 要求的分类（4 种类型、5 种时间表达）
- 无需引入 ML/NLP 依赖（避免增加包体积和初始化延迟）

**Pattern inventory** (from reference implementation):

| 功能 | 模式 |
|------|------|
| 日期解析 | 明天/后天/下周/周X → DateTime math |
| 时间解析 | `\d{1,2}[点:：]\d{0,2}` 显式 + 早上/上午/中午/下午/晚上 隐式 |
| 类型分类 | 工作(会议/汇报/周报), 账单(缴费/付款/报销), 健康(健身/跑步/体检), 个人(购物/聚会/电影) |
| 标题清洗 | 去除日期词、时间词、显式时间数字、祈使词(去/要/记得/帮我) |

**Dart improvements over JS reference**:
- 下午小时偏移修正（3点+下午 → 15:00）
- 中午不覆盖显式时间
- 支持 下周一/下周二 等具体下周工作日

**Source**: prototypes/todo-app.html reference implementation

---

## R6: 数据持久化方案

**Decision**: Drift ORM + freezed 数据模型 + Riverpod Provider 注入

**Rationale**:
- Drift 提供编译时类型安全的 SQL 操作，代码生成减少样板
- freezed 生成不可变数据类，copyWith 方法天然适配状态管理
- 通过 `Provider<AppDatabase>` 惰性初始化，各 Repository 通过 Provider 注入

**Database init pattern**:
```dart
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

@DriftDatabase(tables: [Todos, Routines])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  @override int get schemaVersion => 1;
}
```

**Source**: drift.simonbinder.eu official docs

---

## R7: macOS 开发环境要求

**Decision**: macOS Ventura 13+, Xcode 16.0+, JDK 17, Android Studio latest

**Rationale**:
- macOS 是唯一能同时编译 Android + macOS 三端的开发环境（参考架构方案）
- Xcode 16.0+ 是 Flutter 3.41 编译 macOS 桌面的最低要求
- JDK 17 是 Android Gradle 9.x + Kotlin 2.1+ 的要求

**Source**: docs/design/Flutter从零开始技术指导方案.md + Flutter 官方文档
