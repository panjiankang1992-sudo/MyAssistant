# AGENTS.md — AI 个人助手项目

> **交互语言：中文（zh-CN）**

## 项目性质

这是一个**设计与规划阶段**的项目，尚未进入代码实现。仓库内无 `package.json`、构建系统或可运行代码。

**最终目标**：Flutter 跨平台 AI 个人助手（Android + 鸿蒙 NEXT + macOS），核心能力为通知读取 → AI 分析 → 自动生成待办/账单。

## 文件结构

| 文件/目录 | 用途 |
|-----------|------|
| `docs/design/AI助手跨平台实现方案.md` | 架构总方案（跨平台选型、通知读取策略、数据同步、Agent 设计） |
| `docs/design/Flutter从零开始技术指导方案.md` | 从零搭建的完整技术指导（环境、项目结构、平台原生集成代码示例） |
| `docs/design/design_refresh*.md` | 视觉设计迭代记录 |
| `docs/screenshots/` | 设计和验证截图 |
| `prototypes/todo-app.html` | UI 原型——待办/记账/随手记/Copilot 四个 Tab 的 Apple 风格 Demo |
| `prototypes/test-preview.html` | 无关紧要的测试页面 |
| `scripts/setup_flutter.sh` | Flutter 环境初始化脚本 |
| `.opencode/` | OpenCode 配置 + SpecKit 工作流命令 |
| `.specify/` | SpecKit 工作流配置（spec → plan → tasks → implement） |

## 技术栈（设计阶段已确定）

- **跨平台框架**：Flutter 3.41.7（标准）+ Flutter-OH 3.27.4-ohos（鸿蒙，独立 SDK 目录）
- **状态管理**：Riverpod 3.x + go_router
- **本地数据库**：Drift (SQLite ORM) + build_runner 代码生成
- **实时通信**：腾讯云 IM SDK（唯一三端原生支持含鸿蒙 NEXT）
- **后端**：Go (Gin) 或 Node.js (Fastify) + PostgreSQL + Redis
- **主力 LLM**：DeepSeek-V3.1（Function Calling strict 模式）
- **Agent 协议**：MCP（Model Context Protocol）
- **鸿蒙端**：不出 `ohos/` 原生代码由 DevEco Studio 管理

## 关键约束（从方案文档中提取）

- **Android**：唯一可做自动通知监听的平台（NotificationListenerService）
- **鸿蒙 NEXT**：无法自动监听通知。截图方案、无障碍服务均已确认不可行。降级为「意图分享框架」+ 剪贴板辅助
- **macOS**：无法读取系统通知。定位为纯数据查看 + 管理端
- **双版本 Flutter**：标准 Flutter 和 Flutter-OH 存放在不同目录，不可混用 PATH。用 FVM 管理或分终端窗口切换

## SpecKit 工作流

项目已集成 [SpecKit](https://github.com/your-org/speckit)，配置见 `.specify/`：

| 命令 | 作用 |
|------|------|
| `/speckit.specify` | 从自然语言描述创建/更新功能规格 |
| `/speckit.plan` | 生成实现计划和设计产物 |
| `/speckit.tasks` | 生成依赖排序的任务列表 |
| `/speckit.implement` | 按 tasks.md 执行实现 |
| `/speckit.analyze` | 跨产物一致性分析 |

工作流：`specify → clarify → plan → tasks → implement`

## 无需执行的操作

- 本项目**无构建命令、无测试命令、无 lint 命令**
- 不要尝试 `npm install`、`flutter pub get` 或任何包管理器
- HTML 文件是静态原型，直接在浏览器打开即可预览
- 修改方案文档时，注意两篇文档间的一致性（`docs/design/AI助手跨平台实现方案.md` 是高层设计，`docs/design/Flutter从零开始技术指导方案.md` 是实现指导）

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan at
`specs/004-webdav-sync-revamp/plan.md`.
<!-- SPECKIT END -->
