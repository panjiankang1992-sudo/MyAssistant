# AI 个人助手 APP —— 跨平台实现方案

> 目标平台：**Android + 鸿蒙 (HarmonyOS Next) + macOS**
> 核心能力：通知读取 → AI 分析 → 自动生成待办/账单 | Agent 自主执行 | 跨设备数据同步

---

## 一、总体架构概览

```
┌──────────────────────────────────────────────────────────┐
│                      客户端层 (三端)                       │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Android  │  │  HarmonyOS   │  │      macOS        │   │
│  │ Flutter  │  │   Flutter    │  │     Flutter       │   │
│  │ + 原生插件│  │  + 原生插件   │  │   + 原生插件      │   │
│  └────┬─────┘  └──────┬───────┘  └────────┬─────────┘   │
│       │               │                   │              │
│  ┌────┴───────────────┴───────────────────┴──────────┐   │
│  │           平台桥接层 (Platform Channel)             │   │
│  │  • 通知监听  • 后台服务  • 本地存储  • 系统集成    │   │
│  └──────────────────────┬────────────────────────────┘   │
├──────────────────────────┼──────────────────────────────┤
│                      通信层                               │
│  ┌──────────────────────┴────────────────────────────┐   │
│  │     腾讯云 IM SDK（三端原生支持，含鸿蒙NEXT）        │   │
│  │     • 实时消息推送  • 设备在线状态  • 自定义消息    │   │
│  └──────────────────────┬────────────────────────────┘   │
├──────────────────────────┼──────────────────────────────┤
│                      服务端                               │
│  ┌───────────────────────────────────────────────────┐   │
│  │               API Gateway (Go/Kong)                 │   │
│  ├──────────┬──────────┬──────────┬──────────────────┤   │
│  │ 账号服务  │ 数据同步  │ Agent引擎 │  通知分析引擎    │   │
│  │ JWT Auth │ REST API │ LangGraph │  LLM分类+提取   │   │
│  ├──────────┴──────────┴──────────┴──────────────────┤   │
│  │         PostgreSQL  │  Redis  │  COS 对象存储      │   │
│  └───────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

---

## 二、跨平台框架选型

### 2.1 推荐方案：Flutter

| 维度 | Android | HarmonyOS Next | macOS |
|------|---------|---------------|-------|
| 官方支持 | ✅ Stable（一级平台） | ⚠️ 社区适配（SIG） | ✅ Stable |
| 稳定版本 | Flutter 3.32+ | 3.27.4-ohos 1.0.1（生产级） | Flutter 3.x |
| 原生API交互 | Platform Channel | Platform Channel + 鸿蒙插件 | Platform Channel |
| UI一致性 | Material 3 | Material 3 | Cupertino / Material 3 |

**选择理由：**
- **唯一三平台覆盖最完整的框架**：Android 和 macOS 均为 Google 官方 Stable，鸿蒙通过 OpenHarmony-SIG 社区适配已到生产可用状态
- 2025年9月「开源鸿蒙跨平台框架 PMC」正式启动（华为+腾讯+京东+美团等25家），Flutter 被列为核心框架之一，2026年路线图目标版本同步压缩至4个月
- 原生能力通过 Platform Channel 完整调用（通知监听、后台服务等关键能力）

### 2.2 备选方案

| 框架 | 推荐场景 |
|------|---------|
| **Kuikly（腾讯开源）** | 团队已有 KMP 储备，一码五端（Android/iOS/鸿蒙/Web/小程序），macOS Render 模块可用 |
| **React Native (RNOH)** | 已有 RN 代码存量，但 macOS 和鸿蒙版本滞后需注意 |
| **Taro** | Android + 鸿蒙为主，但无 macOS 桌面支持 |

### 2.3 关键结论

> **选 Flutter**。如果团队有 Kotlin 背景也可考虑 Kuikly。核心原则：不选不支持 macOS 的框架（Taro/uni-app），鸿蒙适配关注 Flutter-OH SIG 的季度交付节奏。

---

## 三、通知读取方案（核心难点）

### 3.1 三平台可行性总览

| 平台 | 技术可行性 | 方案 | 分发风险 |
|------|-----------|------|---------|
| **Android** | ✅ 可行 | NotificationListenerService | Google Play 需权限声明 |
| **鸿蒙 NEXT** | ⚠️ 严重受限 | 仅穿戴伴侣应用可用 | 普通应用基本无法通过审核 |
| **macOS** | ❌ 不可行 | 无公开API | Mac App Store 完全不可行 |

### 3.2 Android 方案（主力平台）

**NotificationListenerService**（官方标准API，自 API 18 起）：

```kotlin
class AssistantNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification, rankingMap: RankingMap) {
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val packageName = sbn.packageName
        
        // 发送到本地分析引擎 → 调用服务端Agent
        NotificationAnalyzer.analyze(title, text, packageName, sbn.postTime)
    }
}
```

**关键限制与对策：**

| 限制 | 对策 |
|------|------|
| Android 15 敏感通知过滤（OTP等被标记） | 在 Manifest 声明 `RECEIVE_SENSITIVE_NOTIFICATIONS` 权限 |
| Google Play 权限声明 | 如实填写 Data Safety Form，在隐私政策中清晰披露 |
| 后台保活 | Foreground Service + 持久通知，合理使用 |
| 用户授权引导 | 跳转 `Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS` |

### 3.3 鸿蒙方案 —— 深度调研结论

#### 3.3.1 路线A：截图方案 ❌ 不可行

用户提出通过"截图 → OCR → AI 分析"绕过通知读取限制。经深入调研，此路线在技术上有**四层障碍**：

| 障碍层 | 具体问题 |
|--------|---------|
| ① 手机端无全屏截图公开 API | `screenshot.capture()` 仅支持 2in1/平板设备，手机调用直接返回**错误码 801** |
| ② 窗口截图无法截取系统 UI | `window.snapshot()` 只能截当前应用窗口，通知栏/锁屏属于独立的系统窗口层级 |
| ③ 通知栏是受保护的系统覆盖层 | 官方文档明确："通知栏、状态栏等系统级覆盖层不受窗口截图影响"，第三方应用无法通过任何窗口 API 捕获 |
| ④ CAPTURE_SCREEN 权限为 system_core 级 | 最高限制级权限，普通应用即使通过 ACL 申请也极难获批，且不能用于上架发布 |

**即使手动截图也不行**：用户在通知中心或锁屏界面手动按键截屏，通知内容同样无法被截取（系统覆盖层保护）。

#### 3.3.2 路线B：无障碍服务 ❌ 不可行

鸿蒙的 `AccessibilityExtensionAbility` 曾是第三方的入口，但**自 API 12 起，所有核心回调方法已系统性废弃**：

| API 方法 | 用途 | 状态 |
|---------|------|------|
| `onAccessibilityEvent(event)` | 监听无障碍事件 | API 12 废弃，系统不再开放 |
| `onConnect()` / `onDisconnect()` | 服务连接/断开回调 | API 12 废弃 |
| `onKeyEvent(keyEvent)` | 物理按键事件 | API 12 废弃 |

官方文档明确声明：**"从 API version 12 开始废弃，系统不再开放相关能力，无替代 API"。** 这是华为主动为之的安全决策——防止 Android 上无障碍服务被恶意利用的问题在鸿蒙上重演。

当前仅存的 `Accessibility Kit` 定位完全不同：它只让开发者**让自己的应用更适配无障碍**（如设置朗读文本），**无法读取其他应用的内容**。

#### 3.3.3 唯一官方路径：NotificationSubscriberExtensionAbility ⚠️ 极度受限

这是鸿蒙唯一可获取通知的官方 API，但有三重严格限制：

| 限制 | 说明 |
|------|------|
| 权限级别 | `system_basic`（受限开放权限），需要 ACL 跨级申请 |
| 场景限制 | **仅限穿戴设备伴侣应用**（智能手表同步手机通知） |
| 审核门槛 | 审核预计 3 个工作日，非穿戴场景的应用基本被拒 |

#### 3.3.4 鸿蒙通知获取——诚实结论

```
❌ 截图方案       → 技术路径堵死（手机无全屏截图API + 通知栏为系统覆盖层）
❌ 无障碍服务     → API 12 起系统性废弃，无替代 API  
⚠️ 通知订阅API    → 仅穿戴伴侣应用可用，普通助手 App 无法通过审核
```

**当前唯一现实可行的鸿蒙端策略：接受约束，不做系统级通知监听。** 降级为以下替代方案：

| 替代方案 | 可行性 | 说明 |
|---------|--------|------|
| 鸿蒙意图框架（Share/Intent） | ✅ | 用户在任意 App 内「分享」到助手，由助手分析处理 |
| 剪贴板监听 | ⚠️ | 用户手动复制通知文本 → 助手读取剪贴板；但鸿蒙对剪贴板后台读取也有限制 |
| 短信解析 | ❌ | 鸿蒙 NEXT 不提供短信读取 API 给第三方应用 |
| Push Kit 直推 | ✅ | 自有服务端通过华为 Push Kit 推送结构化通知数据 |
| 等待生态开放 | ⏳ | 密切关注 HarmonyOS API 版本更新，华为可能在未来开放等效于 Android NotificationListenerService 的 API |

**鸿蒙意图分享方案——推荐实现路径：**

这是当前鸿蒙端最务实的"通知获取"替代方案。核心流程：

```
用户在任意App收到通知
       │
       ▼
  用户点击「分享」
       │
       ▼
  系统分享面板 → 选择「AI助手」
       │
       ▼
  AI助手接收文本
       │
       ▼
  服务端 LLM 分析 → 分类 + 结构化提取
       │
       ▼
  生成待办/账单 → 三端同步
```

鸿蒙实现（`module.json5` 中注册）：

```json5
// 注册分享接收能力
{
  "name": "ShareEntryAbility",
  "skills": [
    {
      "actions": ["ohos.want.action.sendData"],
      "uris": [
        {"scheme": "text", "type": "text/plain"}
      ]
    }
  ]
}
```

```typescript
// ShareEntryAbility 接收分享内容
export default class ShareEntryAbility extends UIAbility {
  onNewWant(want: Want): void {
    // 读取分享的文本内容
    const sharedText = want.parameters?.['harmony.share.text'] as string
    
    if (sharedText) {
      // 调用服务端 Agent 分析
      this.analyzeSharedContent(sharedText)
    }
  }
}
```

**方案优势**：
- 无需特殊权限，合规性最好
- 用户主动触发，无隐私争议
- 可覆盖大部分通知场景（银行消费通知、快递消息、日程提醒等）
- 任何支持系统分享的 App 都能用

**方案劣势**：
- 需要用户手动操作（相比 Android 自动监听，多了一步）
- 依赖用户在收到通知时有意识地去分享
- 通知原文较长的场景体验稍差

### 3.4 macOS 方案 —— 仅数据展示

macOS **没有任何公开API** 可读取系统通知。读取 `usernoted` 数据库的方案在 macOS Sequoia 后受 TCC 保护且 Mac App Store 沙盒应用完全无法访问。

**macOS 端定位：纯数据查看 + 管理端**——查看手机端采集的数据、管理待办/账单、与 Agent 交互。

### 3.5 通知读取策略总结（更新）

```
Android（主力采集）         鸿蒙（降级：分享/意图）       macOS（纯展示端）
    │                           │                          │
    │ NotificationListener      │ 用户主动分享              │ 查看待办/账单
    │ Service                   │ 意图框架                  │ 管理数据
    │                           │ 剪贴板辅助                │ Agent 交互
    │                           │                          │
    └───────────┬───────────────┴──────────────┬───────────┘
                │                              │
                ▼                              ▼
          ┌──────────────────────────────────────┐
          │           服务端 AI 分析              │
          │   通知分类 → 结构化提取 → Agent 执行  │
          └──────────────────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
       Android        HarmonyOS       macOS
      (全功能)       (查看+分享)     (纯查看)
```

**核心思路**：Android 是唯一可做自动通知采集的平台，鸿蒙端通过「分享意图」实现手动触发，macOS 定位为纯管理端。三端数据通过腾讯云 IM 实时同步，体验上保持一致。

---

## 四、数据同步与账号体系

### 4.1 账号体系

**推荐方案：自建 JWT 认证 + 微信/QQ 三方登录**

| 登录方式 | Android | 鸿蒙 NEXT | macOS |
|---------|---------|----------|-------|
| 微信登录 | ✅ | ✅（Open SDK v1.0.14 已发布） | ✅ |
| QQ 登录 | ✅ | ✅（SDK 已发布） | ⚠️（Web OAuth） |
| 手机号/邮箱 | ✅ | ✅ | ✅ |
| Apple ID | ❌ | ❌ | ✅ |

**关键发现：微信和QQ的鸿蒙NEXT SDK均已发布**，这是三端统一账号体验的基础。

```go
// 服务端 JWT 签发
type AuthService struct {
    jwtSecret    []byte
    accessTTL    time.Duration // 2h
    refreshTTL   time.Duration // 30d
}

func (s *AuthService) Login(ctx context.Context, req LoginRequest) (*TokenPair, error) {
    // 微信/QQ/手机号 → 统一 UID
    user := s.resolveUser(ctx, req)
    
    accessToken := jwt.NewWithClaims(...)
    refreshToken := s.generateRefreshToken(user.UID)
    
    return &TokenPair{AccessToken: accessToken, RefreshToken: refreshToken}, nil
}
```

### 4.2 数据同步架构

**推荐方案：REST API 增量拉取 + 腾讯云 IM 实时触发**

```
┌─────────────────────────────────────────────────────┐
│                   服务端                             │
│  ┌──────────┐   ┌──────────┐   ┌────────────────┐  │
│  │ REST API │   │ 数据服务  │   │ 腾讯云 IM 服务  │  │
│  │ (CRUD)   │   │PostgreSQL│   │ (消息通道)     │  │
│  └────┬─────┘   └────┬─────┘   └───────┬────────┘  │
│       │              │                 │            │
│       │     ┌────────▼────────┐        │            │
│       │     │ 变更日志 (CDC)   │────────┘            │
│       │     │ lastModified     │   数据变更→IM通知   │
│       │     └─────────────────┘                     │
└───────┼─────────────────────────────────────────────┘
        │              │                 │
   ┌────▼────┐   ┌─────▼──────┐   ┌─────▼──────┐
   │ Android │   │  HarmonyOS │   │   macOS    │
   │ SQLite  │   │  RDB存储   │   │  SQLite    │
   │ offline │   │  offline   │   │  offline   │
   └─────────┘   └────────────┘   └────────────┘
```

**为什么选腾讯云 IM 作为实时通道？**
- 目前**唯一**官方支持三端原生（含鸿蒙 NEXT）的实时通信 SDK
- 自定义消息类型可承载"数据变更通知"（仅发一个 `{type: "todo_updated", id: "xxx"}`，客户端收到后增量拉取）
- 自带设备在线状态管理

**同步策略：**
| 数据维度 | 同步方式 | 冲突解决 |
|---------|---------|---------|
| 待办/账单 | 变更日志增量同步 | Last-Write-Wins（简单字段）+ 业务合并（列表项） |
| 用户设置 | 全量同步（数据量小） | LWW |
| Agent任务状态 | 服务端权威 | 无冲突 |
| 离线操作 | 本地队列 → 重连批量提交 | 提交时服务端仲裁 |

### 4.3 两套方案对比

| | 方案A：腾讯云生态 | 方案B：开源自建 |
|---|---|---|
| 账号 | CloudBase 认证 | 自建 JWT + 微信/QQ |
| 数据同步 | CloudBase watch() | REST + IM 通知 |
| 实时通信 | 腾讯云 IM | 腾讯云 IM（不变） |
| 后端 | CloudBase 云函数 | Go 自建服务 |
| 成本 | 按量付费 | 服务器固定成本 |
| **推荐** | Flutter 团队快速启动 | 原生开发/自主可控需求 |

> **无论哪种方案，腾讯云 IM 都是实时通知通道的最优解。**

---

## 五、AI Agent 集成方案

### 5.1 整体架构：服务端 Agent + 端侧轻量调用

```
┌─────────────────────────────────────────────────┐
│                   Agent 引擎（服务端）             │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │            Agent 编排器                    │   │
│  │  ┌────┐  ┌─────────┐  ┌──────────────┐   │   │
│  │  │规划│→│工具调用  │→│ 结果评估      │   │   │
│  │  └────┘  └────┬────┘  └──────┬───────┘   │   │
│  │               │              │           │   │
│  │        ┌──────▼──────┐       │           │   │
│  │        │  工具注册中心 │       │           │   │
│  │        │ (MCP协议)    │       │           │   │
│  │        └──────┬──────┘       │           │   │
│  └───────────────┼──────────────┼───────────┘   │
│                  │              │               │
│  ┌───────────────▼──────────────▼───────────┐   │
│  │  工具集                                   │   │
│  │  • create_todo  • record_bill            │   │
│  │  • search_note  • send_reminder          │   │
│  │  • analyze_notification • query_weather  │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐     │
│  │DeepSeek  │  │ GPT-4o   │  │端侧小模型  │     │
│  │ V3.1     │  │ (兜底)   │  │(离线场景)  │     │
│  │ 主力模型  │  │          │  │           │     │
│  └──────────┘  └──────────┘  └───────────┘     │
└─────────────────────────────────────────────────┘
         │                  │
    ┌────▼────┐        ┌────▼────┐
    │  客户端  │        │  客户端  │
    │  SSE/WS │        │  拉取结果 │
    └─────────┘        └─────────┘
```

### 5.2 大模型选型

| 模型 | 角色 | 理由 |
|------|------|------|
| **DeepSeek-V3.1** | 主力模型 | Function Calling 支持 strict 模式、成本仅为 GPT-4o 1/10、中文能力极强 |
| **GPT-4o** | 复杂任务兜底 | Function Calling 最成熟、推理最强 |
| **Qwen3-Max** | 中文场景备选 | 混合思考能力强、中文优化 |
| **llama.cpp / MindSpore Lite** | 端侧离线 | 隐私敏感场景（通知内容不外传）、无网络环境 |

**成本控制关键**：Agent 任务通常需要 8-30 次模型调用/会话。以 DeepSeek-V3.1 为主力可将单次 Agent 交互成本控制在 ¥0.01-0.05。

### 5.3 Agent 框架选型

| 场景 | 推荐方案 |
|------|---------|
| **MVP/快速验证** | 轻量级 ReAct Loop（自建，~200行代码） |
| **复杂多步骤任务** | LangGraph（图结构+状态管理+断点恢复） |
| **鸿蒙生态深度集成** | 鸿蒙智能体框架 HMAF + 小艺开放平台 |

**推荐路径：先轻量 Loop → 再升级 LangGraph**

```python
# 轻量级 Agent Loop（服务端）
class AgentLoop:
    def run(self, user_input: str, tools: list[Tool], max_steps: int = 10):
        messages = [{"role": "user", "content": user_input}]
        
        for step in range(max_steps):
            response = llm.chat(messages, tools=tools)
            
            if response.tool_calls:
                for tc in response.tool_calls:
                    result = self.execute_tool(tc)  # 安全沙箱执行
                    messages.append({"role": "tool", "content": result})
            else:
                return response.content  # Agent 认为任务完成
        
        raise MaxStepsExceeded()
```

### 5.4 工具系统设计（MCP 协议）

采用 **Model Context Protocol (MCP)** 标准化工具定义：

```json
{
  "name": "create_todo_from_notification",
  "description": "从通知内容创建待办事项",
  "parameters": {
    "type": "object",
    "properties": {
      "title": {"type": "string", "description": "待办标题"},
      "due_date": {"type": "string", "description": "截止日期 ISO8601"},
      "priority": {"type": "string", "enum": ["high", "medium", "low"]},
      "source_notification_id": {"type": "string"}
    },
    "required": ["title"]
  }
}
```

**核心工具集：**
| 工具 | 功能 | 安全等级 |
|------|------|---------|
| `create_todo` / `update_todo` | 待办 CRUD | 低（仅写数据库） |
| `record_bill` | 记录账单（金额、分类、来源） | 中（涉及金额） |
| `search_knowledge` | 搜索用户知识库 | 低（只读） |
| `send_reminder` | 创建提醒 | 中（涉及通知发送） |
| `query_calendar` | 查询日历 | 低（只读） |
| `analyze_notification` | 分析通知（分类+提取） | 低（只读） |

### 5.5 安全沙箱

- **端侧**：依赖各平台原生沙箱（Android Sandbox、鸿蒙 App Sandbox、macOS Sandbox）
- **云侧工具执行**：Docker 容器隔离 + 权限白名单
- Agent **不能**：删除数据、发送消息给他人、访问未授权的 API

### 5.6 后台任务执行

核心策略：**服务端异步执行 + 端侧状态展示**

```
用户发起Agent任务
     │
     ▼
服务端接收 → 加入任务队列
     │
     ├─ 短任务(<30s)：同步等待，直接返回
     │
     └─ 长任务：异步执行
          │
          ├─ 进度通过 IM 推送 → 客户端展示进度条
          │
          └─ 完成 → IM 推送通知 → 客户端拉取结果
```

| 平台 | 后台保活方案 |
|------|-------------|
| Android | WorkManager + Foreground Service |
| 鸿蒙 | ContinuousTask (TASK_KEEPING) 或 Push 唤醒 |
| macOS | XPC Service 或 Push 唤醒 |

---

## 六、通知 → AI 分析 Pipeline

这是产品的核心链路：

```
┌─────────────────────────────────────────────────────────┐
│  Android 手机                                              │
│  ┌──────────────────────────────────────────┐            │
│  │ NotificationListenerService              │            │
│  │  ↓ 新通知到达                             │            │
│  │  ├─ 提取：title, text, packageName, time  │            │
│  │  ├─ 本地预过滤（白名单/黑名单）             │            │
│  │  └─ 发送到服务端                           │            │
│  └──────────────────────────────────────────┘            │
└────────────────────┬────────────────────────────────────┘
                     │ HTTPS
                     ▼
┌─────────────────────────────────────────────────────────┐
│  服务端 - 通知分析 Pipeline                                │
│                                                          │
│  ① 意图分类 (LLM轻量调用，DeepSeek单次)                    │
│     ├─ "您的快递已签收" → type: delivery                  │
│     ├─ "您尾号8888的信用卡消费￥128.00" → type: bill      │
│     ├─ "明天下午3点会议" → type: calendar                 │
│     └─ "验证码：123456" → type: otp (标记敏感，不存储)     │
│                                                          │
│  ② 结构化提取 (同次LLM调用输出JSON)                        │
│     bill: {amount, merchant, card_last4, time}           │
│     calendar: {title, time, location, attendees}         │
│     todo: {title, deadline, priority}                    │
│                                                          │
│  ③ 触发 Agent 建议                                        │
│     → 确认是 bill → Agent: "检测到一笔消费，要记录吗？"     │
│     → 用户确认 → 写入数据库 → IM通知所有设备               │
└─────────────────────────────────────────────────────────┘
```

**设计原则：**
- 通知原文**不上传到服务端可配置**（隐私模式）
- OTP 类通知在客户端直接过滤，不上传
- 白名单机制：用户可选择哪些 App 的通知被监听

---

## 七、推荐实施路线图

### Phase 1：MVP（2-3个月）

| 任务 | 内容 |
|------|------|
| 跨平台框架搭建 | Flutter 项目初始化，三端跑通 |
| Android 通知监听 | NotificationListenerService + 本地预过滤 |
| 服务端通知分析 | DeepSeek 单次分类+提取 API |
| 基础数据模型 | 待办/账单的 CRUD + PostgreSQL |
| 账号体系 | 自建 JWT + 微信登录 |
| 数据同步 | REST API + IM 通知通道 |

**交付物**：Android 端可读取通知并生成待办/账单，三端可查看。

### Phase 2：Agent 深度集成（2-3个月）

| 任务 | 内容 |
|------|------|
| Agent 引擎 | 轻量 ReAct Loop → LangGraph |
| 工具系统 | MCP 协议，5-8 个核心工具 |
| 后台任务 | 服务端异步 Agent 执行 + 进度推送 |
| 端侧模型 | llama.cpp 集成（隐私场景离线处理） |
| 鸿蒙适配 | 鸿蒙端 Flutter 编译 + 平台插件 |

**交付物**：Agent 可自主执行任务（如"帮我把今天的消费都记上"）。

### Phase 3：体验打磨 + 鸿蒙深度适配（2-3个月）

| 任务 | 内容 |
|------|------|
| 鸿蒙意图分享 | 实现「分享到助手」意图，用户在任意 App 内分享内容给助手分析 |
| 鸿蒙剪贴板辅助 | 用户复制通知文本后，助手读取剪贴板并分析（需注意鸿蒙后台读取限制） |
| macOS 桌面体验 | 菜单栏常驻、快捷键、原生通知 |
| 多设备协同 | 设备间状态实时同步 |
| 性能优化 | 启动速度、内存占用、电量优化 |
| 上架准备 | Google Play / 华为应用市场 / Mac App Store |
| 鸿蒙生态跟进 | 持续关注 HarmonyOS API 更新，若华为开放通知监听 API 则第一时间适配 |

---

## 八、关键风险与应对

| 风险 | 等级 | 详细说明 | 应对 |
|------|------|---------|------|
| **鸿蒙截图方案不可行** | 🔴 已确认 | 手机端无全屏截图API（仅平板可用）+ 通知栏为受保护系统覆盖层 + CAPTURE_SCREEN 为 system_core 权限 | 放弃截图路线，改用意图分享框架 |
| **鸿蒙无障碍服务不可用** | 🔴 已确认 | AccessibilityExtensionAbility 自 API 12 起核心方法全部废弃，系统不再开放 | 放弃无障碍路线 |
| **鸿蒙通知订阅仅限穿戴** | 🔴 高 | NotificationSubscriberExtensionAbility 定位穿戴伴侣，普通App无法通过审核 | 意图分享 + 剪贴板辅助；静待华为开放 API |
| **Google Play 审核拒绝** | 🟡 中 | 通知监听权限需如实声明用途 | 填写 Data Safety Form，准备详细隐私政策 |
| **Flutter 鸿蒙适配滞后** | 🟡 中 | 目前滞后约7个月 | 关注 Flutter-OH SIG 季度交付，必要时 Fork 自维护 |
| **LLM 成本失控** | 🟡 中 | Agent 任务需多次模型调用 | DeepSeek 主力（成本低），设置每日上限，缓存分类结果 |
| **通知隐私合规** | 🟡 中 | 读取通知涉及用户隐私 | 隐私模式可配置、OTP 本地过滤、不上传原文、数据最小化 |
| **macOS 无通知读取** | 🟢 低 | 无公开 API | 接受约束，macOS 定位为"查看+管理端" |

---

## 九、技术栈最终推荐

| 层 | 选型 |
|----|------|
| **跨平台框架** | Flutter 3.32+（鸿蒙用社区适配版 3.27.4-ohos） |
| **账号认证** | 自建 JWT + 微信 Open SDK（三端）+ QQ SDK |
| **实时通信** | 腾讯云 IM SDK（唯一三端原生支持含鸿蒙） |
| **数据库** | 服务端 PostgreSQL | 客户端 SQLite |
| **后端语言** | Go (Gin) 或 Node.js (Fastify) |
| **主力 LLM** | DeepSeek-V3.1（Function Calling + strict 模式） |
| **兜底 LLM** | GPT-4o（高难度推理）+ Qwen3-Max（中文优化） |
| **端侧 LLM** | llama.cpp (Android/macOS) + MindSpore Lite (鸿蒙) |
| **Agent 框架** | 轻量 ReAct Loop → LangGraph（演进路径） |
| **工具协议** | MCP（兼容 OpenAI Function Calling） |
| **文件存储** | 腾讯云 COS |
| **后台任务** | 服务端队列 + IM Push 通知 |

---

## 十、结论

这个项目在技术上是**完全可行的**，但需要接受以下核心约束：

1. **Android 是唯一可做自动通知采集的平台**——NotificationListenerService 成熟可靠，Google Play 审核有明确路径（权限声明 + 隐私政策）。

2. **鸿蒙端做了截图和无障碍服务两条路线的深度调研，结论都是不可行**：
   - 截图：手机无全屏截图 API（仅平板可用），通知栏是受保护的系统覆盖层，CAPTURE_SCREEN 为 system_core 权限
   - 无障碍：AccessibilityExtensionAbility 自 API 12 起核心方法全部废弃，系统不再开放
   - 唯一官方路径 NotificationSubscriberExtensionAbility 仅限穿戴伴侣应用
   - **务实方案**：鸿蒙端通过「意图分享框架」让用户主动分享内容给助手分析，不追求自动监听

3. **macOS 合理定位为纯展示+管理端**，不做通知采集。

4. **Flutter 是当前三平台覆盖最均衡的框架**，鸿蒙适配虽有滞后但在快速追赶（开源鸿蒙 PMC 已成立）。

5. **腾讯云 IM 是实时同步的关键基础设施**——目前唯一官方支持 Android/鸿蒙/macOS 三端的实时通信 SDK。

6. **DeepSeek-V3.1 是目前性价比最高的 Agent 主力模型**，中文能力强、Function Calling 可靠、成本约为 GPT-4o 的 1/10。

7. **Agent 应放在服务端**，移动端作为轻量调用层。工具系统用 MCP 协议标准化，为未来扩展留空间。
