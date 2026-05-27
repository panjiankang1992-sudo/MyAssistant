# Research: 数据存储与同步机制

**Feature**: 003-data-storage-sync
**Date**: 2026-05-20

---

## R1: WebDAV 客户端库选择

**Decision**: `webdav_plus` ^1.2.2

**Rationale**:
- 原生支持 PROPFIND/PROPPATCH，自动解析 multistatus XML 为 `DavResource` 对象
- 内置 Basic Auth 支持（`isPreemptive: true` 减少往返）
- 流式上传/下载接口（`putFileStream`/`downloadToFile`）
- WebDAV 特定异常类型（`WebDAVAuthenticationException`, `WebDAVNetworkException`）
- v1.2.2 发布于 2026 年 1 月，维护活跃

**Alternatives considered**:
- 原始 `http` 包（需手动构建 XML、解析 PROPFIND → 工作量太大）
- `simple_webdav_client`（API 不如 webdav_plus 丰富，流式支持有限）

**Source**: pub.dev

---

## R2: macOS Keychain 凭据存储

**Decision**: `flutter_secure_storage` ^10.2.0 with macOS Keychain

**Rationale**:
- macOS 上原生使用 Keychain Services API
- 需在 `macos/Runner/*.entitlements` 中添加 `keychain-access-groups`
- 配置: `accessibility: unlocked`, `synchronizable: false`（不同步 iCloud）

**Keychain configuration**:
```xml
<key>keychain-access-groups</key>
<array/>
```

**Source**: pub.dev + flutter_secure_storage README

---

## R3: 网络连通性检测

**Decision**: `connectivity_plus` ^7.1.1

**Rationale**:
- Flutter Favorite 包，维护活跃
- macOS 使用 `NWPathMonitor` API
- 同步前检查（`checkConnectivity()`）比流式监听更可靠
- VPN 在 macOS 上返回 `ConnectivityResult.other`

**Source**: pub.dev

---

## R4: 后台同步策略

**Decision**: 应用内 `Timer.periodic` + 启动时立即同步

**Rationale**:
- macOS 无真正的后台任务执行能力（app 关闭后 Timer 停止）
- `workmanager` 包在 macOS 上不可靠
- 组合策略：每次启动立即同步 + 运行时每 10 分钟定时同步
- 网络变化时额外触发一次同步

**Alternatives considered**:
- `workmanager`（Android 专用，macOS 不支持）
- `background_fetch`（iOS/Android，macOS 不支持）

**Source**: Flutter 官方文档 + StackOverflow

---

## R5: XML 解析（PROPFIND 响应）

**Decision**: 依赖 `webdav_plus` 内置解析，不引入额外 XML 库

**Rationale**:
- `webdav_plus` 内部使用 `package:xml` 解析 multistatus
- 开发者无需手动处理 XML
- 若需自定义解析，可添加 `xml: ^6.6.1` 依赖

**Source**: webdav_plus 源码

---

## R6: 变更追踪集成模式

**Decision**: Repository 层拦截器模式

**Rationale**:
- 所有数据操作经过 Repository（`TodoRepository.addTodo` 等）
- 在 Repository 方法中注入 `ChangeTracker.recordChange()` 调用
- 不修改 Provider/Widget 层，单点注入，减少遗漏

**Source**: 现有项目架构 (002-env-todo-copilot)

---

## R7: 完整依赖列表

```yaml
dependencies:
  webdav_plus: ^1.2.2
  flutter_secure_storage: ^10.2.0
  connectivity_plus: ^7.1.1
  xml: ^6.6.1        # webdav_plus 已包含，自定义解析时使用
```
