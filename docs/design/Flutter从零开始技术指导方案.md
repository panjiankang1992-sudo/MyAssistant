# Flutter 跨平台 AI 助手 —— 从零开始技术指导方案

> **目标**: Android + 鸿蒙 NEXT + macOS 三平台 AI 个人助手
> **核心技术**: Flutter 3.41.7 + Platform Channel + 腾讯云 IM + DeepSeek Agent
> **最后更新**: 2026-05-16

---

## 目录

- [第一部分：环境搭建](#第一部分环境搭建)
  - [1.1 Flutter 标准环境 (Android + macOS)](#11-flutter-标准环境-android--macos)
  - [1.2 Flutter-OH 鸿蒙环境 (额外)](#12-flutter-oh-鸿蒙环境-额外)
  - [1.3 双版本 Flutter 并存方案 (FVM)](#13-双版本-flutter-并存方案-fvm)
- [第二部分：项目初始化](#第二部分项目初始化)
  - [2.1 创建三平台项目](#21-创建三平台项目)
  - [2.2 项目目录结构](#22-项目目录结构)
  - [2.3 依赖与状态管理](#23-依赖与状态管理)
- [第三部分：平台原生能力集成](#第三部分平台原生能力集成)
  - [3.1 Android 通知监听](#31-android-通知监听)
  - [3.2 鸿蒙意图分享接收](#32-鸿蒙意图分享接收)
  - [3.3 macOS 消息读取](#33-macos-消息读取)
- [第四部分：数据层与同步](#第四部分数据层与同步)
  - [4.1 本地数据库设计](#41-本地数据库设计)
  - [4.2 腾讯云 IM 集成](#42-腾讯云-im-集成)
  - [4.3 服务端 API 设计](#43-服务端-api-设计)
- [第五部分：AI Agent 集成](#第五部分ai-agent-集成)
- [第六部分：调试、构建与分发](#第六部分调试构建与分发)

---

## 第一部分：环境搭建

### 1.1 Flutter 标准环境 (Android + macOS)

#### 1.1.1 系统要求

| | macOS 开发机 | Windows 开发机 |
|---|---|---|
| OS | macOS 13 (Ventura) 或更高 | Windows 10/11 64 位 |
| 硬盘 | 50GB+ 可用空间 | 50GB+ 可用空间 |
| 内存 | 8GB+ (推荐 16GB) | 16GB+ (推荐，尤其同时跑多个 IDE) |
| CPU | Apple Silicon (M 系列) 或 Intel | Intel Core i5 或更高 |

> **强烈建议用 macOS 开发机**：同时打 Android + 鸿蒙 + macOS 三个包，macOS 是唯一能覆盖三端的开发环境。

#### 1.1.2 安装 Flutter 3.41.7

```bash
# ===== 方式一：直接安装（推荐新手） =====
# 1. 下载 Flutter SDK
#    macOS: https://storage.flutter-io.cn/flutter_infra_release/stable/macos/flutter_macos_3.41.7-stable.zip
#    Windows: https://storage.flutter-io.cn/flutter_infra_release/stable/windows/flutter_windows_3.41.7-stable.zip

# 2. 解压到合适位置
cd ~/development
unzip ~/Downloads/flutter_macos_3.41.7-stable.zip

# 3. 配置环境变量（写入 ~/.zshrc 或 ~/.bash_profile）
export PATH="$HOME/development/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# 4. 生效并验证
source ~/.zshrc
flutter --version
# 输出: Flutter 3.41.7 • channel stable • ...
```

```bash
# ===== 方式二：FVM 版本管理（推荐团队开发） =====
dart pub global activate fvm
fvm install 3.41.7
fvm global 3.41.7    # 设为全局默认
```

#### 1.1.3 Android 开发环境

| 组件 | 版本/要求 | 安装方式 |
|------|----------|---------|
| **JDK** | JDK 17 (必须) | `brew install openjdk@17` 或手动安装 |
| **Android Studio** | 最新稳定版 | https://developer.android.com/studio |
| **Android SDK** | API 36 + Build Tools 36 | Android Studio → SDK Manager |
| **Gradle** | 9.x (Flutter 3.41 默认) | 随 Android Studio 安装 |
| **Kotlin** | 2.1.0+ (插件开发用) | 随 Android Studio |

```bash
# 安装 JDK 17 (macOS)
brew install openjdk@17

# 配置 JAVA_HOME
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
source ~/.zshrc

# Android Studio 安装后，执行 SDK 安装
# 打开 Android Studio → SDK Manager → 勾选:
#   - Android SDK Platform 36
#   - Android SDK Build-Tools 36
#   - Android SDK Platform-Tools
#   - NDK (如果需要编译原生 C/C++)
```

**验证 Android 环境**:

```bash
flutter doctor --android-licenses  # 接受所有 Android SDK 许可
flutter doctor -v | grep -A2 android
# 应该看到 [✓] Android toolchain
```

#### 1.1.4 macOS 桌面开发环境

| 组件 | 版本要求 | 说明 |
|------|---------|------|
| **Xcode** | 16.0+ | Mac App Store 下载，**必须完整安装** |
| **Command Line Tools** | 随 Xcode 安装 | `xcode-select --install` 手动安装 |
| **CocoaPods** | 最新版 (仅部分旧插件需要) | `sudo gem install cocoapods` |

```bash
# 验证 macOS 桌面环境
flutter config --enable-macos-desktop
flutter doctor -v | grep -A2 macOS
# 应该看到 [✓] macOS toolchain
```

**macOS 桌面注意事项**:
- macOS 桌面 App 默认以**沙盒模式**运行，要读取系统通知/消息需要「完全磁盘访问权限」（在 `macos/Runner/DebugProfile.entitlements` 和 `Release.entitlements` 中配置）
- 若不上 Mac App Store（官网 DMG 分发），可以用非沙盒模式，去掉 entitlements 中的沙盒限制

#### 1.1.5 最终验证

```bash
flutter doctor -v
```

期望输出：
```
[✓] Flutter (Channel stable, 3.41.7, on macOS ...)
[✓] Android toolchain - develop for Android devices
[✓] Xcode - develop for macOS
[!] Chrome - develop for the web (可忽略)
[✓] Android Studio
[✓] Connected device (2 available)
```

---

### 1.2 Flutter-OH 鸿蒙环境 (额外)

> ⚠️ **关键概念**：Flutter 鸿蒙版是独立的分叉仓库，**不与标准 Flutter 共享同一个目录**。

#### 1.2.1 前置条件

1. **注册华为开发者账号**：[https://developer.huawei.com](https://developer.huawei.com)
2. **完成实名认证**：个人（身份证+人脸识别，几小时完成）/ 企业（营业执照）
3. **下载 DevEco Studio 5.0.x**：[https://developer.huawei.com/consumer/cn/deveco-studio](https://developer.huawei.com/consumer/cn/deveco-studio)

#### 1.2.2 安装 DevEco Studio

```bash
# macOS - 安装后打开，路径不能包含中文或空格
# 安装到默认位置: /Applications/DevEco-Studio.app

# 启动后：
# 1. 登录华为开发者账号
# 2. File → Settings → OpenHarmony SDK → 下载 API 12 或更高
# 3. 记录 SDK 路径，默认:
#    macOS: /Applications/DevEco-Studio.app/Contents/sdk
#    Windows: C:\Users\<用户名>\AppData\Local\Huawei\DevEco Studio\sdk
```

#### 1.2.3 JDK 配置

鸿蒙端的 JDK 配置与 Android 分开管理：

| 环境变量 | 路径 | 说明 |
|---------|------|------|
| `JAVA_HOME` | JDK 17 路径 | Flutter 标准版用 |
| `DEVECO_SDK_HOME` | DevEco SDK 路径 | Flutter-OH 用 |
| `TOOL_HOME` | DevEco 的 hvigor 工具路径 | 构建工具链 |

#### 1.2.4 安装 Flutter-OH SDK

```bash
# ===== Step 1: 克隆 Flutter-OH 仓库 =====
# 注意：克隆到与标准 Flutter 不同的目录
cd ~/development
git clone https://gitcode.com/openharmony-sig/flutter_flutter.git flutter_ohos

# ===== Step 2: 切换到稳定分支 =====
cd flutter_ohos

# 当前推荐稳定版本 (2026 Q2)
git checkout 3.27.4-ohos-1.0.1

# 如果上述 tag 不存在，查找最新 ohos tag:
git tag | grep ohos
# 选择一个最新的 stable tag

# ===== Step 3: 配置环境变量 =====
# 写入 ~/.zshrc
export TOOL_HOME=/Applications/DevEco-Studio.app/Contents/tools
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export PATH=$HOME/development/flutter_ohos/bin:$PATH
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# 重要: 不要把标准 flutter 的 PATH 和 Flutter-OH 的 PATH 同时写入！
# 要用 FVM 或在切换时手动修改 PATH，见 1.3 节。

source ~/.zshrc

# ===== Step 4: 初始化鸿蒙工具链 =====
flutter doctor -v
# 特别注意看 "OpenHarmony toolchain" 项
# 如果状态异常，检查 TOOL_HOME 和 DEVECO_SDK_HOME 是否指向正确路径
```

#### 1.2.5 创建鸿蒙模拟器

```
DevEco Studio → 右上角设备管理 → Device Manager
→ 点击 "New Emulator" → 选择手机设备 → 下载系统镜像 → 启动
```

或通过命令行启动：
```bash
# 查看可用模拟器
/Applications/DevEco-Studio.app/Contents/tools/emulator/bin/emulator -list-avds

# 启动模拟器
/Applications/DevEco-Studio.app/Contents/tools/emulator/bin/emulator -avd <avd_name>
```

#### 1.2.6 配置调试签名

```bash
# 方式一：通过 DevEco Studio 自动生成（推荐）
# File → Project Structure → Sign Configs → 自动生成 p12 + bks

# 方式二：命令行生成
cd /path/to/ohos_project
hvigorw assembleHap --mode module -p product=default --no-daemon
# 首次生成会自动创建调试签名
```

---

### 1.3 双版本 Flutter 并存方案 (FVM)

由于标准 Flutter 和 Flutter-OH 无法共用同一个 SDK 目录，用 **FVM** 管理两个版本是最优雅的方案。

```bash
# 1. 安装 FVM
dart pub global activate fvm

# 2. 安装标准 Flutter
fvm install 3.41.7

# 3. 安装 Flutter-OH（作为自定义 SDK 导入）
cd ~/development/flutter_ohos
git checkout 3.27.4-ohos-1.0.1

# 4. FVM 使用自定义 Flutter SDK
fvm use 3.41.7 --global          # 全局默认：标准 Flutter

# 5. 在项目目录中指定版本
cd ~/projects/ai_assistant
fvm use 3.41.7                    # 标准 Flutter 开发 Android/macOS
# 或者，当开发鸿蒙时，手动指定：
# 暂时切换 PATH 到 flutter_ohos，或使用项目级配置
```

**推荐工作流**：为鸿蒙开发单独准备一个终端窗口，其中 `PATH` 指向 Flutter-OH：

```bash
# 终端 1 (日常开发 Android + macOS): 使用标准 Flutter
# 终端 2 (鸿蒙构建): 使用 Flutter-OH

# 终端 2 的 ~/.zshrc 中注释掉标准 flutter，启用 flutter_ohos:
export PATH=$HOME/development/flutter_ohos/bin:$HOME/fvm/default/bin:$PATH
```

---

## 第二部分：项目初始化

### 2.1 创建三平台项目

```bash
# ===== Step 1: 用标准 Flutter 创建项目基础 =====
flutter create \
  --org com.example \
  --project-name ai_assistant \
  --platforms android,macos \
  ai_assistant

cd ai_assistant

# ===== Step 2: 创建鸿蒙平台目录（手动） =====
# 切换到 Flutter-OH SDK 的终端
# 在项目根目录下:
flutter create --platforms ohos .

# 这会自动生成 ohos/ 目录和所需模板文件
```

此时项目结构：
```
ai_assistant/
├── android/           # Android 原生代码
├── macos/             # macOS 原生代码
├── ohos/              # 鸿蒙原生代码
├── lib/               # Dart 共享代码 ★
│   └── main.dart
├── test/              # 测试
├── pubspec.yaml       # 依赖声明
└── analysis_options.yaml
```

### 2.2 项目目录结构

推荐的完整项目架构：

```
ai_assistant/
├── android/
│   └── app/src/main/kotlin/com/example/ai_assistant/
│       ├── MainActivity.kt
│       ├── NotificationListener.kt          # 通知监听服务
│       └── AssistantPlugin.kt              # Flutter Platform Channel 插件
│
├── macos/
│   └── Runner/
│       ├── AppDelegate.swift
│       ├── MessageReader.swift             # chat.db 消息读取
│       └── Release.entitlements
│
├── ohos/
│   └── entry/src/main/ets/
│       ├── entryability/
│       │   └── EntryAbility.ets            # 主入口 + Platform Channel
│       └── share/
│           └── ShareEntryAbility.ets       # 意图分享接收
│
├── lib/
│   ├── main.dart                           # 应用入口
│   ├── app.dart                            # MaterialApp 配置
│   ├── router.dart                         # 路由定义 (go_router)
│   │
│   ├── core/                               # 核心基础设施
│   │   ├── di/                             # 依赖注入 (get_it)
│   │   ├── network/                        # 网络层 (dio + interceptor)
│   │   ├── database/                       # 本地数据库 (drift)
│   │   └── im/                             # 腾讯云 IM 封装
│   │
│   ├── domain/                             # 领域层（纯 Dart）
│   │   ├── models/                         # 数据模型
│   │   │   ├── todo.dart
│   │   │   ├── bill.dart
│   │   │   └── notification_item.dart
│   │   └── repositories/                   # 仓库接口
│   │
│   ├── data/                               # 数据层
│   │   ├── repositories/                   # 仓库实现
│   │   ├── datasources/                    # 数据源
│   │   │   ├── local_datasource.dart       # SQLite 操作
│   │   │   └── remote_datasource.dart      # 服务端 API
│   │   └── mappers/                        # 数据映射
│   │
│   ├── features/                           # 功能模块
│   │   ├── home/                           # 首页（待办/账单总览）
│   │   ├── notification/                   # 通知管理
│   │   ├── agent/                          # AI Agent 对话
│   │   ├── settings/                       # 设置
│   │   └── auth/                           # 登录/注册
│   │
│   ├── platform/                           # 平台桥接抽象层
│   │   ├── platform_service.dart           # 接口定义
│   │   └── platform_service_stub.dart      # 默认实现
│   │
│   └── shared/                             # 共享 UI 组件
│       ├── widgets/
│       └── theme/
│
├── pubspec.yaml
└── analysis_options.yaml
```

### 2.3 依赖与状态管理

**pubspec.yaml 核心依赖**:

```yaml
name: ai_assistant
description: AI Personal Assistant
version: 0.1.0+1

environment:
  sdk: ^3.11.5

dependencies:
  flutter:
    sdk: flutter

  # ===== 状态管理 =====
  flutter_riverpod: ^3.0.0          # 状态管理（Riverpod 3.x）
  riverpod_annotation: ^3.0.0

  # ===== 路由 =====
  go_router: ^14.0.0                # 路由管理

  # ===== 网络 =====
  dio: ^5.4.0                       # HTTP 客户端
  retrofit: ^4.1.0                  # 类型安全 API

  # ===== 本地存储 =====
  drift: ^2.18.0                    # SQLite ORM
  sqlite3_flutter_libs: ^0.5.0     # SQLite 原生库

  # ===== 腾讯云 IM =====
  tencent_cloud_chat_sdk: ^latest   # IM SDK

  # ===== 平台桥接 =====
  permission_handler: ^11.3.0       # 权限管理

  # ===== UI =====
  flutter_animate: ^4.5.0
  lottie: ^3.1.0

  # ===== 工具 =====
  freezed_annotation: ^2.4.1        # 不可变数据类
  json_annotation: ^4.9.0           # JSON 序列化
  intl: ^0.19.0                     # 国际化和日期格式化
  uuid: ^4.4.0                      # UUID 生成

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  drift_dev: ^2.18.0
  riverpod_generator: ^3.0.0
  retrofit_generator: ^8.1.0
```

---

## 第三部分：平台原生能力集成

### 3.1 Android 通知监听

#### 3.1.1 架构

```
Android 系统通知
      │
      ▼
NotificationListenerService (Kotlin 原生服务)
      │
      ├── 白名单过滤（只监听用户授权的App）
      ├── OTP 过滤（本地识别，不上传）
      ├── 敏感信息脱敏
      │
      ▼
Flutter Platform Channel → Dart 层处理
      │
      ▼
服务端 Agent 分析 → 分类 + 结构化提取
```

#### 3.1.2 权限声明 (`android/app/src/main/AndroidManifest.xml`)

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- 通知监听权限 -->
    <uses-permission android:name="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE" />

    <!-- 前台服务（保活） -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <!-- 敏感通知读取（Android 15+ OTP 等） -->
    <uses-permission android:name="android.permission.RECEIVE_SENSITIVE_NOTIFICATIONS" />

    <application>
        <!-- 通知监听服务 -->
        <service
            android:name=".NotificationListener"
            android:exported="true"
            android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
            <intent-filter>
                <action android:name="android.service.notification.NotificationListenerService" />
            </intent-filter>
        </service>

        <!-- 前台服务类型声明 (Android 14+) -->
        <service
            android:name=".KeepAliveService"
            android:foregroundServiceType="specialUse"
            android:exported="false" />

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop">
            <!-- ... -->
        </activity>
    </application>
</manifest>
```

#### 3.1.3 通知监听服务 (`android/.../NotificationListener.kt`)

```kotlin
package com.example.ai_assistant

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.os.Build
import java.util.regex.Pattern

class NotificationListener : NotificationListenerService() {

    companion object {
        // OTP 正则 - 匹配验证码类短信
        private val OTP_PATTERNS = arrayOf(
            Pattern.compile("验证码[是为：:]\\s*\\d{4,8}"),
            Pattern.compile("\\d{4,8}\\s*[是为]?[您你]?的?验证码"),
            Pattern.compile("verification code[\\s:]*\\d{4,8}", Pattern.CASE_INSENSITIVE),
        )

        // 默认白名单 App（用户可配置）
        val DEFAULT_WHITELIST = setOf(
            "com.android.mms",           // 短信
            "com.tencent.mm",            // 微信
            "com.eg.android.AlipayGphone", // 支付宝
            // 用户可在设置中添加更多
        )

        var flutterMethodChannel: MethodChannel? = null
        var flutterEventChannel: EventChannel? = null
        var flutterEventSink: EventChannel.EventSink? = null
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        // 通知 Flutter 端：服务已连接
        flutterMethodChannel?.invokeMethod("onNotificationServiceConnected", null)
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        flutterMethodChannel?.invokeMethod("onNotificationServiceDisconnected", null)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification, rankingMap: RankingMap) {
        // ===== 1. 检查权限 =====
        if (!isEnabled) return

        // ===== 2. 白名单过滤 =====
        val packageName = sbn.packageName
        if (packageName !in getCurrentWhitelist()) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""

        // 空通知跳过
        if (title.isEmpty() && text.isEmpty()) return

        // ===== 3. OTP 过滤 =====
        val combined = "$title $text"
        if (isOtpContent(combined)) {
            // 验证码通知不处理，不上传到服务端
            return
        }

        // ===== 4. 发送到 Flutter 层 =====
        val notificationData = mapOf(
            "packageName" to packageName,
            "appName" to getAppName(packageName),
            "title" to title,
            "text" to text,
            "postTime" to sbn.postTime,
            "isClearable" to sbn.isClearable,
            "platform" to "android",
        )

        flutterEventSink?.success(notificationData)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // 通知被移除时的处理（可选）
    }

    private fun isOtpContent(text: String): Boolean {
        return OTP_PATTERNS.any { it.matcher(text).find() }
    }

    private fun getAppName(packageName: String): String {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }

    private fun getCurrentWhitelist(): Set<String> {
        // 从 SharedPreferences 读取用户配置的白名单
        // 可以通过 Platform Channel 让 Flutter 端读写
        return DEFAULT_WHITELIST
    }

    // 检查服务是否被用户开启
    private val isEnabled: Boolean
        get() {
            val contentResolver = applicationContext.contentResolver
            val enabledListeners = android.provider.Settings.Secure.getString(
                contentResolver,
                "enabled_notification_listeners"
            )
            return enabledListeners?.contains(packageName) == true
        }
}
```

#### 3.1.4 Platform Channel 注册 (`MainActivity.kt`)

```kotlin
package com.example.ai_assistant

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ai_assistant/notification"
    private val EVENT_CHANNEL = "com.example.ai_assistant/notification_event"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ===== MethodChannel: 命令式调用 =====
        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
        NotificationListener.flutterMethodChannel = methodChannel

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationServiceEnabled" -> {
                    val enabled = checkNotificationServiceEnabled()
                    result.success(enabled)
                }
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(null)
                }
                "updateWhitelist" -> {
                    // 更新白名单逻辑
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ===== EventChannel: 事件流（通知到达时推送） =====
        val eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL
        )
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, events: EventChannel.EventSink) {
                NotificationListener.flutterEventSink = events
            }
            override fun onCancel(args: Any?) {
                NotificationListener.flutterEventSink = null
            }
        })
    }

    private fun checkNotificationServiceEnabled(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        )
        return enabledListeners?.contains(packageName) == true
    }

    private fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        startActivity(intent)
    }
}
```

#### 3.1.5 Flutter 端调用 (`lib/platform/notification_service.dart`)

```dart
import 'dart:async';
import 'package:flutter/services.dart';

/// 通知数据模型
class NotificationItem {
  final String packageName;
  final String appName;
  final String title;
  final String text;
  final int postTime;
  final bool isClearable;
  final String platform;

  NotificationItem({
    required this.packageName,
    required this.appName,
    required this.title,
    required this.text,
    required this.postTime,
    required this.isClearable,
    this.platform = 'android',
  });

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      title: map['title'] as String,
      text: map['text'] as String,
      postTime: map['postTime'] as int,
      isClearable: map['isClearable'] as bool,
      platform: map['platform'] as String? ?? 'android',
    );
  }
}

/// 平台通知服务抽象
abstract class NotificationPlatformService {
  Future<bool> isServiceEnabled();
  Future<void> openSettings();
  Stream<NotificationItem> get notificationStream;
}

/// Android 实现
class AndroidNotificationService implements NotificationPlatformService {
  static const _channel = MethodChannel('com.example.ai_assistant/notification');
  static const _eventChannel = EventChannel('com.example.ai_assistant/notification_event');

  @override
  Future<bool> isServiceEnabled() async {
    return await _channel.invokeMethod('isNotificationServiceEnabled') ?? false;
  }

  @override
  Future<void> openSettings() async {
    await _channel.invokeMethod('openNotificationSettings');
  }

  @override
  Stream<NotificationItem> get notificationStream {
    return _eventChannel
        .receiveBroadcastStream()
        .map((data) => NotificationItem.fromMap(
              Map<String, dynamic>.from(data as Map),
            ));
  }
}
```

---

### 3.2 鸿蒙意图分享接收

由于鸿蒙端无法自动监听通知，通过「意图分享」框架让用户主动分享通知文本。

#### 3.2.1 module.json5 注册

```json5
// ohos/entry/src/main/module.json5
{
  "module": {
    "name": "entry",
    "type": "entry",
    "abilities": [
      // 主入口
      {
        "name": "EntryAbility",
        "srcEntry": "./ets/entryability/EntryAbility.ets",
        "exported": true
      },
      // 分享接收 Ability
      {
        "name": "ShareEntryAbility",
        "srcEntry": "./ets/share/ShareEntryAbility.ets",
        "exported": true,
        "skills": [
          {
            "entities": ["entity.system.default"],
            "actions": ["ohos.want.action.sendData"]
          }
        ]
      }
    ]
  }
}
```

#### 3.2.2 分享接收实现 (`ShareEntryAbility.ets`)

```typescript
// ohos/entry/src/main/ets/share/ShareEntryAbility.ets
import { UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { FlutterPlugin } from '../flutter/FlutterPlugin';

export default class ShareEntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam);
    this.handleShare(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 应用已在后台运行时收到分享
    this.handleShare(want);
  }

  private handleShare(want: Want): void {
    // 提取分享的文本内容
    const sharedText = want.parameters?.['harmony.share.text'] as string;

    if (sharedText && sharedText.trim().length > 0) {
      // 通过 EventChannel 发送到 Flutter 层
      FlutterPlugin.sendNotificationEvent({
        packageName: want.bundleName || 'unknown',
        appName: want.parameters?.['harmony.share.sourceAppName'] || '未知应用',
        title: sharedText.substring(0, 50), // 前50字符作为标题
        text: sharedText,
        postTime: Date.now(),
        isClearable: true,
        platform: 'harmonyos',
        source: 'share_intent' // 标记来源为意图分享
      });

      // 关闭分享界面（用户不需要看到空页面）
      this.terminateSelf();
    }
  }

  onDestroy(): void {
    super.onDestroy();
  }
}
```

#### 3.2.3 鸿蒙 Platform Channel 注册 (`EntryAbility.ets`)

```typescript
// ohos/entry/src/main/ets/entryability/EntryAbility.ets
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { MethodChannel, EventChannel } from '@ohos/flutter_ohos';
import { Clipboard } from '@ohos/data';
import { notification } from '@kit.NotificationKit';

class FlutterPlugin {
  static eventSink: EventChannel.EventSink | null = null;

  static sendNotificationEvent(data: Record<string, Object>): void {
    if (FlutterPlugin.eventSink) {
      FlutterPlugin.eventSink.success(data);
    }
  }
}

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);

    const messenger = flutterEngine.dartExecutor.getBinaryMessenger();

    // MethodChannel: 功能调用
    const methodChannel = new MethodChannel(messenger, 'com.example.ai_assistant/notification');
    methodChannel.setMethodCallHandler((call, result) => {
      switch (call.method) {
        case 'checkClipboard':
          // 读取剪贴板（辅助方案：用户手动复制通知文本后读取）
          try {
            // 注意：鸿蒙对剪贴板后台读取有限制，需要用户在应用中触发
            const text = ''; // 实际需要结合 Clipboard Kit
            result.success(text);
          } catch (e) {
            result.error('CLIPBOARD_ERROR', '无法读取剪贴板', e);
          }
          break;

        case 'isShareSupported':
          // 鸿蒙端始终支持意图分享
          result.success(true);
          break;

        default:
          result.notImplemented();
          break;
      }
    });

    // EventChannel: 通知事件流
    const eventChannel = new EventChannel(messenger, 'com.example.ai_assistant/notification_event');
    eventChannel.setStreamHandler({
      onListen(args, events) {
        FlutterPlugin.eventSink = events;
      },
      onCancel(args) {
        FlutterPlugin.eventSink = null;
      }
    });
  }
}
```

---

### 3.3 macOS 消息读取

macOS 端读取 `~/Library/Messages/chat.db`，获取 iMessage 和短信转发的内容。

#### 3.3.1 权限配置 (`macos/Runner/Release.entitlements`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 如果需要上架 Mac App Store，必须在这里配置沙盒权限 -->
    <!-- 非 Mac App Store 分发（官网 DMG）可注释掉沙盒 -->
    <!--
    <key>com.apple.security.app-sandbox</key>
    <true/>
    -->

    <!-- 完全磁盘访问：读取 chat.db 需要 -->
    <!-- 这个权限实际由用户在「系统设置 → 隐私 → 完全磁盘访问权限」中手动授予 -->
    <!-- Entitlements 中只需要确保应用不会被沙盒拦截文件读取 -->

    <!-- 网络权限 -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- 如果不需要 Mac App Store，直接设为非沙盒 -->
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

> ⚠️ **注意**：如果要读 `chat.db`，应用**不能**是 Mac App Store 沙盒应用。建议走**官网 DMG 分发**路径。

#### 3.3.2 消息读取服务 (`macos/Runner/MessageReader.swift`)

```swift
import Foundation
import SQLite3

class MessageReader {
    static let shared = MessageReader()

    private var db: OpaquePointer?
    private var timer: Timer?
    private var lastReadDate: Date

    // 消息回调（将通过 Platform Channel 发送到 Flutter）
    var onNewMessage: (([String: Any]) -> Void)?

    private init() {
        self.lastReadDate = Date()
        openDatabase()
    }

    // MARK: - 数据库连接

    private func openDatabase() {
        let dbPath = NSHomeDirectory() + "/Library/Messages/chat.db"

        // 需要「完全磁盘访问权限」才能读取
        guard FileManager.default.isReadableFile(atPath: dbPath) else {
            print("[MessageReader] 无法读取 chat.db，请授予完全磁盘访问权限")
            return
        }

        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            print("[MessageReader] 成功打开 Messages 数据库")
            startPolling()
        } else {
            let error = String(cString: sqlite3_errmsg(db))
            print("[MessageReader] 打开数据库失败: \(error)")
        }
    }

    // MARK: - 轮询新消息

    func startPolling(interval: TimeInterval = 2.0) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkNewMessages()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func checkNewMessages() {
        let newMessages = fetchNewMessages(since: lastReadDate)
        lastReadDate = Date()

        for message in newMessages {
            // 只处理收到的消息（非自己发送的）
            guard let isFromMe = message["is_from_me"] as? Int,
                  isFromMe == 0 else { continue }

            // 构造与 Android 端一致的数据格式
            let notificationData: [String: Any] = [
                "packageName": "com.apple.messages",
                "appName": "信息",
                "title": message["sender"] as? String ?? "未知",
                "text": message["text"] as? String ?? "",
                "postTime": Int((message["date"] as? Date ?? Date()).timeIntervalSince1970 * 1000),
                "isClearable": true,
                "platform": "macos",
                "source": "imessage"
            ]

            onNewMessage?(notificationData)
        }
    }

    // MARK: - SQL 查询

    private func fetchNewMessages(since date: Date) -> [[String: Any]] {
        guard db != nil else { return [] }

        let dateInt = Int(date.timeIntervalSince1970 * 1_000_000_000 +
            TimeInterval(Calendar.current.timeZone.secondsFromGMT(for: date)) * 1_000_000_000)

        let query = """
            SELECT
                message.ROWID,
                message.text,
                message.date,
                message.is_from_me,
                handle.id AS sender
            FROM message
            LEFT JOIN chat_message_join ON message.ROWID = chat_message_join.message_id
            LEFT JOIN chat ON chat_message_join.chat_id = chat.ROWID
            LEFT JOIN handle ON message.handle_id = handle.ROWID
            WHERE message.date > ?
            ORDER BY message.date ASC
            LIMIT 50
        """

        var statement: OpaquePointer?
        var results: [[String: Any]] = []

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, Int64(dateInt))

            while sqlite3_step(statement) == SQLITE_ROW {
                let text = String(cString: sqlite3_column_text(statement, 1))
                let dateInt = sqlite3_column_int64(statement, 2)
                let isFromMe = sqlite3_column_int(statement, 3)
                let sender = String(cString: sqlite3_column_text(statement, 4))

                // 转换 macOS 时间戳 (自 2001-01-01 的纳秒数)
                let epochDate = TimeInterval(dateInt) / 1_000_000_000.0
                let refDate = Date(timeIntervalSinceReferenceDate: 0) // 2001-01-01
                let messageDate = refDate.addingTimeInterval(epochDate)

                results.append([
                    "text": text,
                    "date": messageDate,
                    "is_from_me": Int(isFromMe),
                    "sender": sender
                ])
            }

            sqlite3_finalize(statement)
        }

        return results
    }

    deinit {
        stopPolling()
        if db != nil {
            sqlite3_close(db)
        }
    }
}
```

#### 3.3.3 macOS Platform Channel (`macos/Runner/AppDelegate.swift`)

```swift
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化消息读取器
        MessageReader.shared.onNewMessage = { [weak self] data in
            self?.sendToFlutter(data)
        }
    }

    private func sendToFlutter(_ data: [String: Any]) {
        guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
            return
        }

        let channel = FlutterEventChannel(
            name: "com.example.ai_assistant/notification_event",
            binaryMessenger: controller.engine.binaryMessenger
        )

        // 通过 EventChannel 发送（需要在 Flutter 端 addStreamHandler）
        // 或者通过 MethodChannel 发送
    }
}
```

---

## 第四部分：数据层与同步

### 4.1 本地数据库设计 (Drift)

```dart
// lib/core/database/database.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart'; // drift_dev 生成

// ===== 待办表 =====
class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(1))(); // 0=low, 1=mid, 2=high
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  TextColumn get sourceNotificationId => text().nullable()(); // 来源通知ID
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ===== 账单表 =====
class Bills extends Table {
  TextColumn get id => text()();
  RealColumn get amount => real()();
  TextColumn get category => text()(); // food/shopping/transport/...
  TextColumn get merchant => text().nullable()();
  TextColumn get cardLast4 => text().nullable()();
  DateTimeColumn get transactionDate => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get sourceNotificationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ===== 通知记录表（可选，用于历史回溯） =====
@DataClassName('NotificationRecord')
class NotificationRecords extends Table {
  TextColumn get id => text()();
  TextColumn get packageName => text()();
  TextColumn get appName => text()();
  TextColumn get title => text()();
  TextColumn get text => text()();
  DateTimeColumn get receivedAt => dateTime()();
  TextColumn get analysisResult => text().nullable()(); // JSON: 分类结果

  @override
  Set<Column> get primaryKey => {id};
}

// ===== 数据库定义 =====
@DriftDatabase(tables: [Todos, Bills, NotificationRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'ai_assistant.sqlite'));
      return NativeDatabase(file);
    });
  }
}

// ===== 使用 Riverpod 注入 =====
import 'package:flutter_riverpod/flutter_riverpod.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});
```

### 4.2 腾讯云 IM 集成

IM SDK 作为实时通知通道，不做消息存储（存储用 SQLite + 服务端 PostgreSQL）。

```
服务端数据变更 → IM 推自定义消息 → 客户端收到 → 增量拉取 REST API
```

```dart
// lib/core/im/im_service.dart

import 'package:tencent_cloud_chat_sdk/tencent_cloud_chat_sdk.dart';

/// 封装腾讯云 IM，只做"数据变更通知"通道
class IMService {
  static final IMService _instance = IMService._();
  factory IMService() => _instance;
  IMService._();

  late V2TIMManager _manager;
  bool _initialized = false;

  // 自定义消息类型
  static const String SYNC_TODO_CREATED = 'sync_todo_created';
  static const String SYNC_TODO_UPDATED = 'sync_todo_updated';
  static const String SYNC_BILL_CREATED = 'sync_bill_created';
  static const String SYNC_BILL_UPDATED = 'sync_bill_updated';

  /// 初始化（用户登录后调用）
  Future<void> init(String userId, String userSig) async {
    _manager = TencentCloudChatSdk.instance.manager;

    final result = await _manager.initSDK(
      sdkAppID: YOUR_SDK_APP_ID, // 从腾讯云 IM 控制台获取
      loglevel: LogLevelEnum.V2TIM_LOG_DEBUG,
      listener: V2TimSDKListener(
        onConnecting: () => print('IM 连接中...'),
        onConnectSuccess: () => print('IM 连接成功'),
        onConnectFailed: (code, error) => print('IM 连接失败: $code $error'),
      ),
    );

    if (result.code == 0) {
      await _manager.login(userID: userId, userSig: userSig);
      _initialized = true;

      // 监听自定义消息
      _manager.addAdvancedMsgListener(listener: _messageListener);
    }
  }

  /// 自定义消息监听器
  late final V2TimAdvancedMsgListener _messageListener =
      V2TimAdvancedMsgListener(
    onRecvC2CCustomMessage: (msgID, customData) {
      _handleSyncMessage(customData);
    },
  );

  /// 处理同步消息
  void _handleSyncMessage(String customData) {
    try {
      final data = jsonDecode(customData);
      final type = data['type'] as String;
      final payload = data['payload'] as Map<String, dynamic>;

      switch (type) {
        case SYNC_TODO_CREATED:
        case SYNC_TODO_UPDATED:
          // TODO: 触发数据库增量拉取
          break;
        case SYNC_BILL_CREATED:
        case SYNC_BILL_UPDATED:
          // TODO: 触发数据库增量拉取
          break;
      }
    } catch (e) {
      print('IM 消息解析失败: $e');
    }
  }

  /// 主动推送同步通知到其他设备
  Future<void> notifySync(String type, String entityId) async {
    // 注意：不通过 IM 发送完整数据，只发一个"变更提示"
    // 接收方收到后通过 REST API 增量拉取
    final customData = jsonEncode({
      'type': type,
      'payload': {'entityId': entityId, 'timestamp': DateTime.now().toIso8601String()}
    });

    // 发送到系统消息（所有设备都能收到）
    await _manager.sendC2CCustomMessage(
      customData: customData,
      userID: '', // 发给系统（可在服务端实现）
    );
  }

  void dispose() {
    _manager.removeAdvancedMsgListener(listener: _messageListener);
    _manager.logout();
    _manager.unInitSDK();
  }
}
```

### 4.3 服务端 API 设计

```dart
// lib/core/network/api_client.dart
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'api_client.g.dart';

@RestApi(baseUrl: 'https://api.yourdomain.com/v1')
abstract class ApiClient {
  factory ApiClient(Dio dio) = _ApiClient;

  // ===== 认证 =====
  @POST('/auth/login')
  Future<AuthResponse> login(@Body() LoginRequest request);

  @POST('/auth/refresh')
  Future<AuthResponse> refreshToken(@Body() RefreshRequest request);

  // ===== 待办 =====
  @GET('/todos')
  Future<List<TodoDto>> getTodos({
    @Query('updated_after') String? updatedAfter, // 增量拉取
  });

  @POST('/todos')
  Future<TodoDto> createTodo(@Body() CreateTodoRequest request);

  @PUT('/todos/{id}')
  Future<TodoDto> updateTodo(@Path('id') String id, @Body() UpdateTodoRequest request);

  @DELETE('/todos/{id}')
  Future<void> deleteTodo(@Path('id') String id);

  // ===== 账单 =====
  @GET('/bills')
  Future<List<BillDto>> getBills({
    @Query('updated_after') String? updatedAfter,
  });

  @POST('/bills')
  Future<BillDto> createBill(@Body() CreateBillRequest request);

  // ===== 通知分析 =====
  @POST('/analyze/notification')
  Future<NotificationAnalysisResult> analyzeNotification(
    @Body() NotificationAnalysisRequest request,
  );

  // ===== Agent 对话 =====
  @POST('/agent/chat')
  Future<AgentChatResponse> agentChat(@Body() AgentChatRequest request);

  // SSE 流式输出（用于 Agent 实时回复）
  @GET('/agent/stream')
  Future<Response> agentStream(@Query('session_id') String sessionId);

  // ===== 同步 =====
  @GET('/sync/checkpoint')
  Future<SyncCheckpoint> getCheckpoint();

  @POST('/sync/push')
  Future<void> pushChanges(@Body() PushChangesRequest request);
}
```

---

## 第五部分：AI Agent 集成

### 5.1 Agent 服务端架构

Agent 放在**服务端**执行，Flutter 前端通过 SSE 流式获取 Agent 的思考过程和结果。

```
Flutter 客户端                服务端 Agent
     │                           │
     ├── POST /agent/chat ──────→│
     │   {user_message,           │  ┌─ LLM 调用 (DeepSeek V3.1)
     │    session_id}             │  ├─ Function Calling
     │                            │  ├─ 工具执行 (create_todo / record_bill)
     │   ←──── SSE stream ───────│  └─ 返回结果
     │   {type: "thinking",       │
     │    content: "..."}         │
     │   {type: "tool_call",      │
     │    tool: "create_todo",    │
     │    args: {...}}            │
     │   {type: "done",           │
     │    result: {...}}          │
```

### 5.2 Flutter 端 Agent 服务

```dart
// lib/features/agent/agent_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

/// Agent 流式消息类型
enum AgentMessageType { thinking, toolCall, result, error }

class AgentStreamMessage {
  final AgentMessageType type;
  final String content;
  final Map<String, dynamic>? metadata;

  AgentStreamMessage({required this.type, required this.content, this.metadata});
}

class AgentService {
  final Dio _dio;

  AgentService(this._dio);

  /// 发送消息并接收流式回复
  Stream<AgentStreamMessage> sendMessage(String userMessage, {String? sessionId}) async* {
    final controller = StreamController<AgentStreamMessage>();

    try {
      final response = await _dio.post(
        '/agent/chat',
        data: {
          'user_message': userMessage,
          'session_id': sessionId,
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);

        // SSE 格式解析
        while (buffer.contains('\n')) {
          final index = buffer.indexOf('\n');
          final line = buffer.substring(0, index).trim();
          buffer = buffer.substring(index + 1);

          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            try {
              final data = jsonDecode(jsonStr);
              final type = _parseType(data['type'] as String?);

              yield AgentStreamMessage(
                type: type,
                content: data['content'] as String? ?? '',
                metadata: data['metadata'] as Map<String, dynamic>?,
              );
            } catch (e) {
              // 非 JSON 数据行，跳过
            }
          }
        }
      }
    } catch (e) {
      yield AgentStreamMessage(
        type: AgentMessageType.error,
        content: 'Agent 服务暂时不可用: $e',
      );
    }
  }

  AgentMessageType _parseType(String? type) {
    switch (type) {
      case 'thinking':
        return AgentMessageType.thinking;
      case 'tool_call':
        return AgentMessageType.toolCall;
      case 'result':
        return AgentMessageType.result;
      default:
        return AgentMessageType.error;
    }
  }
}
```

### 5.3 Chat UI 示例

```dart
// lib/features/agent/agent_chat_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final agentServiceProvider = Provider<AgentService>((ref) {
  return AgentService(ref.read(dioProvider));
});

class AgentChatPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<AgentChatPage> createState() => _AgentChatPageState();
}

class _AgentChatPageState extends ConsumerState<AgentChatPage> {
  final _controller = TextEditingController();
  final _messages = <ChatMessage>[];
  StreamSubscription<AgentStreamMessage>? _subscription;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI 助手')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: '告诉 AI 你想做什么...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                ),
                enabled: !_loading,
              ),
            ),
            SizedBox(width: 8),
            FloatingActionButton(
              onPressed: _loading ? null : _sendMessage,
              child: _loading
                  ? SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(isUser: true, content: text));
      _loading = true;
    });

    // 添加一个占位消息用于流式更新
    final botMsg = ChatMessage(isUser: false, content: '');
    setState(() => _messages.add(botMsg));

    final agentService = ref.read(agentServiceProvider);

    _subscription = agentService.sendMessage(text).listen(
      (streamMsg) {
        setState(() {
          switch (streamMsg.type) {
            case AgentMessageType.thinking:
              botMsg.content = '🤔 ${streamMsg.content}';
              break;
            case AgentMessageType.toolCall:
              botMsg.content = '🔧 正在执行: ${streamMsg.content}';
              break;
            case AgentMessageType.result:
              botMsg.content = streamMsg.content;
              _loading = false;
              break;
            case AgentMessageType.error:
              botMsg.content = '❌ ${streamMsg.content}';
              _loading = false;
              break;
          }
        });
      },
      onDone: () {
        setState(() => _loading = false);
      },
      onError: (e) {
        setState(() {
          botMsg.content = '❌ 发生错误: $e';
          _loading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: msg.isUser ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          msg.content,
          style: TextStyle(color: msg.isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}

class ChatMessage {
  final bool isUser;
  String content;
  ChatMessage({required this.isUser, required this.content});
}
```

---

## 第六部分：调试、构建与分发

### 6.1 开发调试

| 目标 | 命令 |
|------|------|
| Android 调试 | `flutter run -d android` |
| macOS 调试 | `flutter run -d macos` |
| 鸿蒙调试 | `flutter run -d ohos` (Flutter-OH SDK) |
| 热重载 | `r` (终端中) |
| 热重启 | `R` |
| DevTools | `flutter pub global run devtools` |

### 6.2 构建产物

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Google Play)
flutter build appbundle --release

# macOS 应用包
flutter build macos --release
# 输出: build/macos/Build/Products/Release/ai_assistant.app

# macOS DMG (使用 create-dmg)
npm install -g create-dmg
create-dmg build/macos/Build/Products/Release/ai_assistant.app \
  --dmg-title="AI 助手" \
  --output=dist/

# 鸿蒙 HAP
flutter build hap --release
# 输出: ohos/entry/build/default/outputs/default/entry-default-signed.hap
```

### 6.3 分发渠道

| 平台 | 渠道 | 关键要求 |
|------|------|---------|
| **Android** | Google Play | 权限声明 + 隐私政策 + Data Safety |
| **Android** | 国内市场 | 华为/小米/OPPO/vivo/应用宝 各自政策 |
| **macOS** | 官网 DMG 分发 | Apple 开发者证书签名 + 公证 |
| **macOS** | Mac App Store | 沙盒模式（但读 chat.db 需非沙盒，建议不走上架） |
| **鸿蒙** | 华为应用市场 | 开发者实名认证 + 应用审核 |

### 6.4 macOS 非沙盒应用的签名与公证

```bash
# 1. 签名
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  build/macos/Build/Products/Release/ai_assistant.app

# 2. 公证 (Notarization)
xcrun notarytool submit ai_assistant.dmg \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID" \
  --password "@keychain:AC_PASSWORD" \
  --wait

# 3. 装订公证票据
xcrun stapler staple ai_assistant.dmg
```

---

## 附录 A：环境变量速查

```bash
# ~/.zshrc 完整配置（标准 Flutter 开发 Android + macOS）
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
export PATH="$HOME/development/flutter/bin:$HOME/.pub-cache/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$PATH"

# 切换到鸿蒙开发时，注释上面一行，取消注释下面：
# export PATH="$HOME/development/flutter_ohos/bin:$HOME/.pub-cache/bin:$PATH"
# export TOOL_HOME=/Applications/DevEco-Studio.app/Contents/tools
# export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
```

## 附录 B：快速启动检查清单

- [ ] Flutter 3.41.7 已安装，`flutter doctor` 全部 ✓
- [ ] Android Studio 已安装，SDK 36 已下载
- [ ] Xcode 16+ 已安装 (macOS)
- [ ] DevEco Studio 5.0.x 已安装，SDK API 12 已下载
- [ ] 华为开发者账号已注册并实名认证
- [ ] Flutter-OH 已克隆并切换到稳定 tag
- [ ] FVM 已安装，双版本管理配置完成
- [ ] Android 模拟器 / 真机可运行
- [ ] macOS 桌面可运行
- [ ] 鸿蒙模拟器可运行
- [ ] 通知监听服务在 Android 上可正常启用
- [ ] 意图分享在鸿蒙上可接收文本
