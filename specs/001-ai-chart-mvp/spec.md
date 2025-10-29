# Feature Specification: AI 可视化最小闭环（Qwen 模型）

**Feature Branch**: `001-ai-chart-mvp`  
**Created**: 2025-10-29  
**Status**: Draft  
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

---

### User Story 2 - 历史记录浏览与复现 (Priority: P2)

作为登录用户，我可以在历史页查看自己生成过的图表清单，包含标题、类型与时间；我可以点开任意记录，重新查看并渲染对应图表。

**Why this priority**: 满足复看与演示需求，形成基本留存与回访价值。

**Independent Test**: 仅基于历史数据列表与打开详情，即可独立演示，无需依赖导出或再次上传。

**Acceptance Scenarios**:

1. **Given** 已存在至少一条图表记录，**When** 打开历史页，**Then** 可见按时间倒序的图表条目（含标题、类型、时间）。
2. **Given** 历史列表，**When** 点击任一条记录，**Then** 进入详情并正确渲染该记录对应图表。

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
