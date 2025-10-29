# Phase 0 Research — AI 可视化最小闭环（Qwen 模型）

## Unknowns (from Technical Context)

1) 前端与 Edge 的测试框架选型（NEEDS CLARIFICATION）

## Tasks

- Research: 适配 HarmonyOS ArkTS 的可行测试策略（组件/交互最小覆盖）
- Research: Supabase Edge（Deno）函数的单测/合约测最佳实践

## Findings

### 前端测试（HarmonyOS/ArkTS）
- Decision: 采用 Hypium（已有依赖）进行基础单测；关键路径使用手动验收步骤在 quickstart 中固化。
- Rationale: 与鸿蒙生态兼容、成本最低；端到端 UI 自动化暂不纳入本阶段。
- Alternatives: 第三方 UI 自动化（复杂度与稳定性成本过高，推迟）。

### Edge 函数测试（Deno/Supabase）
- Decision: 使用 Deno 原生测试（deno test）对入/出参校验与降级逻辑做单元测试；合约测试由 OpenAPI/Schema 驱动（CI 调用 spec-kit）。
- Rationale: 无额外依赖、运行简单；与 Schema 校验配合保证契约稳定。
- Alternatives: 引入完整集成环境（部署后回测），阶段内收益不高，后续再加。

## Resolutions

- Testing: 前端采用 Hypium；Edge 采用 Deno 原生测试与合约测试（CI）。

## Impact

- Constitution Check 无阻塞；Phase 1 可继续。

## Cross-Device Design References（新增）

- TV/车机：焦点与遥控导航规范、返回键行为、焦点环可见性与顺序策略
- 可穿戴：圆屏/小屏布局栅格、字号与触控目标放大、信息精简策略
- 大屏/展示屏（smartVision）：高信息密度栅格、对比度与留白、远距离可读性
- 2in1/窗口化：横竖屏与动态窗口监听，断点切换时的动画与状态保持
