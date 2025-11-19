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

# 停止 hvigor 守护进程以确保清理干净
echo "🧹 清理编译缓存..."
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --stop-daemon 2>/dev/null || true

# 清理构建目录
rm -rf entry/build/ .hvigor/ 2>/dev/null || true

# 使用 DevEco Studio 的 hvigor 编译
echo "🔨 开始编译..."
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap

# 检查编译结果
if [ $? -eq 0 ]; then
    echo "✅ 编译成功！"
    echo "📦 HAP 包已生成在 entry/build/outputs/hap/debug/entry-debug-unsigned.hap"
    echo ""
    echo "💡 如果 DevEco Studio 仍显示编译错误，请尝试："
    echo "   1. File → Invalidate Caches... → Invalidate and Restart"
    echo "   2. File → Sync Project"
    echo "   3. Build → Clean Project → Build → Rebuild Project"
else
    echo "❌ 编译失败"
    exit 1
fi