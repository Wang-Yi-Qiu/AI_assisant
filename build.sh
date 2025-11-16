#!/bin/bash

# HarmonyOS AI Assistant 编译脚本
# 使用 DevEco Studio 的 hvigor 工具进行编译

echo "🚀 开始编译 HarmonyOS AI Assistant 项目..."

# 设置环境变量
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"

# 获取脚本所在目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "📁 项目目录: $PROJECT_DIR"
echo "🔧 SDK 路径: $DEVECO_SDK_HOME"

# 使用 DevEco Studio 的 hvigor 编译
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap

# 检查编译结果
if [ $? -eq 0 ]; then
    echo "✅ 编译成功！"
    echo "📦 HAP 包已生成在 entry/build/outputs/hap/debug/entry-debug-unsigned.hap"
else
    echo "❌ 编译失败"
    exit 1
fi