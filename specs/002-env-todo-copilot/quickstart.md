# Quickstart: 环境搭建与项目运行

**Feature**: 002-env-todo-copilot
**Target**: macOS 开发机 → Android 模拟器 + macOS 桌面

---

## 前置条件

| 组件 | 最低要求 | 验证命令 |
|------|---------|---------|
| macOS | Ventura 13+ | `sw_vers` |
| Xcode | 16.0+ (含 Command Line Tools) | `xcode-select -p` |
| Android Studio | 最新稳定版 | `ls /Applications/Android\ Studio.app` |
| JDK | 17 | `java -version` |
| Homebrew | 最新 | `brew --version` |

---

## Step 1: 安装 Flutter 3.41.7

```bash
# 下载 Flutter SDK
cd ~/development
curl -O https://storage.flutter-io.cn/flutter_infra_release/stable/macos/flutter_macos_3.41.7-stable.zip
unzip flutter_macos_3.41.7-stable.zip

# 配置环境变量 (追加到 ~/.zshrc)
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc
echo 'export PUB_HOSTED_URL=https://pub.flutter-io.cn' >> ~/.zshrc
echo 'export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn' >> ~/.zshrc
source ~/.zshrc

# 验证
flutter --version
# 期望: Flutter 3.41.7 • channel stable
```

---

## Step 2: 配置 Android 开发环境

```bash
# JDK 17
brew install openjdk@17
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
source ~/.zshrc

# Android Studio → SDK Manager → 安装:
#   - Android SDK Platform 36
#   - Android SDK Build-Tools 36
#   - Android SDK Platform-Tools

# 接受许可 + 验证
flutter doctor --android-licenses
flutter doctor -v | grep android
# 期望: [✓] Android toolchain
```

---

## Step 3: 配置 macOS 桌面环境

```bash
# 启用 macOS 桌面支持
flutter config --enable-macos-desktop

# 验证
flutter doctor -v | grep macOS
# 期望: [✓] macOS toolchain
```

---

## Step 4: 创建项目并安装依赖

```bash
# 创建 Flutter 项目
flutter create \
  --org com.example \
  --project-name ai_assistant \
  --platforms android,macos \
  ai_assistant

cd ai_assistant

# 添加依赖 (编辑 pubspec.yaml 后)
flutter pub get

# 验证依赖解析
flutter pub deps
```

---

## Step 5: 运行项目

```bash
# Android 模拟器
flutter emulators --launch <emulator_id>
flutter run -d android

# macOS 桌面
flutter run -d macos

# 查看所有可用设备
flutter devices
```

---

## Step 6: 验证功能 Checklist

- [ ] Android 模拟器上默认 Flutter 应用运行成功
- [ ] macOS 桌面上默认 Flutter 应用运行成功
- [ ] `flutter doctor -v` 无错误（Chrome web 可忽略）
- [ ] `flutter pub get` 无依赖冲突
- [ ] 项目目录结构符合 plan.md 中的布局

---

## 常见问题

| 问题 | 解决方案 |
|------|---------|
| `flutter doctor` 报 Android license 错误 | `flutter doctor --android-licenses` |
| `flutter doctor` 报 Xcode 错误 | 打开 Xcode → 完成组件安装 → 重启终端 |
| `pub get` 超时 | 检查 PUB_HOSTED_URL 是否指向国内镜像 |
| macOS 构建签名错误 | 在 Xcode 中打开 `macos/Runner.xcworkspace` → 配置 Team |

---

## 下一步

环境搭建完成后，参照 `tasks.md`（由 `/speckit.tasks` 生成）开始实现各功能模块。
