# Tasks: AI 可视化最小闭环（Qwen 模型）

**Input**: Design documents from `/specs/001-ai-chart-mvp/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

## Path Conventions

- Mobile app (HarmonyOS): `entry/src/main/ets/`
- Edge Functions: `supabase/functions/`
- Specs: `specs/001-ai-chart-mvp/`

---

## Phase 1: Setup (Shared Infrastructure)

- [X] T001 创建 Edge 函数目录与占位文件 supabase/functions/generate_chart_qwen.ts
- [X] T002 创建前端工具目录 entry/src/main/ets/utils/ 并添加占位文件
- [X] T003 [P] 在 specs/001-ai-chart-mvp/contracts/ 补充/核对 openapi.yaml 与 schemas/

---

## Phase 2: Foundational (Blocking Prerequisites)

- [X] T004 配置 Supabase 客户端 entry/src/main/ets/utils/supabaseClient.ets（读取环境配置）
- [X] T005 [P] 配置 AI 调用封装 entry/src/main/ets/utils/aiService.ets（指向 Edge 函数 URL）
- [X] T006 [P] 配置文件访问封装 entry/src/main/ets/utils/fileAccess.ets（保存 PNG/PDF/JSON）
- [X] T007 在 supabase/functions/generate_chart_qwen.ts 实现入/出参 Schema 校验与 Qwen 调用骨架
- [X] T008 配置 contracts/schemas 校验流程（spec-kit validate 占位脚本说明） specs/001-ai-chart-mvp/contracts/

---

## Phase 3: User Story 1 - 登录→上传→生成→渲染→导出（最小闭环） (Priority: P1)

**Goal**: 通过上传/输入数据完成生成并渲染图表，支持导出 PNG。
**Independent Test**: 从“登录→上传→生成→渲染→导出”全流程可独立演示。

### Implementation for User Story 1

- [X] T009 [P] [US1] 创建首页页面骨架 entry/src/main/ets/pages/HomePage.ets（上传/输入 UI 与触发按钮）
- [X] T010 [P] [US1] 创建图表页骨架 entry/src/main/ets/pages/ChartPage.ets（WebView 容器与桥接）
- [X] T011 [US1] 在 aiService.ets 增加 generateChart(data) 方法 entry/src/main/ets/utils/aiService.ets
- [X] T012 [US1] 在 ChartPage.ets 接收 JSON 并 setOption 渲染 entry/src/main/ets/pages/ChartPage.ets
- [X] T013 [US1] 在 fileAccess.ets 实现导出 PNG entry/src/main/ets/utils/fileAccess.ets
- [X] T014 [US1] 将生成结果写入记录（本地暂存或接口占位） entry/src/main/ets/utils/aiService.ets

### Edge Function for User Story 1

- [X] T015 [P] [US1] 校验入参（userData.schema.json） supabase/functions/generate_chart_qwen.ts
- [X] T016 [P] [US1] 调用 Qwen 兼容接口并设 response_format=json_object supabase/functions/generate_chart_qwen.ts
- [X] T017 [US1] 校验输出（chartConfig.schema.json），失败回退模板 supabase/functions/generate_chart_qwen.ts

---

## Phase 4: User Story 2 - 历史记录浏览与复现 (Priority: P2)

**Goal**: 历史页列表展示与点开复现渲染。
**Independent Test**: 单独打开历史页并复现任一记录，无需再次上传。

### Implementation for User Story 2

- [X] T018 [P] [US2] 创建历史页骨架 entry/src/main/ets/pages/HistoryPage.ets（列表与点击事件）
- [X] T019 [P] [US2] 在 supabaseClient.ets 增加 charts 表访问封装 entry/src/main/ets/utils/supabaseClient.ets
- [X] T020 [US2] 列表倒序读取记录并展示标题/类型/时间 entry/src/main/ets/pages/HistoryPage.ets
- [X] T021 [US2] 点击记录进入 ChartPage 并按记录配置渲染 entry/src/main/ets/pages/ChartPage.ets

### Edge Function/Data for User Story 2

- [X] T022 [P] [US2] 定义/确认 charts 表字段与 RLS 策略 specs/001-ai-chart-mvp/data-model.md

---

## Phase 5: User Story 3 - 高级导出（PDF/JSON）与分享准备 (Priority: P3)

**Goal**: 将图表导出 PDF 与配置 JSON。
**Independent Test**: 不依赖历史页；从图表页直接导出 PDF/JSON。

### Implementation for User Story 3

- [X] T023 [P] [US3] 在 fileAccess.ets 增加导出 PDF entry/src/main/ets/utils/fileAccess.ets
- [X] T024 [P] [US3] 在 ChartPage.ets 增加导出 JSON 入口 entry/src/main/ets/pages/ChartPage.ets
- [X] T025 [US3] 在 aiService.ets 增加获取当前配置 JSON 能力 entry/src/main/ets/utils/aiService.ets

---

## Phase N: Polish & Cross-Cutting Concerns

- [X] T026 [P] 文案与错误提示统一（中文） entry/src/main/ets/
- [X] T027 性能优化（预加载 WebView、缓存缩略图策略说明） entry/src/main/ets/pages/ChartPage.ets
- [X] T028 观测与日志点位（requestId、错误码） supabase/functions/generate_chart_qwen.ts
- [X] T029 安全自查（密钥不在前端、RLS/Storage 策略复核） specs/001-ai-chart-mvp/
- [X] T030 更新 quickstart.md 与 pr.md 相关片段 specs/001-ai-chart-mvp/quickstart.md

### QA & Validation (Post-MVP)

- [X] T031 前端最小单测（Hypium/hamock）：
  - HomePage 输入解析（JSON/CSV/txt）与异常提示
  - ChartPage 配置校验与空配置报错
  - entry/src/main/ets/

- [X] T032 Edge 合约测试（基于 OpenAPI/Schema）：
  - 成功返回（有效输入）
  - 安全降级（INVALID_MODEL_OUTPUT → 回退模板）
  - 无效输入（INVALID_INPUT）
  - supabase/functions/generate_chart_qwen.ts

- [X] T033 性能与观测验证：
  - 采集生成路径 P95、历史页加载 P95 指标
  - 校验日志包含 requestId、错误码与耗时
  - pr.md/quickstart.md 更新“度量方法”说明

---

## Dependencies & Execution Order

### Phase Dependencies
- Setup → Foundational → US1 → US2 → US3 → Polish

### User Story Dependencies
- US1 无外部依赖；US2 依赖记录写入能力；US3 依赖 US1 的渲染已完成

### Parallel Opportunities
- T003、T005、T006、T009、T010、T015、T016、T018、T019、T022、T023、T024 可并行（不同文件互不依赖）

## Implementation Strategy
- MVP：完成 US1 后即可演示与发布内测
- 迭代：US2 → US3，逐步增强导出与留存能力
