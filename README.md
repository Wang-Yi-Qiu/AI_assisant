# 鸿蒙 AI 智能数据可视化助手（Supabase云端支持版）

基于 HarmonyOS 的智能数据可视化应用，结合 Supabase 作为轻后端云平台，实现用户数据的 AI 分析与图表自动生成。

## 功能特性

- ✅ **数据输入**：支持上传 CSV、JSON 文件或手动输入文本
- ✅ **AI 生成**：云端调用通义千问（Qwen）生成 ECharts 图表配置
- ✅ **图表渲染**：鸿蒙端使用 WebView + ECharts 渲染图表
- ✅ **多格式导出**：支持导出 PNG、PDF、JSON
- ✅ **历史记录**：查看和复现历史生成的图表
- ✅ **云端同步**：数据与图表配置存储在 Supabase

## 技术架构

- **前端**：HarmonyOS ArkTS + ECharts（WebView）
- **后端**：Supabase（Auth/Storage/Database/Edge Functions）
- **AI 模型**：通义千问（Qwen），通过 DashScope OpenAI 兼容接口调用

## 快速开始

### 环境要求

- DevEco Studio（HarmonyOS 开发环境）
- Supabase 项目账号
- DashScope API Key（通义千问）

### 配置步骤

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd AI_Assistant
   ```

2. **配置 Supabase**
   - 在 Supabase 控制台创建项目
   - 创建 `charts` 表（参考 `specs/001-ai-chart-mvp/data-model.md`）
   - 启用 RLS 策略（参考同上）

3. **配置 Edge Function**
   ```bash
   cd supabase/functions/generate_chart_qwen
   # 设置环境变量
   supabase secrets set DASHSCOPE_API_KEY=your_key
   supabase secrets set QWEN_MODEL=qwen-plus
   # 部署
   supabase functions deploy generate_chart_qwen
   ```

4. **配置前端**
   - 在 `entry/src/main/ets/utils/supabaseClient.ets` 中填入 Supabase URL 和 anon key
   - 在 `entry/src/main/ets/utils/aiService.ets` 中更新 Edge Function URL

5. **构建运行**
   ```bash
   # 使用 DevEco Studio 打开项目并运行
   ```

## 项目结构

```
├── entry/src/main/ets/
│   ├── pages/
│   │   ├── HomePage.ets      # 首页：数据输入
│   │   ├── ChartPage.ets     # 图表页：渲染与导出
│   │   └── HistoryPage.ets   # 历史页：记录列表
│   └── utils/
│       ├── supabaseClient.ets # Supabase 客户端
│       ├── aiService.ets      # AI 服务封装
│       └── fileAccess.ets     # 文件访问工具
├── supabase/functions/
│   └── generate_chart_qwen.ts # Edge Function：Qwen 调用
└── specs/001-ai-chart-mvp/    # 规范文档（spec-kit）
```

## 开发规范

本项目遵循 `spec-kit` 规范驱动开发：

- **规范先行**：OpenAPI + JSON Schema 定义接口与数据契约
- **云端优先**：统一使用 Supabase 能力，前端保持轻量
- **安全合规**：密钥零硬编码，RLS 策略，分化处理
- **可观测性**：结构化日志、错误码、SLO 监控

详见 `.specify/memory/constitution.md`。

## 环境变量

### Edge Function（Supabase Secrets）

- `DASHSCOPE_API_KEY`（必填）：通义千问 API Key
- `DASHSCOPE_API_BASE`（可选）：默认 `https://dashscope.aliyuncs.com/compatible-mode/v1`
- `QWEN_MODEL`（可选）：默认 `qwen-plus`

### 前端配置

- `SUPABASE_URL`：Supabase 项目 URL
- `SUPABASE_ANON_KEY`：Supabase 公开 anon key
- `EDGE_GENERATE_CHART_URL`：Edge Function URL

⚠️ **安全提示**：服务端密钥（如 `DASHSCOPE_API_KEY`）不得在前端代码中暴露。

## 许可证

[待补充]

## 贡献

欢迎提交 Issue 和 Pull Request。

