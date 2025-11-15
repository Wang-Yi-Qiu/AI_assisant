# Feature Specification: 图表增强与AI洞察功能

**Feature Branch**: `002-chart-ai-enhancements`  
**Created**: 2025-01-28  
**Status**: Draft  
**Input**: User description: "@pr.md"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 样本数据快速体验 (Priority: P1)

作为新用户，我可以点击"使用样本数据"按钮，一键加载预设的示例数据集，快速体验图表生成功能，无需手动输入或上传文件。

**Why this priority**: 降低新用户使用门槛，提供快速上手体验，展示应用核心价值。

**Independent Test**: 仅实现该功能即可让用户通过一次点击完成数据加载和图表生成，具备独立演示价值。

**Acceptance Scenarios**:

1. **Given** 用户在首页，**When** 点击"使用样本数据"按钮，**Then** 输入框自动填充预设的示例数据（JSON或CSV格式）。
2. **Given** 样本数据已加载到输入框，**When** 用户点击"生成图表"，**Then** 系统成功生成并显示示例图表。
3. **Given** 用户在不同设备上，**When** 点击"使用样本数据"，**Then** 所有支持的设备类型都能正常加载和显示样本数据。

---

### User Story 2 - 图表重新生成 (Priority: P1)

作为用户，我可以对当前显示的图表点击"重新生成"按钮，基于相同数据让AI重新生成不同风格的图表配置，获得更多可视化选择。

**Why this priority**: 提供用户对图表生成结果的控制权，满足不同场景下的可视化需求。

**Independent Test**: 仅实现该功能即可让用户在不改变数据的情况下获得新的图表配置，具备独立价值。

**Acceptance Scenarios**:

1. **Given** 图表页面已显示一个图表，**When** 用户点击"重新生成"按钮，**Then** 系统基于当前数据重新调用AI生成新的图表配置并更新显示。
2. **Given** 重新生成过程中，**When** AI服务响应，**Then** 显示加载状态，完成后平滑切换到新图表。
3. **Given** 重新生成失败或超时，**When** 系统检测到错误，**Then** 显示友好错误提示，保留原图表显示。

---

### User Story 3 - 图表类型切换 (Priority: P2)

作为用户，我可以点击"更改类型"按钮，手动切换当前图表的类型（如折线图、柱状图、饼图等），快速尝试不同的可视化方式。

**Why this priority**: 提供用户对图表类型的直接控制，无需重新生成即可快速切换可视化方式。

**Independent Test**: 仅实现该功能即可让用户在不重新调用AI的情况下切换图表类型，具备独立价值。

**Acceptance Scenarios**:

1. **Given** 图表页面显示一个折线图，**When** 用户点击"更改类型"并选择"柱状图"，**Then** 图表立即切换为柱状图显示，数据保持不变。
2. **Given** 用户选择图表类型，**When** 系统切换类型，**Then** 图表配置正确更新，图表平滑过渡显示。
3. **Given** 当前数据不适合某种图表类型，**When** 用户尝试切换，**Then** 系统提示该类型不适用或自动选择最合适的类型。

---

### User Story 4 - 图表数据AI洞察 (Priority: P2)

作为用户，我可以在图表预览页面查看"AI 洞察"部分，了解AI对当前图表数据的智能分析和建议，帮助我更好地理解数据趋势和关键信息。

**Why this priority**: 增强用户对数据的理解，提供智能化的数据分析能力，提升应用价值。

**Independent Test**: 仅实现该功能即可让用户获得数据洞察，具备独立价值。

**Acceptance Scenarios**:

1. **Given** 图表页面显示一个图表，**When** 用户查看"AI 洞察"部分，**Then** 显示AI生成的数据分析文本，包括趋势、关键点、建议等。
2. **Given** 用户首次查看洞察，**When** 系统调用AI服务，**Then** 显示加载状态，完成后展示洞察内容。
3. **Given** AI洞察生成失败，**When** 系统检测到错误，**Then** 显示友好提示，不影响图表正常显示。

---

### User Story 5 - 专注数据AI洞察 (Priority: P3)

作为用户，我可以在专注进度统计页面点击"AI 洞察"按钮，获得基于我的专注时间数据的智能分析报告和建议，帮助我优化工作习惯。

**Why this priority**: 为专注管理功能提供智能化分析能力，提升用户体验和价值。

**Independent Test**: 仅实现该功能即可让用户获得专注数据分析，具备独立价值。

**Acceptance Scenarios**:

1. **Given** 用户在专注进度统计页面，**When** 点击"总专注时间"部分的"AI 洞察"按钮，**Then** 显示基于专注数据的AI分析报告。
2. **Given** 用户查看洞察报告，**When** 系统生成分析，**Then** 报告包含专注趋势、最佳时段、改进建议等内容。
3. **Given** 用户没有足够的专注数据，**When** 尝试查看洞察，**Then** 系统提示需要更多数据或显示基础统计信息。

---

### Edge Cases

- 样本数据加载失败：显示友好错误提示，允许用户手动输入或上传文件。
- 重新生成时网络中断：保留原图表，提示网络错误，允许重试。
- 图表类型切换时数据不兼容：自动选择最合适的类型或提示用户。
- AI洞察服务不可用：显示降级提示，不影响图表正常显示。
- 样本数据格式错误：使用默认示例数据或提示用户手动输入。
- 多设备适配：TV/车机等设备上按钮布局和交互方式需适配。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系统必须在首页提供"使用样本数据"按钮，点击后自动加载预设的示例数据集到输入框。
- **FR-002**: 系统必须提供至少3种不同类型的样本数据集（如销售数据、用户数据、时间序列数据），确保用户能体验不同的图表类型。
- **FR-003**: 系统必须在图表预览页面提供"重新生成"按钮，允许用户基于当前数据重新调用AI生成图表配置。
- **FR-004**: 系统必须在图表预览页面提供"更改类型"按钮，允许用户手动切换图表类型（折线图、柱状图、饼图、散点图等）。
- **FR-005**: 系统必须在图表预览页面显示"AI 洞察"部分，展示AI对当前图表数据的智能分析和建议。
- **FR-006**: 系统必须在专注进度统计页面的"总专注时间"部分提供"AI 洞察"按钮，生成基于专注数据的分析报告。
- **FR-007**: 所有AI洞察功能必须在服务不可用时优雅降级，不影响主要功能使用。
- **FR-008**: 所有新增按钮和功能必须支持多设备适配（phone、tablet、2in1、TV、wearable、car、smartVision）。
- **FR-009**: 图表类型切换必须保持数据完整性，仅修改可视化方式，不改变数据本身。
- **FR-010**: 重新生成功能必须显示明确的加载状态，让用户了解操作进度。

### Non-Functional Requirements

- **NFR-001**: 样本数据加载时间应小于1秒，提供即时反馈。
- **NFR-002**: 图表重新生成响应时间应遵循现有AI服务SLO（P95 ≤ 3秒）。
- **NFR-003**: 图表类型切换应即时响应，无感知延迟。
- **NFR-004**: AI洞察生成应在5秒内完成，超时则显示降级提示。
- **NFR-005**: 所有新增功能必须遵循项目宪法原则（规范先行、云端优先、安全合规）。

### Supported Devices & Interaction Differences

- **设备矩阵**: phone, tablet, 2in1, tv, wearable, car, smartVision
- **布局适配**: 
  - 手机/平板：按钮正常显示，支持触控操作
  - TV/车机：按钮需支持焦点导航，使用方向键和确认键操作
  - 可穿戴：按钮布局精简，减少显示数量，支持手势操作
- **能力降级**:
  - AI洞察功能在服务不可用时显示友好提示
  - 图表类型切换在所有设备上均支持
  - 样本数据加载在所有设备上均支持

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 90%的新用户能在首次使用时通过"样本数据"功能在2分钟内完成首次图表生成。
- **SC-002**: 图表重新生成成功率≥95%，平均响应时间≤3秒（P95）。
- **SC-003**: 图表类型切换响应时间≤500ms，用户满意度≥85%。
- **SC-004**: AI洞察功能可用性≥90%，生成成功率≥80%。
- **SC-005**: 所有新增功能在多设备测试中通过率≥95%，无严重适配问题。

### Qualitative Measures

- 用户反馈显示样本数据功能降低了使用门槛
- 图表重新生成和类型切换功能提升了用户对可视化结果的控制感
- AI洞察功能提供了有价值的数据分析，用户认为有帮助

## Key Entities *(include if feature involves data)*

- **SampleDataset**: 代表预设的样本数据集；关键属性：id、name、description、data（JSON/CSV格式）、chartType。
- **ChartInsight**: 代表AI生成的图表数据洞察；关键属性：chartId、insightText、generatedAt、confidence。
- **FocusInsight**: 代表AI生成的专注数据洞察；关键属性：userId、insightText、period（周/月/年）、generatedAt。

## Dependencies

- 依赖现有的AI服务（Edge Function `generate_chart_qwen`）用于图表重新生成
- 需要新增AI洞察服务（可复用现有Edge Function或创建新的）
- 依赖现有的图表渲染能力（ChartPage.ets）
- 依赖现有的专注数据统计能力（ProgressPage.ets）

## Assumptions

- 样本数据将存储在本地资源文件中，不占用云端存储
- AI洞察功能可以复用现有的通义千问模型，通过调整prompt实现
- 图表类型切换仅修改series[0].type，不涉及数据转换
- 用户已熟悉基本的图表类型概念（折线图、柱状图等）
- 多设备适配将使用现有的deviceAdapter工具

## Clarifications Needed

以下问题需要在规划阶段明确，以确保实现方案的正确性：

### Question 1: AI洞察响应格式

**Context**: AI洞察功能需要返回文本格式的分析结果，但当前项目只有图表配置的Schema定义。

**What we need to know**: AI洞察功能的响应格式是否需要定义新的Schema，还是复用现有的chartConfig格式？

**Suggested Answers**:

| Option | Answer | Implications |
|--------|--------|--------------|
| A | 定义新的insightSchema.json，包含text、confidence、suggestions等字段 | 更规范，便于后续扩展，但需要新增Schema文件 |
| B | 复用chartConfig格式，将洞察文本放在title或tooltip中 | 实现简单，但不符合数据语义，不利于扩展 |
| C | 使用简单的文本响应，不定义Schema | 最快实现，但缺乏结构化和验证 |

**Your choice**: _[Wait for user response]_

---

### Question 2: 样本数据集配置方式

**Context**: 样本数据功能需要提供预设的示例数据集供用户快速体验。

**What we need to know**: 样本数据集的数量和类型是否需要可配置，还是固定为预设的几种？

**Suggested Answers**:

| Option | Answer | Implications |
|--------|--------|--------------|
| A | 固定3-5种预设样本数据，存储在本地资源文件 | 实现简单，加载快速，但扩展性差 |
| B | 可配置的样本数据列表，支持从配置文件或云端加载 | 灵活可扩展，但增加复杂度 |
| C | 固定样本数据，但支持后续通过更新添加新样本 | 平衡实现复杂度和扩展性 |

**Your choice**: _[Wait for user response]_

---

### Question 3: 图表类型切换范围

**Context**: 图表类型切换功能允许用户手动切换可视化方式。

**What we need to know**: 图表类型切换是否需要支持所有ECharts支持的图表类型，还是仅支持常用类型？

**Suggested Answers**:

| Option | Answer | Implications |
|--------|--------|--------------|
| A | 仅支持常用类型（折线图、柱状图、饼图、散点图） | 实现简单，用户界面清晰，覆盖80%使用场景 |
| B | 支持所有ECharts基础图表类型（约15种） | 功能完整，但界面复杂，需要更好的UI设计 |
| C | 支持常用类型，但提供"更多类型"入口展开完整列表 | 平衡易用性和功能完整性 |

**Your choice**: _[Wait for user response]_

