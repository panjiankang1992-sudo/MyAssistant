#!/bin/bash
# Flutter 3.41.7 配置脚本 (macOS Apple Silicon)
# Flutter SDK 已位于 ~/development/flutter，本脚本仅配置环境变量

echo "⚙️  配置 Flutter 环境变量..."

if grep -q "PUB_HOSTED_URL=https://pub.flutter-io.cn" ~/.zshrc 2>/dev/null; then
  echo "  环境变量已存在，跳过"
else
  cat >> ~/.zshrc << 'EOF'

# ===== Flutter 环境变量 =====
export PATH="$HOME/development/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
EOF
  echo "  已写入 ~/.zshrc"
fi

echo ""
echo "✅ 完成！运行以下命令使配置生效："
echo "   source ~/.zshrc"
