# Implementation Plan: AI 可视化最小闭环（Qwen 模型）

**Branch**: `001-ai-chart-mvp` | **Date**: 2025-10-29 | **Spec**: `specs/001-ai-chart-mvp/spec.md`
**Input**: Feature specification from `/specs/001-ai-chart-mvp/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

- 目标：完成“登录→上传→Qwen 生成→渲染→导出”的最小闭环（PNG），并提供历史记录与复现；扩展 PDF/JSON 导出。
- 方法：前端 ArkTS + WebView ECharts；云端 Supabase（Auth/Storage/DB/Edge）；Edge 调用 Qwen 兼容接口，输出经 Schema 校验。

## Technical Context

**Language/Version**: ArkTS（HarmonyOS）; Deno (Supabase Edge)  
**Primary Dependencies**: ECharts（WebView）、Supabase SDK、DashScope 兼容接口（Qwen）、Ajv（Schema 校验）  
**Storage**: Supabase Storage（文件）、PostgreSQL（charts 表）  
**Testing**: 前端使用 Hypium/hamock 做最小单测；Edge 使用合约测试（基于 OpenAPI/Schema 的请求-响应校验），覆盖成功/降级/无效输入三类路径。  
**Target Platform**: HarmonyOS（DevEco Studio） + Supabase（Edge Functions）  
**Project Type**: mobile + serverless edge  
**Performance Goals**: 生成路径 P95 ≤ 3s；历史页最近 10 条加载 ≤ 2s；渲染 ≤ 2s  
**Constraints**: 密钥零硬编码；RLS 开启；输入/输出均需 Schema 校验；速率限制与降级策略  
**Scale/Scope**: 单用户百 KB～数 MB 数据；并发场景以个人/小团队为主

## Constitution Check

- 规范先行：OpenAPI + JSON Schema 必须存在并通过 `spec-kit validate`（Gate）
- 云端优先：仅使用 Supabase 能力；不得引入自建后端（无审批不得例外）（Gate）
- 安全与合规：密钥仅服务端；RLS 与 Storage 策略生效；输入/输出 Schema 校验（Gate）
- 可观测性与质量：结构化日志与统一错误码；关键路径最小测试覆盖（Gate）
- 性能与降级：严格超时与回退模板；缓存策略（Gate）
- 模型策略：默认 Qwen，response_format=json_object，temperature=0；超时与 QWEN_ERROR（Gate）

结论：以上门禁均可在本特性范围内满足。测试与工具链已明确选型；细化用例将随 tasks.md 的 QA 任务推进。

## Project Structure

### Documentation (this feature)

```text
specs/001-ai-chart-mvp/
├── plan.md              # This file (/speckit.plan output)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
entry/src/main/ets/
├── pages/
│  ├── LoginPage.ets
│  ├── HomePage.ets
│  ├── ChartPage.ets
│  └── HistoryPage.ets
└── utils/
   ├── supabaseClient.ets
   ├── aiService.ets
   └── fileAccess.ets

supabase/functions/
└── generate_chart_qwen.ts
```

**Structure Decision**: 移动端（ArkTS）+ Edge Function（Deno）；前端轻，云端优先，符合宪章“最小后端”原则。

## Complexity Tracking

> 当前无违反宪章的复杂度项；如需引入自建后端或额外队列，将提交单独豁免说明。
