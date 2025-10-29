鸿蒙 AI 智能数据可视化助手（Supabase云端支持版）项目计划书
一、项目概述

本项目旨在构建一款基于 HarmonyOS（鸿蒙系统） 的智能数据可视化应用，结合 Supabase 作为轻后端云平台，实现用户数据的 AI 分析与图表自动生成。

应用核心目标是让用户只需输入或上传数据，系统即可：

将数据上传到 Supabase；

由云端 AI 模型分析生成 ECharts 图表配置；

鸿蒙端拉取图表结果进行渲染；

支持导出图表（PNG / PDF / JSON）。

该架构既保持前端轻量、灵活，又利用 Supabase 提供安全存储、API代理、身份验证等能力，实现真正的云端智能可视化。

二、项目目标
功能方向	目标说明
数据输入	支持用户上传 CSV、JSON、Excel 文件或手动输入数据
云端同步	所有数据上传至 Supabase 存储或数据库
 AI 分析	云端调用 AI（通义千问 Qwen）生成图表配置
图表展示	鸿蒙端使用 ECharts 渲染 AI 返回配置
图表导出	用户可导出图表（PNG、PDF、JSON）
用户管理	Supabase 提供用户注册 / 登录 / 数据关联
可扩展性	后期可拓展分析报告、语音输入、数据预测等功能
三、系统总体架构
┌────────────────────────────────────────────┐
│           鸿蒙App (DevEco ArkTS)           │
│--------------------------------------------│
│ - 用户上传/输入数据                        │
│ - 登录/注册(Supabase Auth)                 │
│ - 显示AI生成的图表(ECharts)                │
│ - 下载图表(PNG/PDF)                        │
└───────────────┬────────────────────────────┘
                │ HTTPS 请求
┌───────────────┴────────────────────────────┐
│               Supabase 云平台               │
│---------------------------------------------│
│ Auth：用户管理                              │
│ Storage：存储上传文件（CSV、图片等）         │
│ Database：记录图表元数据和AI结果             │
│ Edge Function：AI接口代理(调用Qwen兼容API)  │
└───────────────┬────────────────────────────┘
                │
┌───────────────┴────────────────────────────┐
│               AI 模型服务                   │
│  (通义千问 / 文心一言 等)                  │
│ - 接收数据并返回ECharts配置JSON             │
└────────────────────────────────────────────┘

四、核心功能模块设计
模块	功能说明	技术实现
1️⃣ 数据输入模块	上传CSV/JSON文件或文本输入	ArkTS FilePicker + TextArea
2️⃣ 用户登录模块	Supabase Auth 用户体系	OAuth / 邮箱注册
3️⃣ 云端存储模块	上传数据文件至 Supabase Storage	Supabase SDK
4️⃣ AI分析模块	调用 Supabase Edge Function 接口	fetch() 调用 AI
5️⃣ 图表展示模块	渲染ECharts图表配置	WebView加载ECharts
6️⃣ 图表导出模块	导出图表为 PNG / PDF	ECharts API + jsPDF
7️⃣ 记录模块	将图表配置、生成时间等存数据库	Supabase Database (PostgreSQL)
五、详细实现步骤
阶段一：前端基础结构搭建

创建鸿蒙App项目；

页面结构：

LoginPage.ets：用户登录/注册；

HomePage.ets：上传或输入数据；

ChartPage.ets：展示AI生成图表；

ExportPage.ets：导出图表。

引入 ECharts（通过本地 index.html + WebView 加载）。

阶段二：接入 Supabase

在项目中引入 Supabase SDK（TypeScript 版本）：

import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://your-project-id.supabase.co'
const supabaseKey = 'public-anon-key'
export const supabase = createClient(supabaseUrl, supabaseKey)

功能实现：

用户登录注册 (supabase.auth.signInWithPassword)

上传文件 (supabase.storage.from('datasets').upload(...))

数据存取 (supabase.from('charts').select())

阶段三：云端 AI 调用逻辑（Qwen）

在 Supabase 中创建 Edge Function（Serverless函数），命名为 generate_chart（或 generate_chart_qwen）：

函数逻辑（示例，Qwen OpenAI 兼容接口）：
// /supabase/functions/generate_chart_qwen.ts
import { Ajv } from "https://esm.sh/ajv";
import userDataSchema from "./schemas/userData.schema.json" assert { type: "json" };
import chartConfigSchema from "./schemas/chartConfig.schema.json" assert { type: "json" };

const ajv = new Ajv({ allErrors: true });
const validateIn = ajv.compile(userDataSchema);
const validateOut = ajv.compile(chartConfigSchema);

const API_BASE = Deno.env.get("DASHSCOPE_API_BASE")?.replace(/\/$/, "") ||
  "https://dashscope.aliyuncs.com/compatible-mode/v1";
const API_KEY = Deno.env.get("DASHSCOPE_API_KEY");
const MODEL = Deno.env.get("QWEN_MODEL") || "qwen-plus";

const systemPrompt = `你是数据可视化专家。依据用户提供的数据生成严格符合 ECharts 的 JSON；不要输出任何非 JSON 文本。`;

async function callQwen(messages: Array<{ role: string; content: string }>) {
  const res = await fetch(`${API_BASE}/chat/completions`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: MODEL, temperature: 0, response_format: { type: "json_object" }, messages })
  });
  const data = await res.json();
  return data?.choices?.[0]?.message?.content;
}

export default Deno.serve(async (req) => {
  const body = await req.json();
  if (!validateIn(body)) return new Response(JSON.stringify({ code: "INVALID_INPUT", errors: validateIn.errors }), { status: 400 });
  const content = await callQwen([
    { role: "system", content: systemPrompt },
    { role: "user", content: typeof body === "string" ? body : JSON.stringify(body) },
  ]);
  try {
    const json = JSON.parse(content || "{}");
    if (!validateOut(json)) return new Response(JSON.stringify({ code: "INVALID_MODEL_OUTPUT" }), { status: 502 });
    return new Response(JSON.stringify(json), { headers: { "Content-Type": "application/json" } });
  } catch {
    return new Response(JSON.stringify({ code: "INVALID_JSON_OUTPUT" }), { status: 502 });
  }
})


➡️ 这样鸿蒙前端只需调用：

const res = await fetch('https://your-project.supabase.co/functions/v1/generate_chart', {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${token}` },
  body: JSON.stringify({ data: userData })
})
const chartConfig = await res.json()

阶段四：图表渲染与导出

在鸿蒙前端通过 WebView 加载 ECharts 页面，并传入 JSON 配置：

chart.setOption(chartConfig)


导出功能：

const img = chart.getDataURL({ type: 'png', backgroundColor: '#fff' })
await fileAccess.saveImage(img, 'chart.png')

阶段五：结果存储与展示

每次生成图表后，将元信息写入 Supabase 数据库：

await supabase.from('charts').insert({
  user_id: user.id,
  title: chartConfig.title.text,
  type: chartConfig.series[0].type,
  created_at: new Date(),
  chart_json: chartConfig
})


用户可以在历史记录页查看历史图表。

六、数据库结构设计（Supabase PostgreSQL）
表名	字段名	类型	描述
users	id	uuid	用户唯一ID
	email	text	登录邮箱
	created_at	timestamp	注册时间
charts	id	uuid	图表ID
	user_id	uuid	用户关联
	title	text	图表标题
	type	text	图表类型
	chart_json	jsonb	图表配置
	created_at	timestamp	生成时间
七、技术选型
模块	技术	说明
前端框架	ArkTS（HarmonyOS）	鸿蒙原生开发
图表渲染	ECharts	WebView嵌入
后端服务	Supabase (Edge Function + DB)	无需自行部署
AI 模型	通义千问（Qwen）	生成ECharts配置
数据存储	Supabase Storage	文件上传
数据库	Supabase PostgreSQL	存储图表数据
导出模块	ECharts API / jsPDF	图表导出功能
八、项目结构规划
project-root/
├─ pages/
│  ├─ LoginPage.ets
│  ├─ HomePage.ets
│  ├─ ChartPage.ets
│  ├─ HistoryPage.ets
│  └─ ExportPage.ets
│
├─ utils/
│  ├─ supabaseClient.ets
│  ├─ aiService.ets
│  ├─ fileAccess.ets
│
├─ resources/
│  └─ index.html     # ECharts容器
│
└─ supabase/
   └─ functions/
      └─ generate_chart.ts

九、未来扩展方向

AI 自动生成图表分析说明；

图表模板与样式中心；

多人协作与数据共享；

支持语音输入、自动预测趋势；

图表云端同步与分享链接。

十、预期成果

✅ 用户可在鸿蒙App内输入数据并自动生成图表；
✅ 图表可直接导出、保存、云端备份；
✅ Supabase 保障用户安全登录与数据管理；
✅ 无需独立后端部署，系统维护简单；
✅ 架构灵活，便于扩展 AI 功能与可视化能力。

十一、与 spec-kit 集成方案

目标：以“规范先行”的方式固化接口、数据结构与页面契约，保障前后端/函数间一致性，并实现自动校验与代码生成。

1. 规范产物
- API 规范：OpenAPI（generate_chart、鉴权、文件上传代理等）
- 数据契约：图表配置与用户数据的 JSON Schema（或 Zod）
- Edge Function 规范：入参与出参 Schema、错误码约定
- 前端页面规范：页面事件/状态机（可用 YAML/JSON 描述交互流程）

2. 目录规划（建议）
project-root/
- specs/
  - api.openapi.yaml           # REST/Edge Functions 接口规范
  - schemas/
    - chartConfig.schema.json  # ECharts 配置契约
    - userData.schema.json     # 上传数据契约
  - pages/
    - ChartPage.spec.json      # 页面状态/事件规范

3. 工作流
- 规范编写/更新 → 规范校验（spec-kit lint/validate）→ 代码生成（客户端类型/服务端守卫）→ 实现/联调 → 合约测试（contract tests）→ 发版

4. 生成物落地
- 前端 ArkTS 类型定义：由 JSON Schema/OpenAPI 生成 `.d.ts`/ArkTS 接口
- Edge Function 入参校验：生成 Deno 运行时校验逻辑（如 Ajv）
- 错误码与文案：统一从规范导出常量，避免分散维护

5. CI 集成
- 在 CI 中执行 `spec-kit validate` 与合约测试；规范未通过禁止合入

附：最小示例（片段）

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://example.com/schemas/chartConfig.schema.json",
  "title": "EChartsConfig",
  "type": "object",
  "properties": {
    "title": { "type": "object", "properties": { "text": { "type": "string" } }, "required": ["text"] },
    "series": { "type": "array", "items": { "type": "object", "properties": { "type": { "type": "string" } }, "required": ["type"] } }
  },
  "required": ["series"]
}
```

```yaml
openapi: 3.0.3
info:
  title: AI Chart API
  version: 1.0.0
paths:
  /functions/v1/generate_chart:
    post:
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: './schemas/userData.schema.json'
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                $ref: './schemas/chartConfig.schema.json'
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
```

十二、配置与环境变量

1. 环境区分
- dev / staging / prod 三套变量，严禁在代码中硬编码密钥

2. 变量清单（示例）
- SUPABASE_URL、SUPABASE_ANON_KEY、SUPABASE_SERVICE_ROLE（仅 Edge 使用）
- EDGE_GENERATE_CHART_URL
- DASHSCOPE_API_KEY、DASHSCOPE_API_BASE（可选，默认兼容端点）、QWEN_MODEL
- SENTRY_DSN（可选）

3. 鸿蒙端安全存储
- 使用 `AppScope`/系统安全能力存放可公开的 anon key；服务端密钥仅在 Edge Function 侧

4. 配置管理
- 本地：`.env.local`（不入库）+ `.env.example`
- CI：使用密钥仓库注入；构建产物内仅包含必要公开配置

十三、安全与合规

1. 鉴权与会话
- 全量依赖 Supabase Auth；前端仅持有短期 token，按需刷新

2. 行级访问控制（RLS）
- 对 `charts` 表启用 RLS，策略示例：

```sql
alter table charts enable row level security;
create policy charts_select_own on charts for select
  using (auth.uid() = user_id);
create policy charts_insert_own on charts for insert
  with check (auth.uid() = user_id);
```

3. Storage Bucket 策略
- `datasets` 仅允许文件拥有者读/写；通过签名 URL 分享

4. 输入/输出净化
- 对用户数据与模型输出进行 Schema 校验与大小限制；拒绝超长/二进制混入

5. 速率限制与防滥用
- 在 Edge Function 层基于用户 ID/IP 做速率限制（如 `60 req/min`）

6. 审计与留痕
- 关键操作（生成、导出、分享）写审计表；与日志 Trace ID 关联

十四、性能与离线能力

1. 上传与渲染优化
- 大文件分片/断点续传；CSV 解析在 Worker（或 Edge 预处理）
- ECharts WebView 预加载与资源本地化；按需懒加载组件

2. 缓存策略
- 图表 JSON 与缩略图本地缓存；边缘缓存 Edge 响应（命中后直接返回）

3. 离线支持（可选）
- 最近 N 个图表与数据可离线浏览；在线时增量同步

十五、可观测性与错误处理

1. 日志与追踪
- 前端：结构化日志 + 会话/用户 ID + requestId
- Edge：统一日志格式，记录模型耗时/令牌数/失败率

2. 指标
- 生成成功率、P95 耗时、平均 token 使用量、导出转化率

3. 错误处理
- 统一错误码与用户提示文案；重试与降级（切换简单图表模板）

十六、测试与质量保障

1. 单元测试
- ArkTS 组件与工具；Edge 函数逻辑与 Schema 守卫

2. 集成/合约测试
- 依据 OpenAPI/Schema 的 contract tests，校验入参出参一致性

3. 端到端测试（可选）
- 关键路径：登录→上传→生成→渲染→导出→保存

十七、CI/CD 与发布

1. CI 步骤
- Lint/Format → 规范校验（spec-kit）→ 单测/合约测 → 构建

2. 部署
- 使用 Supabase CLI 部署 Edge Functions 与数据库迁移
- 构建鸿蒙应用包；签名与渠道分发

3. 版本策略
- 后端与前端使用 semver；OpenAPI 变更走 `x-version` 标注

十八、里程碑与验收

里程碑 M1（第1-2周）：项目骨架、ECharts WebView、文件选择与基础渲染
- 验收：可加载静态配置渲染折线图，完成 spec-kit 初版与校验

里程碑 M2（第3-4周）：接入 Supabase Auth/Storage/DB，完成上传与记录
- 验收：登录可用、上传可用、生成记录可查询

里程碑 M3（第5-6周）：Edge Function AI 调用、Schema 校验与速率限制
- 验收：可对中等规模数据生成图表，RLS 生效，速率限制生效

里程碑 M4（第7-8周）：导出、历史页、观测告警与稳定性优化
- 验收：PNG/PDF 导出稳定；SLO 达成（成功率≥99%，P95≤3s）

十九、预算与成本（估算）

- Supabase：免费层起步；按存储/带宽/函数调用量扩展
- AI 模型：以 1K 次/月、每次 1K tokens 估算，成本随模型与上下文长度波动
- 监控：Sentry/Log 服务按量计费

二十、风险与应对

- 模型输出不稳定：加入模板化与后处理校验，失败回退到推荐图表类型
- 数据隐私合规：仅传最小必要数据到模型；提供脱敏选项
- WebView 渲染性能：长列表/超大数据预聚合；限制点数/抽样展示
- 多模型/区域可用性：支持模型/地区切换；网络异常重试与降级

附录：与 Edge Function 的运行时校验示例（Deno + Ajv 片段）

```ts
import { Ajv } from "https://esm.sh/ajv";
import userDataSchema from "./schemas/userData.schema.json" assert { type: "json" };
import chartConfigSchema from "./schemas/chartConfig.schema.json" assert { type: "json" };

const ajv = new Ajv({ allErrors: true });
const validateIn = ajv.compile(userDataSchema);
const validateOut = ajv.compile(chartConfigSchema);

export default Deno.serve(async (req) => {
  const body = await req.json();
  if (!validateIn(body)) return new Response(JSON.stringify({ code: "INVALID_INPUT", errors: validateIn.errors }), { status: 400 });
  // ... 调用模型 ...
  const result = {/* 模型返回 */};
  if (!validateOut(result)) return new Response(JSON.stringify({ code: "INVALID_MODEL_OUTPUT" }), { status: 502 });
  return new Response(JSON.stringify(result), { headers: { "Content-Type": "application/json" } });
});
```

附录：通义千问（DashScope）Edge Function 调用示例（OpenAI 兼容接口，项目默认模型）

环境变量：
- DASHSCOPE_API_KEY（必填）
- DASHSCOPE_API_BASE（可选，默认 `https://dashscope.aliyuncs.com/compatible-mode/v1`）

说明：使用 OpenAI 兼容的 chat completions 接口，`response_format` 设为 `json_object`，并结合上文 Schema 进行二次校验；模型建议 `qwen-plus`（性价比）或 `qwen-max`（效果优先）。

```ts
// /supabase/functions/generate_chart_qwen.ts
import { Ajv } from "https://esm.sh/ajv";
import userDataSchema from "./schemas/userData.schema.json" assert { type: "json" };
import chartConfigSchema from "./schemas/chartConfig.schema.json" assert { type: "json" };

const ajv = new Ajv({ allErrors: true });
const validateIn = ajv.compile(userDataSchema);
const validateOut = ajv.compile(chartConfigSchema);

const API_BASE = Deno.env.get("DASHSCOPE_API_BASE")?.replace(/\/$/, "") ||
  "https://dashscope.aliyuncs.com/compatible-mode/v1";
const API_KEY = Deno.env.get("DASHSCOPE_API_KEY");
const MODEL = Deno.env.get("QWEN_MODEL") || "qwen-plus";

if (!API_KEY) {
  console.error("DASHSCOPE_API_KEY is missing");
}

const systemPrompt = `你是数据可视化专家。依据用户提供的数据（可能是 CSV 解析后的对象、或结构化 JSON），
产出严格符合 ECharts Option 的 JSON；不要输出任何非 JSON 文本。按以下要求：
1) 自动选择合适图表（如 bar/line/pie/scatter），
2) 生成最小必要字段（title、legend、tooltip、xAxis/yAxis、series、dataset/option），
3) 文本请使用简体中文，
4) 若输入信息不足，合理假设并给出可渲染的配置。`;

async function callQwen(messages: Array<{ role: string; content: string }>, signal?: AbortSignal) {
  const body = {
    model: MODEL,
    temperature: 0,
    response_format: { type: "json_object" },
    messages,
  };
  const res = await fetch(`${API_BASE}/chat/completions`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
    signal,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`DashScope error: ${res.status} ${text}`);
  }
  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content;
  if (!content) throw new Error("Empty Qwen response");
  return content;
}

export default Deno.serve(async (req) => {
  const ctrl = new AbortController();
  const timeout = setTimeout(() => ctrl.abort("timeout"), 3000);
  try {
    const body = await req.json();
    if (!validateIn(body)) {
      return new Response(JSON.stringify({ code: "INVALID_INPUT", errors: validateIn.errors }), { status: 400 });
    }
    const userMsg = typeof body === "string" ? body : JSON.stringify(body);
    const content = await callQwen([
      { role: "system", content: systemPrompt },
      { role: "user", content: `请根据以下数据返回 ECharts 配置的 JSON：\n${userMsg}` },
    ], ctrl.signal);

    // 二次校验与降级
    let json: unknown;
    try { json = JSON.parse(content); } catch (_) {
      return new Response(JSON.stringify({ code: "INVALID_JSON_OUTPUT" }), { status: 502 });
    }
    if (!validateOut(json)) {
      // 简单回退模板（示例：折线图）
      const fallback = {
        title: { text: "AI 推荐图表" },
        tooltip: {},
        xAxis: { type: "category" },
        yAxis: { type: "value" },
        series: [{ type: "line", data: [] }],
      };
      return new Response(JSON.stringify(fallback), { headers: { "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify(json), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    const status = e?.message?.includes("timeout") ? 504 : 500;
    return new Response(JSON.stringify({ code: "QWEN_ERROR", message: String(e?.message || e) }), { status });
  } finally {
    clearTimeout(timeout);
  }
});
```