# Implementation Plan: AI 可视化最小闭环（Qwen 模型）

**Branch**: `001-ai-chart-mvp` | **Date**: 2025-10-29 | **Spec**: `specs/001-ai-chart-mvp/spec.md`
**Input**: Feature specification from `/specs/001-ai-chart-mvp/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

- 目标：完成“登录→上传→Qwen 生成→渲染→导出”的最小闭环（PNG），并提供历史记录与复现；扩展 PDF/JSON 导出。
- 方法：前端 ArkTS + WebView ECharts；云端 Supabase（Auth/Storage/DB/Edge）；Edge 调用 Qwen 兼容接口，输出经 Schema 校验。

## Multi-Device Compatibility (新增)

- 支持设备矩阵：phone, tablet, 2in1, tv, wearable, car, smartVision
- 适配策略：
  - 布局断点与密度：按设备与窗口尺寸切换栅格/间距/字号，避免溢出与空白；大屏信息密度提升，wearable 精简要素
  - 输入与导航：触控优先；TV/车机支持方向键/旋钮/返回键可达性与焦点顺序；可穿戴减少键入步骤
  - 能力与降级：不支持文件选择器（TV/车机/部分 smartVision）时隐藏或禁用“上传文件”，提供“文本输入/历史复现”替代路径
  - 方向与窗口：2in1/大屏支持横竖屏与窗口动态变化，保证布局稳定与无截断

### Risks（新增）
- TV/车机焦点导航复杂度与一致性风险（需要可达性巡检用例）
- 可穿戴屏幕极小导致的交互步骤/信息密度冲突（需裁剪方案）
- WebView/ECharts 在大屏/智能屏的性能边界（首帧渲染与内存）
- 文件选择器在部分设备不可用引发流程中断（需清晰降级与文案）

### Test Matrix（新增）

功能/设备 | phone | tablet | 2in1 | tv | wearable | car | smartVision
:--|:--:|:--:|:--:|:--:|:--:|:--:|:--:
文本输入 | 支持 | 支持 | 支持 | 支持（遥控输入） | 支持（简化） | 支持（遥控） | 支持
文件上传 | 支持 | 支持 | 支持 | 降级（隐藏/禁用） | 不适用/降级 | 降级 | 视设备
生成图表 | 支持 | 支持 | 支持 | 支持 | 支持 | 支持 | 支持
渲染展示 | 支持 | 支持（多栅格） | 支持（窗口化） | 支持（大屏密度） | 支持（精简） | 支持 | 支持（展示屏）
导出 PNG | 支持 | 支持 | 支持 | 视设备（可能降级 JSON） | 视设备（可隐藏） | 视设备 | 视设备
导出 JSON | 支持 | 支持 | 支持 | 支持（替代方案） | 支持 | 支持 | 支持
历史复现 | 支持 | 支持 | 支持 | 支持 | 支持 | 支持 | 支持
焦点/返回 | 触控 | 触控 | 触控/键盘 | 遥控/方向键 | 触控（长按/手势） | 旋钮/方向键 | 遥控/触控

### Definition of Done（新增，多设备）
- 覆盖上述矩阵中“支持/降级”标注的最低能力，且：
  - 各设备完成“输入（或替代）→生成→渲染→导出（或替代）→历史复现”闭环
  - TV/车机全路径可达（无“无焦点可达”状态），返回键行为符合预期
  - 可穿戴页面无溢出，关键任务≤2步完成；2in1 横竖屏与窗口变化无截断/严重抖动
  - 不支持文件上传的设备提供清晰文案与替代路径
  - 性能门槛：P95 首次可见渲染 ≤ 大屏 3.5s / 其他 3s；交互无明显掉帧

## Technical Context

**Language/Version**: ArkTS（HarmonyOS）; Deno (Supabase Edge)  
**Primary Dependencies**: ECharts（WebView）、Supabase SDK、DashScope 兼容接口（Qwen）、Ajv（Schema 校验）  
**Storage**: Supabase Storage（文件）、PostgreSQL（charts 表）  
**Testing**: 前端使用 Hypium/hamock 做最小单测；Edge 使用合约测试（基于 OpenAPI/Schema 的请求-响应校验），覆盖成功/降级/无效输入三类路径。  
**Target Platform**: HarmonyOS（DevEco Studio） + Supabase（Edge Functions）  
**Project Type**: multi-device app + serverless edge  
**Performance Goals**: 生成路径 P95 ≤ 3s；历史页最近 10 条加载 ≤ 2s；渲染 ≤ 2s  
**Constraints**: 密钥零硬编码；RLS 开启；输入/输出均需 Schema 校验；速率限制与降级策略；Edge Functions 默认 `verify_jwt=true`，前端以 `Authorization: Bearer <anon key>` 与 `apikey` 调用。  
**Scale/Scope**: 单用户百 KB～数 MB 数据；并发场景以个人/小团队为主

## Constitution Check

- 规范先行：OpenAPI + JSON Schema 必须存在并通过 `spec-kit validate`（Gate）
- 云端优先：仅使用 Supabase 能力；不得引入自建后端（无审批不得例外）（Gate）
- 安全与合规：密钥仅服务端；RLS 与 Storage 策略生效；输入/输出 Schema 校验（Gate）
- 可观测性与质量：结构化日志与统一错误码；关键路径最小测试覆盖（Gate）
- 性能与降级：严格超时与回退模板；缓存策略（Gate）
- 模型策略：默认 Qwen，response_format=json_object，temperature=0；超时与 QWEN_ERROR（Gate）

### Cross-Device Adaptation Baseline（新增）
- 断点：按小屏/中屏/大屏与窗口宽度定义布局与字号阶梯
- 密度：大屏增加信息密度；可穿戴提升可读性与点击目标
- 输入法：触控/键盘/遥控/旋钮差异处理；统一返回逻辑
- 字体缩放：适配系统字体倍率；不出现截断
- 方向/旋转：支持横竖屏与窗口化变化，状态保持

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

### 配置与环境（新增）
- 前端配置读取：`getSupabaseUrl()`、`getSupabaseAnonKey()` 从 AppScope/环境注入读取，不在代码中硬编码。
- URL 规范：前端以 `getSupabaseUrl()` 动态拼接 `.../functions/v1/generate_chart_qwen`。
- 多环境：支持 dev/staging/prod 三套变量与切换流程。

## Implementation Alignment — Multi-Device（新增）

需要修改/校验的代码点（将作为实施对齐清单）：
- `entry/src/main/ets/pages/Index.ets`
  - 固定高度/字号/间距：为 wearable/大屏引入断点样式与密度阶梯
  - “上传文件”在 TV/车机降级隐藏/禁用并给出替代路径文案
- `entry/src/main/ets/pages/HistoryPage.ets`
  - 列表项焦点态与方向键遍历顺序；大屏多列/密度提升（可后续）
- `entry/src/main/ets/pages/ChartPage.ets`
  - 顶栏 56 高与按钮分布在小屏/大屏适配；导出入口支持折叠菜单（wearable）
  - WebView/ECharts 集成时的资源与性能约束记录
- `entry/src/main/ets/utils/aiService.ets`
  - 与设备无耦合；在带宽/存储受限设备上允许仅保存记录或仅导出 JSON 的降级说明
- `entry/src/main/ets/utils/supabaseClient.ets`
  - 可选写入 `deviceType` 字段（若业务启用）

## Complexity Tracking

> 当前无违反宪章的复杂度项；如需引入自建后端或额外队列，将提交单独豁免说明。
