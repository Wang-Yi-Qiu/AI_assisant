# Feature Specification: AI 可视化最小闭环（Qwen 模型）

**Feature Branch**: `001-ai-chart-mvp`  
**Created**: 2025-10-29  
**Status**: Ready  
**Input**: User description: "@pr.md"

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - 登录→上传→生成→渲染→导出（最小闭环） (Priority: P1)

作为登录用户，我可以上传数据（CSV/JSON/文本），点击“生成图表”，在应用中看到可交互的图表，并能导出为 PNG 保存到本地。

**Why this priority**: 直接验证核心价值：输入数据即可得到有效图表并可保存结果。

**Independent Test**: 只实现该故事即可从空白数据到可视化、并完成一次导出，具备演示价值。

**Acceptance Scenarios**:

1. **Given** 用户已登录，**When** 选择一份 CSV 并提交，**Then** 成功生成一张合适类型的图表并显示在页面上。
2. **Given** 图表已显示，**When** 点击“导出 PNG”，**Then** 成功保存图片文件到本地并可在系统相册/文件中查看。

3. **错误处理与鉴权（新增）**：
   - 401：缺失或无效 anon key，提示“登录/配置异常或权限不足”，不崩溃；允许重试。
   - 404：函数路径不存在或未部署，提示“服务暂不可用（函数未找到）”，引导稍后重试或联系支持。
   - 504：云端超时（模型/网络），提示“AI 响应超时，已返回保底模板”，并以回退模板渲染。

> 多设备补充（新增）：
- TV/车机：若文件保存涉及系统能力受限，则以“导出 JSON”替代，或提供“历史复现”路径，显示清晰提示文案；遥控/方向键可完整完成流程
- 可穿戴：导出入口可折叠为菜单，流程≤2步；如不具备保存能力，仅提供“JSON 复制”替代
- 2in1/大屏：横竖屏与窗口变化中保持状态与布局稳定，无截断

---

### User Story 2 - 历史记录浏览与复现 (Priority: P2)

作为登录用户，我可以在历史页查看自己生成过的图表清单，包含标题、类型与时间；我可以点开任意记录，重新查看并渲染对应图表。

**Why this priority**: 满足复看与演示需求，形成基本留存与回访价值。

**Independent Test**: 仅基于历史数据列表与打开详情，即可独立演示，无需依赖导出或再次上传。

**Acceptance Scenarios**:

1. **Given** 已存在至少一条图表记录，**When** 打开历史页，**Then** 可见按时间倒序的图表条目（含标题、类型、时间）。
2. **Given** 历史列表，**When** 点击任一条记录，**Then** 进入详情并正确渲染该记录对应图表。

> 多设备补充（新增）：
- TV/车机：列表项可获得焦点，方向键可遍历，返回键行为正确
- 可穿戴：列表项信息精简，长标题折叠；滚动手势可达

---

### User Story 3 - 高级导出（PDF/JSON）与分享准备 (Priority: P3)

作为登录用户，我可以将当前图表导出为 PDF 与配置 JSON，以便复用或在其他平台分享/归档（分享链接为后续扩展，不在本次范围）。

**Why this priority**: 完善输出形态，提升专业与传播场景的适配性。

**Independent Test**: 不依赖历史页；只要能从图表页面触发导出并得到可用文件，即可独立演示。

**Acceptance Scenarios**:

1. **Given** 图表已显示，**When** 点击“导出 PDF”，**Then** 生成包含当前图表的 PDF 文件并可在系统中打开。
2. **Given** 图表已显示，**When** 点击“导出 JSON”，**Then** 下载包含图表配置的 JSON 文件，内容可被再次用于渲染。

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right edge cases.
-->

- 空数据或格式错误：在提交前识别并给出清晰提示，不进入生成流程。
- 数据量过大：提示用户分批/抽样；保证应用可用性并避免卡顿。
- 模型输出不合规：回退到保底图表模板并提示已采用安全降级。
- 网络异常或超时：提示重试与离线限制，不产生假成功记录。

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: 系统必须支持登录用户上传数据文件或粘贴文本，并在提交前进行基本有效性检查。
- **FR-002**: 系统必须在用户操作下生成一份可被渲染的图表配置，并在应用内展示可交互图表。
- **FR-003**: 系统必须支持将当前图表以 PNG 导出保存到本地。
- **FR-004**: 系统必须在生成图表后保存记录（标题、类型、时间、配置摘要）供历史页展示与复现。
- **FR-005**: 历史页必须按时间倒序展示记录，支持打开任意记录并正确渲染对应图表。
- **FR-006**: 系统应支持将当前图表导出为 PDF 与配置 JSON 文件。
- **FR-007**: 出错时需向用户提供清晰错误提示，并在可能情况下提供安全降级结果；不得产生误导性成功提示。
 - **FR-008（新增）**: 前端调用 Edge Function 时必须发送鉴权头：`Authorization: Bearer <anon key>` 与 `apikey: <anon key>`；URL 通过 `getSupabaseUrl()` 动态拼接。

### Supported Devices & Interaction Differences（新增）
- 设备矩阵：phone, tablet, 2in1, tv, wearable, car, smartVision
- 布局自适应：为 `Index/History/Chart` 页面定义断点与栅格策略；可穿戴采用精简布局与更大触控目标
- 输入方式：
  - 触控（phone/tablet/2in1）
  - 遥控/方向键与返回键（tv/car/smartVision）
  - 精简输入（wearable），减少键入步骤
- 能力可用性与降级：
  - 文件上传：在不支持设备（tv/car/部分 smartVision）隐藏或禁用，提供文本输入或历史复现
  - 导出：若 PNG/PDF 存储受限，提供 JSON 导出或复制文本
  - 窗口与方向：2in1/大屏需支持方向变化与窗口调整

（无关键歧义项需要 [NEEDS CLARIFICATION] 标注）

### Key Entities *(include if feature involves data)*

- **User**: 代表登录用户；关键属性：id、email、createdAt。
- **Dataset**: 代表用户上传或输入的数据；关键属性：id、ownerId、name、createdAt、size。
- **ChartRecord**: 代表一次图表生成结果；关键属性：id、ownerId、title、type、createdAt、chartConfig（或摘要）。

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: 首次使用用户可在3分钟内完成“上传→生成→渲染→导出”闭环。
- **SC-002**: 生成成功率≥99%，多数用户在3秒内看到首张图表。
- **SC-003**: 历史页可在2秒内加载最近10条记录，打开任意记录渲染≤2秒。
- **SC-004**: 至少90%的试用用户能在首次尝试中成功完成主要任务（生成并导出）。
 - **SC-005（新增）**: 针对 401/404/504 三类错误，客户端均给出预期中文提示且不中断主流程（504 使用回退模板渲染）。

### Cross-Device DoD（新增）
- 按 `plan.md` 测试矩阵完成闭环；焦点巡检无“无焦点可达”缺陷；小屏无溢出；窗口变化无截断；不支持能力提供替代方案且文案清晰。

## 配置与环境变量 *(mandatory)*

为满足宪章的“密钥零硬编码、分环境注入”要求，本特性涉及的最小变量清单如下（详见 `pr.md` 的“配置与环境变量”）：

- SUPABASE_URL（前端可公开）
- SUPABASE_ANON_KEY（前端可公开，短期）
- EDGE_GENERATE_CHART_URL（前端可公开，不含密钥）
  （如采用别名路径可保留；默认通过 `getSupabaseUrl()` + `/functions/v1/generate_chart_qwen` 拼接）
- DASHSCOPE_API_KEY（仅 Edge 使用，前端禁止持有）
- DASHSCOPE_API_BASE（可选，默认兼容端点）
- QWEN_MODEL（可选，默认 `qwen-plus`）

要求：
- 前端不保存服务端密钥；密钥仅在 Edge Function 注入
- 不同环境使用不同变量组；构建产物仅包含必要公开配置
- 合规与审计：变更需在 PR 中说明影响并通过 `spec-kit validate`

### 安全与鉴权（新增）
- Edge Functions 默认开启 `verify_jwt=true`。
- 前端仅持有 anon key，并在请求中同时设置 `Authorization` 与 `apikey`；服务端密钥只在 Edge。

## Clarifications Needed（新增）
- TV 与可穿戴是否必须支持导出 PNG？若否，是否以 JSON 替代即可达标？
- 车机联网场景是否有限制（蜂窝/蓝牙共享/仅 Wi-Fi），是否影响 Edge 调用？
- smartVision 设备是否只读展示，是否需要编辑/输入能力？
 - 文件上传在 tv/car/smartVision 的支持策略是否统一为“隐藏+替代路径”？
