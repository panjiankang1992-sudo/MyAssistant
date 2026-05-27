# 手机端 AI Agent 智能助手 — 完整技术方案

> 目标：构建一个手机应用端智能助手 Agent，对接大模型 API，能读取本应用数据，能联网搜索，支持 Skill / MCP 可配置能力。

---

## 一、总体架构：端云协同 Hybrid 模式（推荐）

```
┌─────────────────────────────────────────────────────────────────┐
│                        移动端 App                                │
│                                                                  │
│  ┌──────────────┐   ┌──────────────────┐   ┌─────────────────┐ │
│  │  UI 层        │   │  Agent 编排层     │   │  安全层          │ │
│  │ Compose/      │◄─►│ · ReAct Loop     │   │  · 操作分级门控  │ │
│  │ SwiftUI       │   │ · Intent Router  │   │  · 沙箱隔离      │ │
│  │ 流式渲染+     │   │ · LLM Adapter    │   │  · 权限 ACL      │ │
│  │ 打字机效果    │   │ · Tool Registry  │   │  · 审计日志      │ │
│  └──────────────┘   └───────┬──────────┘   └─────────────────┘ │
│                              │                                    │
│  ┌───────────────────────────┼───────────────────────────────┐  │
│  │                    数据与服务层                             │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐ │  │
│  │  │本地数据源 │ │Skill系统 │ │ MCP客户端 │ │ RAG 检索引擎  │ │  │
│  │  │笔记/文件  │ │SKILL.md  │ │Kotlin SDK │ │向量DB+重排序 │ │  │
│  │  │知识库/DB  │ │动态加载  │ │Stream HTTP│ │本地+云端混合 │ │  │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────────┘ │  │
│  └───────────────────────────┬───────────────────────────────┘  │
│                              │                                    │
│  ┌───────────────────────────┼───────────────────────────────┐  │
│  │                    记忆系统                                 │  │
│  │  Session Memory(短期) + User Profile(中期) + History(长期) │  │
│  │  Room DB / SharedPreferences / Keychain                    │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                              │
                    后端代理 (API Gateway)
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                      ▼
   LLM APIs            Web Search APIs         MCP 远程服务
   OpenAI/DeepSeek/     Tavily/Brave/          Playwright/
   混元/通义千问         Bing/SerpAPI          GitHub/Context7
```

**核心设计原则**：
- **意图分类在端侧**（<50ms），简单任务本地处理，复杂任务上云
- **数据不出设备**：敏感数据本地向量化，仅传 Top-K 片段给云端
- **API Key 绝不落地客户端**：后端代理是唯一安全方案

---

## 二、大模型 API 对接

### 2.1 统一适配层

几乎所有厂商都兼容 OpenAI Chat Completion 格式，只需换 `baseUrl` 和 `apiKey`：

| 厂商 | baseUrl | model |
|------|---------|-------|
| OpenAI | `https://api.openai.com/v1` | `gpt-4o` |
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` |
| 腾讯混元 | `https://api.hunyuan.cloud.tencent.com/v1` | `hunyuan-lite` |
| 通义千问 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-turbo` |

### 2.2 Android 流式调用实现（Kotlin + OkHttp）

```kotlin
// Repository 层 — 流式 SSE
class LlmRepository(
    private val client: OkHttpClient,
    private val baseUrl: String,
    private val apiKey: String
) {
    fun streamChat(messages: List<ChatMessage>): Flow<StreamChunk> = callbackFlow {
        val body = Json.encodeToString(
            ChatRequest(model = "deepseek-chat", messages = messages, stream = true)
        ).toRequestBody("application/json".toMediaType())

        val request = Request.Builder()
            .url("$baseUrl/chat/completions")
            .header("Authorization", "Bearer $apiKey")
            .post(body)
            .build()

        val call = client.newCall(request)
        invokeOnClose { call.cancel() }

        call.enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) { close(e) }
            override fun onResponse(call: Call, resp: Response) {
                resp.body?.source()?.use { source ->
                    while (!source.exhausted()) {
                        val line = source.readUtf8Line() ?: break
                        if (!line.startsWith("data: ")) continue
                        val data = line.removePrefix("data: ")
                        if (data == "[DONE]") {
                            trySend(StreamChunk("", isDone = true)); break
                        }
                        parseChunk(data)?.let { trySend(it) }
                    }
                }
                close()
            }
        })
        awaitClose()
    }
}

// ViewModel — StateFlow 管理状态
class ChatViewModel @Inject constructor(private val repo: LlmRepository) : ViewModel() {
    data class UiState(
        val messages: List<ChatMessage> = emptyList(),
        val streamingText: String = "",
        val isLoading: Boolean = false
    )
    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    fun sendMessage(userInput: String) {
        val sb = StringBuilder()
        viewModelScope.launch {
            repo.streamChat(buildContext(userInput))
                .catch { /* 错误处理 */ }
                .collect { chunk ->
                    if (chunk.isDone) {
                        _uiState.update {
                            it.copy(messages = it.messages + ChatMessage("assistant", sb.toString()),
                                   streamingText = "", isLoading = false)
                        }
                    } else {
                        sb.append(chunk.delta)
                        _uiState.update { it.copy(streamingText = sb.toString()) }
                    }
                }
        }
    }
}
```

### 2.3 API 安全：后端代理模式

```
移动端 App ──device_token──► 自建后端 (Node/Python) ──apiKey──► LLM API
                                  │
                          · 限流/计量/缓存
                          · 内容审核
                          · A/B 测试模型
                          · device_token 短期有效（≤15min）
```

### 2.4 上下文窗口管理

| 策略 | 做法 | 效果 |
|------|------|------|
| **Compaction 压缩** | LLM 提炼旧对话为摘要 | 保留关键信息，上下文降至 10-30% |
| **滑动窗口** | 只保留最近 N 轮 | 实现简单，但丢失早期信息 |
| **语义哈希** | 长上下文语义压缩 | ima 同款技术，保真度高 |

---

## 三、本地数据读取（App 内数据）

### 3.1 数据抽象层架构

```
AI Agent
    │
DataAccessFacade（统一入口）
    ├── NotesRepo      → SQLite/Room
    ├── FilesRepo      → 本地文件系统
    ├── KnowledgeBaseRepo → 向量数据库
    └── UserProfileRepo   → SharedPreferences/Keychain
```

### 3.2 本地 RAG：端侧 Embedding + 云端生成

```
用户提问
    ↓
端侧 ONNX Runtime → Embedding (all-MiniLM-L6-v2, INT8量化, ~23MB)
    ↓
向量搜索 → sqlite-vec (10K chunks, 2-8ms)
    ↓
Top-5 片段 + 问题 → 组装上下文 (~1K tokens)
    ↓
发送云端 LLM → 流式生成答案
```

### 3.3 端侧推理引擎选型

| 引擎 | 平台 | 特点 |
|------|------|------|
| ONNX Runtime Mobile | Android/iOS | INT8 量化，通用性好 |
| llama.cpp | Android/iOS | GGUF 量化，社区最活跃 |
| MediaPipe LLM | Android | Google 官方，Gemma/Phi 支持 |
| Gemini Nano | Android 14+ | 内置，零部署 |
| Apple Foundation | iOS 18+ | 内置，原生 App Intents |

### 3.4 移动端向量数据库

| 方案 | 大小 | 性能 | 推荐度 |
|------|------|------|--------|
| **sqlite-vec** | 零依赖 | 2-8ms (10K) | ★★★★★ |
| ObjectBox Vector | ~2MB | 极快 | ★★★★ |
| LanceDB (嵌入式) | ~5MB | 快 | ★★★ |

---

## 四、联网搜索集成

### 4.1 搜索 API 选型

| API | 免费额度 | 移动端适用性 | 推荐场景 |
|-----|---------|-------------|---------|
| **Tavily** | 1000次/月 | ★★★★★ | Agent 专用，返回已清洗结构化结果 |
| **Brave Search** | 2000次/月 | ★★★★★ | 独立索引，400亿+页面，无 Google 依赖 |
| **SerpAPI** | 付费 | ★★★ | 最完整 Google SERP |
| **Serper.dev** | 有免费层 | ★★★★ | 极快极便宜 |

**推荐策略**：Tavily 主引擎 + Brave 备用 + 本地搜索降级

### 4.2 双引擎搜索 + 融合（ima 同款）

```
用户查询
    ├── 全网搜索 (Tavily API) ──→ 搜索结果 ──┐
    │                                         ├── 去重融合 ──→ Rerank ──→ LLM 生成
    └── 知识库搜索 (本地向量DB) ──→ 私有内容 ──┘
```

### 4.3 去重管线

```
L1: URL 精确匹配
L2: SimHash 局部敏感哈希（汉明距离<3）
L3: Embedding 余弦相似度（阈值 0.95）
→ 去除 30-50% 冗余
```

### 4.4 离线降级策略

```
联网搜索 ✓ → 返回网络结果
    │ 网络不可用
    ▼
本地向量搜索 ✓ → 返回知识库结果
    │ 无匹配
    ▼
倒排索引关键词搜索 → 返回模糊匹配
    │ 无匹配
    ▼
缓存结果（语义缓存 + 时间缓存）
    │ 缓存 miss
    ▼
优雅降级：「网络不可用，请稍后重试」
```

---

## 五、Skill 系统设计

### 5.1 三层能力模型

```
Skill（原子能力）  →  一个独立可执行的能力单元
Plugin（模块级）   →  聚合相关 Skill，含生命周期管理
Agent（系统级）    →  LLM 大脑 + 规划 + 记忆 + 工具调度
```

### 5.2 SKILL.md 标准格式（兼容 Codex/Claude/OpenAI）

```markdown
---
name: web-search
version: 1.0.0
description: Search the internet for real-time information
type: mcp-tool
requires:
  - mcp: tavily-search
  - permission: network
capabilities: [search, fetch, summarize]
timeout_ms: 30000
---

## 任务
根据用户查询搜索互联网，返回结构化结果。

## 流程
1. 接收用户查询
2. 调用 Tavily Search API
3. 提取关键信息
4. 去重排序
5. 返回结构化结果 + 引用来源
```

### 5.3 Skill 注册与动态加载（Android）

```kotlin
// SkillRegistry.kt
class SkillRegistry(private val context: Context) {
    private val registry = ConcurrentHashMap<String, SkillMeta>()
    private val loadedSkills = ConcurrentHashMap<String, ISkill>()

    // 从 assets/skills/ 和 ~/.codex/skills/ 扫描 SKILL.md
    suspend fun discover(): List<SkillMeta> {
        val skills = mutableListOf<SkillMeta>()
        // 内置 skills
        context.assets.list("skills/")?.forEach { dir ->
            parseSkillMd(context.assets.open("skills/$dir/SKILL.md"))?.let {
                registry[it.name] = it
                skills.add(it)
            }
        }
        // 用户安装的 skills
        File(context.filesDir, "skills").listFiles()?.forEach { dir ->
            parseSkillMd(File(dir, "SKILL.md").readText())?.let {
                registry[it.name] = it
                skills.add(it)
            }
        }
        return skills
    }

    // 懒加载：首次使用时才实例化
    suspend fun load(name: String): ISkill {
        loadedSkills[name]?.let { return it }
        val meta = registry[name] ?: throw SkillNotFound(name)
        val skill = when (meta.type) {
            "pure-prompt" -> PromptSkill(meta)
            "scripted"    -> ScriptedSkill(meta, sandbox)
            "mcp-tool"    -> McpToolSkill(meta, mcpClient)
        }
        loadedSkills[name] = skill
        return skill
    }
}
```

### 5.4 渐进式加载（移动端关键优化）

```
启动时：仅加载 Skill 元数据（name + description，~100 tokens/skill）
触发时：加载完整 Skill 指令（完整 SKILL.md body）
执行时：加载 references + scripts（仅当需要时）
```

收益：相比全量注入，上下文节省 85%，准确率提升 30%+

---

## 六、MCP 集成方案

### 6.1 MCP 客户端架构（Android）

```
┌─────────────────────────────────────────┐
│  MCP Client Manager                      │
│  · 连接管理  · 工具发现  · 调用路由       │
├─────────────────────────────────────────┤
│  Transport 层                            │
│  · Streamable HTTP (主要)                │
│  · AIDL/Binder (本地跨App)               │
│  · SSE (兼容旧版)                        │
├─────────────────────────────────────────┤
│  安全层                                  │
│  · Certificate Pinning                   │
│  · 权限分级网关                           │
│  · OAuth PKCE                            │
└─────────────────────────────────────────┘
```

### 6.2 官方 SDK

| 平台 | SDK | 仓库 |
|------|-----|------|
| Android/KMP | kotlin-sdk | `modelcontextprotocol/kotlin-sdk` |
| iOS | swift-sdk | `modelcontextprotocol/swift-sdk` |
| React Native | mcp-sdk-client-ssejs | `mybigday/mcp-sdk-client-ssejs` |
| Flutter | mcp_dart | 配合 Joey MCP Client |

### 6.3 Android 官方 Kotlin SDK 使用

```kotlin
// build.gradle.kts
dependencies {
    implementation("io.modelcontextprotocol:kotlin-sdk:0.16.0")
}

// 连接 Streamable HTTP MCP 服务
import io.modelcontextprotocol.kotlin.sdk.client.Client
import io.modelcontextprotocol.kotlin.sdk.client.StreamableHttpTransport
import io.modelcontextprotocol.kotlin.sdk.Implementation

val transport = StreamableHttpTransport(
    url = "https://my-mcp-server.com/mcp",
    options = TransportOptions(
        headers = mapOf("Authorization" to "Bearer $token")
    )
)

val client = Client(
    clientInfo = Implementation(name = "my-app", version = "1.0.0")
)

client.connect(transport)

// 发现工具
val tools = client.listTools()
// tools.tools: List<Tool> 包含 name, description, inputSchema

// 调用工具
val result = client.callTool(
    CallToolRequest(
        name = "web_search",
        arguments = mapOf("query" to "最新AI新闻")
    )
)
```

### 6.4 推荐 MCP 服务清单

| MCP 服务 | 功能 | 接入方式 |
|----------|------|---------|
| **Tavily Search** | AI 搜索 | `npx -y tavily-mcp` 或 Streamable HTTP |
| **Context7** | 最新库文档 | `npx -y @upstash/context7-mcp` |
| **GitHub** | 仓库/PR/Issue | `npx -y @modelcontextprotocol/server-github` |
| **Playwright** | 浏览器自动化 | `npx -y @anthropic-ai/mcp-server-playwright` |
| **Filesystem** | 文件操作 | `npx -y @anthropic-ai/mcp-server-filesystem` |

### 6.5 权限分级网关

```kotlin
enum class RiskLevel { LOW, HIGH, CRITICAL }

class MCPPermissionsGateway {
    private val allowedTools = mapOf(
        "web_search"    to RiskLevel.LOW,       // 搜索 → 静默执行
        "read_file"     to RiskLevel.LOW,
        "write_file"    to RiskLevel.HIGH,       // 写入 → 二次确认
        "execute_cmd"   to RiskLevel.CRITICAL,   // Shell → 用户授权
        "payment"       to RiskLevel.CRITICAL    // 支付 → 生物认证
    )

    fun check(toolName: String): RiskLevel =
        allowedTools[toolName] ?: RiskLevel.CRITICAL  // 默认拒绝
}
```

---

## 七、Agent 编排引擎

### 7.1 ReAct Loop（核心调度）

```
用户输入 → Intent Router → ReAct Loop:
  ┌─────────────────────────────────────────┐
  │  1. LLM 推理（分析当前状态）              │
  │  2. 决定：继续执行工具 or 输出最终答案     │
  │  3. 执行工具调用（Skill/MCP/API）         │
  │  4. 观察结果，更新上下文                   │
  │  5. 回到步骤 1，最多 8 轮                  │
  └─────────────────────────────────────────┘
```

### 7.2 整体数据流

```
用户输入
    ↓
Intent Router (意图分类)
    ├── 简单对话 → 直接 LLM 回复
    ├── 知识查询 → RAG 检索 → LLM 生成
    ├── 联网搜索 → Search API → 去重 → Rerank → LLM
    └── 任务执行 → Agent Loop → Skill/MCP 调用链
    ↓
流式返回（打字机效果 + 中间状态展示）
```

### 7.3 记忆系统（三层）

| 层级 | 存储 | 生命周期 | 用途 |
|------|------|---------|------|
| Session Memory | 内存 | 当前会话 | 对话上下文 |
| User Profile | Room DB | 持久化（保留30天活跃项） | 用户偏好注入 System Prompt |
| History | Room DB | 持久化 | 关键词匹配检索历史事件 |

---

## 八、安全架构

### 8.1 五层安全防线

```
第1层：API Key 不落地 → 后端代理
第2层：操作分级门控 → LOW静默 / HIGH确认 / CRITICAL生物认证
第3层：沙箱隔离 → IsolatedProcess (Android) / App Sandbox (iOS)
第4层：MCP 权限网关 → 白名单 + 每次授权确认
第5层：审计日志 → 所有敏感操作全量记录
```

### 8.2 Android 沙箱配置

```xml
<service
    android:name=".AgentExecutionService"
    android:isolatedProcess="true"
    android:exported="true">
</service>
```

### 8.3 Harness Engineering 检查清单

- ✅ 工具数量限制 ≤ 5 个（成功率提升 ~34%）
- ✅ 每个工具描述包含"何时调用" + "约束条件"
- ✅ Agent Loop 硬性限制 `MAX_TURNS = 8`
- ✅ 工具调用超时处理（返回结构化错误而非异常）
- ✅ 危险操作代码级二次确认
- ✅ 注入上下文格式固定，不随对话漂移
- ✅ 任务中断时有 fallback，避免 ANR

---

## 九、成本优化

| 策略 | 节省比例 | 做法 |
|------|---------|------|
| 模型路由 | 50-70% | 简单→小模型，复杂→大模型 |
| 常见任务端侧 | 100% | 端侧 LLM 处理简单任务 |
| 响应缓存 | 30-50% | 语义缓存 + 时间缓存 |
| 上下文压缩 | 20-40% | Compaction 摘要 + 渐进式加载 |

---

## 十、推荐技术栈

| 层级 | Android | iOS |
|------|---------|-----|
| UI | Jetpack Compose | SwiftUI |
| Agent 编排 | 自建 ReAct Loop | 自建 ReAct Loop |
| LLM 接入 | OkHttp + SSE Flow | URLSession + Combine |
| 向量数据库 | sqlite-vec | sqlite-vec (via C) |
| 端侧推理 | ONNX / llama.cpp | CoreML / llama.cpp |
| MCP | Kotlin SDK (官方) | Swift SDK (官方) |
| Skill 系统 | SKILL.md + Registry | SKILL.md + Registry |
| 记忆存储 | Room DB | CoreData / SwiftData |
| 搜索 API | Tavily + Brave | Tavily + Brave |
| 安全 | IsolatedProcess + ACL | App Sandbox + Entitlements |

---

## 十一、实施路线图

```
Phase 1 (第1-2周)：基础骨架
├── LLM API 对接（OpenAI 格式统一适配层）
├── 流式 SSE 接收 + 打字机 UI
├── 基础对话管理（滑动窗口）

Phase 2 (第3-4周)：数据与搜索
├── 本地数据读取抽象层（Notes/Files/DB）
├── 联网搜索接入（Tavily + Brave 双引擎）
├── 本地 RAG Pipeline（Embedding + 向量搜索）

Phase 3 (第5-6周)：Agent 化
├── ReAct Loop 编排引擎
├── Skill 系统（SKILL.md 解析 + 动态加载）
├── MCP 客户端（Kotlin/Swift SDK 集成）

Phase 4 (第7-8周)：生产加固
├── 记忆系统（三层：Session/Profile/History）
├── 安全五层防线
├── 离线降级策略
├── 上下文 Compaction 压缩
├── 性能调优 + 热降频防护
```

---

## 附录：关键参考资源

| 资源 | 说明 |
|------|------|
| `modelcontextprotocol/kotlin-sdk` | MCP 官方 Android SDK |
| `modelcontextprotocol/swift-sdk` | MCP 官方 iOS SDK |
| `modelcontextprotocol.io` | MCP 协议规范 |
| `github.com/openai/skills` | OpenAI 官方 Skills 仓库 |
| `github.com/mobile-next/mobile-mcp` | 手机 MCP 自动化 |
| `github.com/benkaiser/joey-mcp-client` | 最完整的移动端 MCP 客户端 |
| Tavily API / Brave Search API | 搜索 API |
| sqlite-vec | 移动端向量数据库 |
