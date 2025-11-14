#!/usr/bin/env bash

# 读取 entry/src/main/resources/rawfile/supabase.json 中的 supabaseUrl 与 anonKey
# 并调用 /functions/v1/generate_chart_qwen 进行联调验证。

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
CONF_FILE="$ROOT_DIR/entry/src/main/resources/rawfile/supabase.json"

if [ ! -f "$CONF_FILE" ]; then
  echo "未找到配置文件: $CONF_FILE" >&2
  exit 1
fi

# 使用 Node 原生能力解析 JSON（避免依赖 jq）
read_json() {
  local file=$1 key=$2
  node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$file','utf8'));const v=p['$key'];if(!v){process.exit(2)}console.log(v)" 2>/dev/null || return 2
}

SUPABASE_URL=$(read_json "$CONF_FILE" supabaseUrl || true)
ANON_KEY=$(read_json "$CONF_FILE" anonKey || true)

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${ANON_KEY:-}" ]; then
  echo "配置不完整：请在 $CONF_FILE 填写 supabaseUrl 与 anonKey" >&2
  exit 1
fi

# 规范化 URL
SUPABASE_URL=${SUPABASE_URL%/}
EDGE_URL="$SUPABASE_URL/functions/v1/generate_chart_qwen"

echo "验证地址: $EDGE_URL"

curl -sS "$EDGE_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "apikey: $ANON_KEY" \
  -d '{"temperature":25,"humidity":70}' | sed 's/.*/响应:\n&/'

echo "\n完成：若为 200 且返回 JSON（含 series），说明云端环境变量与鉴权已正确。"


