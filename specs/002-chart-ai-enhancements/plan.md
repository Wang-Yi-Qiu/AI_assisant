# Implementation Plan: 图表增强与AI洞察功能

**Branch**: `002-chart-ai-enhancements` | **Date**: 2025-01-28 | **Spec**: `specs/002-chart-ai-enhancements/spec.md`
**Input**: Feature specification from `/specs/002-chart-ai-enhancements/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command.

## Summary

- 目标：在现有图表生成功能基础上，增加样本数据快速体验、图表重新生成、类型切换、AI洞察等增强功能，提升用户体验和控制感。
- 方法：前端 ArkTS 本地实现样本数据和类型切换；复用现有 Edge Function 实现重新生成；新增 AI 洞察 Edge Function；遵循规范先行原则定义 Schema。

## Multi-Device Compatibility

- 支持设备矩阵：phone, tablet, 2in1, tv, wearable, car, smartVision
- 适配策略：
- 布局断点：按钮布局按设备类型调整，TV/车机支持焦点导航（焦点导航顺序从左到右、从上到下Tab键顺序，焦点指示器提供清晰视觉反馈如高亮边框/阴影效果），可穿戴精简按钮数量
- 交互方式：触控优先；TV/车机支持方向键（上下左右）移动焦点、确认键（Enter/OK）触发操作、返回键（Back）返回上一级；可穿戴支持手势操作，关键功能≤2步完成
  - 能力降级：AI洞察服务不可用时显示友好提示，不影响主要功能
  - 性能优化：样本数据本地加载，类型切换即时响应，AI洞察异步加载

### Risks

- AI洞察服务超时或失败时的降级处理需要完善的错误处理机制
- 图表类型切换时数据兼容性校验的边界情况处理
- 多设备适配下按钮布局和交互的一致性保证
- 样本数据在不同设备上的加载和显示性能

### Test Matrix

功能/设备 | phone | tablet | 2in1 | tv | wearable | car | smartVision
:--|:--:|:--:|:--:|:--:|:--:|:--:|:--:
样本数据加载 | 支持 | 支持 | 支持 | 支持 | 支持 | 支持 | 支持
图表重新生成 | 支持 | 支持 | 支持 | 支持 | 支持 | 支持 | 支持
图表类型切换 | 支持 | 支持 | 支持 | 支持 | 支持 | 支持 | 支持
图表AI洞察 | 支持 | 支持 | 支持 | 支持（降级） | 支持（降级） | 支持（降级） | 支持
专注AI洞察 | 支持 | 支持 | 支持 | 支持（降级） | 支持（降级） | 支持（降级） | 支持
焦点/返回 | 触控 | 触控 | 触控/键盘 | 遥控/方向键 | 触控（手势） | 旋钮/方向键 | 遥控/触控

### Definition of Done（多设备）

- 覆盖上述矩阵中"支持/降级"标注的最低能力，且：
  - 各设备完成"样本数据→生成→重新生成→类型切换→AI洞察"闭环
  - TV/车机全路径可达（无"无焦点可达"状态），返回键行为符合预期
  - 可穿戴页面无溢出，关键任务≤2步完成；2in1 横竖屏与窗口变化无截断
  - AI洞察功能在服务不可用时优雅降级，显示友好提示
  - 性能门槛：样本数据加载≤1s；类型切换≤500ms；AI洞察生成≤5s（超时降级）

## Technical Context

**Language/Version**: ArkTS（HarmonyOS）; Deno (Supabase Edge)  
**Primary Dependencies**: ECharts（WebView）、Supabase SDK、DashScope 兼容接口（Qwen）、Ajv（Schema 校验）  
**Storage**: 本地资源文件（样本数据）、Supabase PostgreSQL（可选：洞察缓存）  
**Testing**: 前端使用 Hypium/hamock 做最小单测；Edge 使用合约测试（基于 OpenAPI/Schema 的请求-响应校验）  
**Target Platform**: HarmonyOS（DevEco Studio） + Supabase（Edge Functions）  
**Project Type**: multi-device app + serverless edge  
**Performance Goals**: 样本数据加载≤1s；重新生成 P95 ≤ 3s；类型切换≤500ms；AI洞察生成≤5s  
**Constraints**: 密钥零硬编码；RLS 开启；输入/输出均需 Schema 校验；速率限制与降级策略；Edge Functions 默认 `verify_jwt=true`  
**Scale/Scope**: 样本数据本地存储（KB级）；AI洞察响应文本（KB级）；单用户并发场景

**Unknowns/NEEDS CLARIFICATION**:
1. AI洞察 Edge Function 的具体实现方式（复用现有函数 vs 新建函数）
2. 样本数据的存储位置和格式（rawfile vs 代码内嵌）
3. 图表类型切换的数据兼容性校验规则
4. AI洞察的缓存策略（是否需要持久化存储）

## Constitution Check

- **规范先行**：OpenAPI + JSON Schema 必须存在并通过 `spec-kit validate`（Gate）
  - ✅ 需要定义 `insightSchema.json` 用于AI洞察响应格式
  - ✅ 需要更新 OpenAPI 定义新增洞察相关端点
- **云端优先**：仅使用 Supabase 能力；不得引入自建后端（无审批不得例外）（Gate）
  - ✅ 样本数据本地存储，不占用云端资源
  - ✅ AI洞察使用 Supabase Edge Function
- **安全与合规**：密钥仅服务端；RLS 与 Storage 策略生效；输入/输出 Schema 校验（Gate）
  - ✅ AI洞察服务端调用，前端不暴露密钥
  - ✅ 洞察数据遵循 RLS 策略（如需要持久化）
- **可观测性与质量**：结构化日志与统一错误码；关键路径最小测试覆盖（Gate）
  - ✅ 新增功能需要测试覆盖
- **性能与降级**：严格超时与回退模板；缓存策略（Gate）
  - ✅ AI洞察5秒超时，超时显示降级提示
  - ✅ 样本数据本地加载，无网络依赖
- **模型策略**：默认 Qwen，response_format=json_object，temperature=0；超时与 QWEN_ERROR（Gate）
  - ✅ AI洞察复用 Qwen 模型，遵循相同策略

### Cross-Device Adaptation Baseline

- 断点：按小屏/中屏/大屏与窗口宽度定义布局与字号阶梯
- 密度：大屏增加信息密度；可穿戴提升可读性与点击目标
- 输入法：触控/键盘/遥控/旋钮差异处理；统一返回逻辑
- 字体缩放：适配系统字体倍率；不出现截断
- 方向/旋转：支持横竖屏与窗口化变化，状态保持

结论：以上门禁均可在本特性范围内满足。样本数据本地化实现简单高效；AI洞察复用现有架构；类型切换纯前端实现，性能可控。

## Project Structure

### Documentation (this feature)

```text
specs/002-chart-ai-enhancements/
├── plan.md              # This file (/speckit.plan output)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── openapi.yaml
│   └── schemas/
│       ├── insightSchema.json
│       └── sampleDataset.schema.json
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
entry/src/main/ets/
├── pages/
│   ├── HomePage.ets          # 新增：样本数据按钮
│   ├── ChartPage.ets         # 新增：重新生成、类型切换、AI洞察UI
│   └── HistoryPage.ets       # 无变更
└── utils/
    ├── sampleDataManager.ets # 新增：样本数据管理
    ├── chartTypeSwitcher.ets # 新增：图表类型切换逻辑
    └── aiService.ets         # 扩展：AI洞察调用

entry/src/main/resources/
└── rawfile/
    └── sample-data/          # 新增：样本数据文件
        ├── sales-monthly.json      # 月度销售数据（适合折线图和柱状图）
        ├── users-growth.json       # 用户增长数据（适合折线图和柱状图）
        ├── products-category.json  # 产品分类占比数据（适合饼图）
        ├── sales-profit.json      # 销售与利润关系数据（适合散点图）
        └── timeseries-daily.json  # 时间序列数据（适合折线图）

supabase/functions/
├── generate_chart_qwen/      # 现有：复用用于重新生成
└── generate_insight/         # 新增：AI洞察服务
    └── index.ts
```

**Structure Decision**: 
- 样本数据本地存储（rawfile），快速加载，无网络依赖
- 图表类型切换纯前端实现，即时响应
- AI洞察新增独立 Edge Function，便于扩展和维护
- 复用现有架构和工具，符合最小变更原则

### 配置与环境

- 前端配置读取：`getSupabaseUrl()`、`getSupabaseAnonKey()` 从 AppScope/环境注入读取
- URL 规范：前端以 `getSupabaseUrl()` 动态拼接 `.../functions/v1/generate_insight`
- 多环境：支持 dev/staging/prod 三套变量与切换流程

## Implementation Alignment — Multi-Device

需要修改/校验的代码点（将作为实施对齐清单）：

- `entry/src/main/ets/pages/HomePage.ets`
  - 新增"使用样本数据"按钮，支持多设备布局和交互
  - TV/车机支持焦点导航（焦点导航顺序从左到右、从上到下Tab键顺序，焦点指示器提供清晰视觉反馈如高亮边框/阴影效果，方向键移动焦点、确认键触发操作、返回键返回上一级），可穿戴精简按钮
- `entry/src/main/ets/pages/ChartPage.ets`
  - 新增"重新生成"、"更改类型"按钮和"AI洞察"区域
  - 按钮布局适配多设备，TV/车机支持焦点导航（焦点导航顺序从左到右、从上到下Tab键顺序，焦点指示器提供清晰视觉反馈如高亮边框/阴影效果，方向键移动焦点、确认键触发操作、返回键返回上一级）
  - AI洞察区域支持折叠/展开，可穿戴设备精简显示
  - 重新生成功能实现详细加载状态（视觉指示器、状态提示、用户反馈、完成反馈）
- `entry/src/main/ets/utils/sampleDataManager.ets`（新增）
  - 样本数据加载逻辑，支持多设备
  - 错误处理和降级策略
- `entry/src/main/ets/utils/chartTypeSwitcher.ets`（新增）
  - 图表类型切换逻辑，数据兼容性校验
  - 支持常用类型：line、bar、pie、scatter
- `entry/src/main/ets/utils/aiService.ets`
  - 扩展AI洞察调用方法
  - 超时处理和降级策略
- `supabase/functions/generate_insight/index.ts`（新增）
  - AI洞察生成逻辑，复用 Qwen 模型
  - Schema 校验和错误处理

## Complexity Tracking

> 当前无违反宪章的复杂度项。样本数据本地化实现简单；类型切换纯前端实现；AI洞察复用现有架构。所有功能遵循规范先行、云端优先、安全合规原则。

