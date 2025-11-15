# Implementation Tasks: 图表增强与AI洞察功能

**Feature Branch**: `002-chart-ai-enhancements`  
**Created**: 2025-01-28  
**Spec**: `specs/002-chart-ai-enhancements/spec.md`  
**Plan**: `specs/002-chart-ai-enhancements/plan.md`

## Summary

- **Total Tasks**: 57
- **User Stories**: 5 (US1-P1, US2-P1, US3-P2, US4-P2, US5-P3)
- **MVP Scope**: US1 (样本数据快速体验) + US2 (图表重新生成)
- **Parallel Opportunities**: 多个工具函数和UI组件可并行开发

## Implementation Strategy

**MVP First**: 优先实现 P1 用户故事（US1, US2），提供核心价值。  
**Incremental Delivery**: 每个用户故事独立可测试，可单独交付。  
**Parallel Execution**: 工具函数、UI组件、Edge Function 可并行开发。

---

## Phase 1: Setup & Validation

**Goal**: 验证合同文件，确保Schema和OpenAPI定义正确，为实施做准备。

### Independent Test Criteria
- ✅ 所有Schema文件通过JSON Schema验证
- ✅ OpenAPI定义通过 `spec-kit validate` 验证
- ✅ 项目结构符合plan.md定义

### Tasks

- [x] T001 验证 insightSchema.json 格式正确性，运行 `spec-kit validate` 检查 `specs/002-chart-ai-enhancements/contracts/schemas/insightSchema.json`
- [x] T002 验证 sampleDataset.schema.json 格式正确性，运行 `spec-kit validate` 检查 `specs/002-chart-ai-enhancements/contracts/schemas/sampleDataset.schema.json`
- [x] T003 验证 OpenAPI 定义完整性，运行 `spec-kit validate` 检查 `specs/002-chart-ai-enhancements/contracts/openapi.yaml`
- [x] T004 创建样本数据目录结构，创建 `entry/src/main/resources/rawfile/sample-data/` 目录

---

## Phase 2: Foundational Tasks

**Goal**: 实现基础工具函数和共享组件，为所有用户故事提供支撑。

### Independent Test Criteria
- ✅ 所有工具函数可通过单元测试
- ✅ 多设备适配工具正常工作
- ✅ 错误处理机制完善

### Tasks

- [x] T005 [P] 创建样本数据管理器工具类，实现 `entry/src/main/ets/utils/sampleDataManager.ets`，包含加载rawfile资源、解析JSON、错误处理功能
- [x] T006 [P] 创建图表类型切换工具类，实现 `entry/src/main/ets/utils/chartTypeSwitcher.ets`，包含类型切换逻辑、数据兼容性校验、类型映射功能
- [x] T007 [P] 扩展AI服务工具类，在 `entry/src/main/ets/utils/aiService.ets` 中新增 `generateInsight()` 方法，支持图表洞察和专注洞察调用
- [x] T008 [P] 扩展错误处理工具，在 `entry/src/main/ets/utils/errorHandler.ets` 中新增AI洞察相关错误码和处理逻辑

---

## Phase 3: User Story 1 - 样本数据快速体验 (P1)

**Goal**: 实现样本数据快速体验功能，让新用户一键加载示例数据并生成图表。

**Independent Test**: 用户可以通过一次点击完成数据加载和图表生成，具备独立演示价值。

**Acceptance Criteria**:
- 用户在首页点击"使用样本数据"按钮，输入框自动填充预设数据（<1秒）
- 样本数据已加载后，点击"生成图表"成功生成并显示示例图表
- 所有支持的设备类型都能正常加载和显示样本数据

### Tasks

- [x] T009 [US1] 创建样本数据JSON文件 - 月度销售数据，创建 `entry/src/main/resources/rawfile/sample-data/sales-monthly.json`，包含月度销售数据示例，适合折线图和柱状图
- [x] T010 [US1] 创建样本数据JSON文件 - 用户增长数据，创建 `entry/src/main/resources/rawfile/sample-data/users-growth.json`，包含用户增长数据示例，适合折线图和柱状图
- [x] T011 [US1] 创建样本数据JSON文件 - 产品分类占比数据，创建 `entry/src/main/resources/rawfile/sample-data/products-category.json`，包含产品分类占比数据示例，适合饼图
- [x] T012 [US1] 创建样本数据JSON文件 - 销售与利润关系数据，创建 `entry/src/main/resources/rawfile/sample-data/sales-profit.json`，包含销售与利润关系数据示例，适合散点图
- [x] T013 [US1] 创建样本数据JSON文件 - 时间序列数据，创建 `entry/src/main/resources/rawfile/sample-data/timeseries-daily.json`，包含时间序列数据示例，适合折线图
- [x] T014 [US1] 在 sampleDataManager.ets 中实现样本数据列表元数据，定义5种样本数据的 id、name、description、filePath、category、chartType
- [x] T015 [US1] 在 sampleDataManager.ets 中实现 loadSampleData() 方法，从rawfile加载指定样本数据，返回JSON字符串
- [x] T016 [US1] 在 sampleDataManager.ets 中实现 getSampleDataList() 方法，返回所有可用样本数据列表
- [x] T017 [US1] 在 HomePage.ets 中新增"使用样本数据"按钮，支持多设备布局：phone/tablet正常显示支持触控操作；TV/车机支持焦点导航（焦点导航顺序从左到右、从上到下Tab键顺序，焦点指示器提供清晰视觉反馈如高亮边框/阴影效果，方向键移动焦点、确认键触发操作、返回键返回上一级）；可穿戴精简显示支持手势操作
- [x] T018 [US1] 在 HomePage.ets 中实现样本数据选择逻辑，点击按钮后调用 sampleDataManager 加载数据并填充输入框
- [x] T019 [US1] 在 HomePage.ets 中实现样本数据加载错误处理，包括：文件不存在时显示"样本数据文件不存在，请手动输入数据"（Toast 2秒 + 输入框下方红色文字提示）；JSON格式错误时显示"样本数据格式错误，请手动输入数据"；数据为空或无效时显示"样本数据无效，请手动输入数据"；数据字段缺失时显示"样本数据不完整，请手动输入数据"；文件损坏或无效JSON格式时显示"样本数据文件损坏，请手动输入数据"；设备存储空间不足时显示"存储空间不足，请清理空间后重试"；设备内存不足时显示"内存不足，请关闭其他应用后重试"；加载超时（>3秒）时显示"加载超时，请手动输入数据"；部分样本数据加载成功部分失败时显示已加载的数据，对失败的数据显示错误提示；所有错误提示允许用户手动输入或上传文件

---

## Phase 4: User Story 2 - 图表重新生成 (P1)

**Goal**: 实现图表重新生成功能，允许用户基于相同数据重新调用AI生成新的图表配置。

**Independent Test**: 用户可以在不改变数据的情况下获得新的图表配置，具备独立价值。

**Acceptance Criteria**:
- 图表页面显示图表时，点击"重新生成"按钮，系统基于当前数据重新调用AI生成新配置并更新显示
- 重新生成过程中显示加载状态，完成后平滑切换到新图表
- 重新生成失败或超时时，显示友好错误提示，保留原图表显示

### Tasks

- [x] T020 [US2] 在 ChartPage.ets 中新增"重新生成"按钮，支持多设备布局和交互：phone/tablet正常显示支持触控操作；TV/车机支持焦点导航（焦点导航顺序从左到右、从上到下Tab键顺序，焦点指示器提供清晰视觉反馈如高亮边框/阴影效果，方向键移动焦点、确认键触发操作、返回键返回上一级）；可穿戴精简显示支持手势操作
- [x] T021 [US2] 在 ChartPage.ets 中实现重新生成按钮点击处理，包括：优先从内存中获取原始数据；如果原始数据已从内存中清除，则从当前显示的图表配置中提取数据用于重新生成；如果当前图表配置无效，显示"无法重新生成，请重新输入数据"提示并引导用户返回首页；调用现有 generate_chart_qwen Edge Function
- [x] T022 [US2] 在 ChartPage.ets 中实现重新生成加载状态显示，包括：视觉指示器（显示加载动画如旋转图标或进度条，覆盖在图表区域或按钮上）、状态提示（显示"正在重新生成图表..."文字提示）、用户反馈（按钮状态变为禁用disabled，防止重复点击）、完成反馈（加载完成后新图表平滑切换显示，加载动画消失）
- [x] T023 [US2] 在 ChartPage.ets 中实现重新生成成功处理，验证返回的图表配置，平滑切换到新图表
- [x] T024 [US2] 在 ChartPage.ets 中实现重新生成错误处理，包括：检测到网络错误时保留原图表显示，显示"网络连接失败，请检查网络后重试"提示并提供重试按钮；服务超时时保留原图表显示，显示"服务响应超时，请稍后重试"提示并提供重试按钮；重试机制：用户点击重试按钮后重新调用AI服务生成图表；快速连续点击时仅处理最后一次点击，忽略中间请求；图表重新生成成功但AI洞察生成失败时显示新图表，洞察区域显示降级提示

---

## Phase 5: User Story 3 - 图表类型切换 (P2)

**Goal**: 实现图表类型切换功能，允许用户手动切换图表类型（折线图、柱状图、饼图、散点图）。

**Independent Test**: 用户可以在不重新调用AI的情况下切换图表类型，具备独立价值。

**Acceptance Criteria**:
- 图表页面显示折线图时，点击"更改类型"并选择"柱状图"，图表立即切换为柱状图，数据保持不变
- 图表类型切换时，图表配置正确更新，图表平滑过渡显示（≤500ms）
- 当前数据不适合某种图表类型时，系统提示该类型不适用或自动选择最合适的类型

### Tasks

- [x] T025 [US3] 在 chartTypeSwitcher.ets 中实现支持的图表类型列表，定义 line、bar、pie、scatter 四种类型及其显示名称
- [x] T026 [US3] 在 chartTypeSwitcher.ets 中实现数据兼容性校验函数，检查数据是否适合指定图表类型（数据维度、数据点数量等）
- [x] T027 [US3] 在 chartTypeSwitcher.ets 中实现 switchChartType() 方法，接收当前图表配置和目标类型，返回更新后的配置
- [x] T028 [US3] 在 chartTypeSwitcher.ets 中实现自动选择合适类型逻辑，当目标类型不兼容时，自动选择最合适的类型
- [x] T029 [US3] 在 ChartPage.ets 中新增"更改类型"按钮，支持多设备布局：phone/tablet正常显示支持触控操作；TV/车机支持焦点导航（焦点导航顺序从左到右、从上到下Tab键顺序，焦点指示器提供清晰视觉反馈如高亮边框/阴影效果，方向键移动焦点、确认键触发操作、返回键返回上一级）；可穿戴精简显示支持手势操作
- [x] T030 [US3] 在 ChartPage.ets 中实现图表类型选择器UI，显示可用类型列表（折线图、柱状图、饼图、散点图）
- [x] T031 [US3] 在 ChartPage.ets 中实现类型切换处理逻辑，调用 chartTypeSwitcher.switchChartType()，更新图表配置并重新渲染
- [x] T032 [US3] 在 ChartPage.ets 中实现类型不兼容提示，包括：数据维度不足时显示"当前数据不适合该图表类型，已自动选择最合适的类型"提示并自动切换到兼容类型；数据点数量不足时显示"当前数据点数量不足，已自动选择最合适的类型"提示并自动切换到兼容类型；所有类型都不兼容时显示"当前数据无法切换图表类型，请使用重新生成功能"提示并保留当前图表类型；同时切换类型时仅处理最后一次选择，立即响应；图表类型切换成功但数据验证部分失败时显示切换后的图表，显示数据验证警告提示

---

## Phase 6: User Story 4 - 图表数据AI洞察 (P2)

**Goal**: 实现图表数据AI洞察功能，在图表预览页面显示AI对当前图表数据的智能分析和建议。

**Independent Test**: 用户可以获得数据洞察，具备独立价值。

**Acceptance Criteria**:
- 图表页面显示图表时，查看"AI 洞察"部分，显示AI生成的数据分析文本（趋势、关键点、建议等）
- 用户首次查看洞察时，系统调用AI服务，显示加载状态，完成后展示洞察内容
- AI洞察生成失败时，显示友好提示，不影响图表正常显示

### Tasks

- [x] T033 [US4] 创建 generate_insight Edge Function，实现 `supabase/functions/generate_insight/index.ts`，支持图表洞察类型（type: 'chart'）
- [x] T034 [US4] 在 generate_insight/index.ts 中实现输入Schema校验，使用Ajv验证请求参数符合OpenAPI定义
- [x] T035 [US4] 在 generate_insight/index.ts 中实现Qwen模型调用，使用通义千问生成图表数据洞察，prompt设计必须确保返回的洞察内容包含：趋势分析（数据的变化趋势：上升、下降、波动等）、关键点（数据中的最大值、最小值、异常值等关键信息）、建议（基于数据分析的操作建议），遵循模型策略（response_format=json_object, temperature=0）
- [x] T036 [US4] 在 generate_insight/index.ts 中实现输出Schema校验，验证返回的洞察数据符合 insightSchema.json
- [x] T037 [US4] 在 generate_insight/index.ts 中实现超时控制（5秒）和错误处理，超时或失败时返回降级提示
- [x] T038 [US4] 在 aiService.ets 中实现 generateChartInsight() 方法，调用 generate_insight Edge Function，传递图表配置或原始数据
- [x] T039 [US4] 在 aiService.ets 中实现洞察内存缓存逻辑，缓存键为 `chart-{dataHash}`，缓存时间1小时
- [x] T040 [US4] 在 ChartPage.ets 中新增"AI 洞察"区域UI，支持折叠/展开，可穿戴设备精简显示；TV/车机支持焦点导航（焦点导航顺序从左到右、从上到下Tab键顺序，焦点指示器提供清晰视觉反馈如高亮边框/阴影效果，方向键移动焦点、确认键触发操作、返回键返回上一级）
- [x] T041 [US4] 在 ChartPage.ets 中实现洞察加载逻辑，首次查看时调用 aiService.generateChartInsight()，显示加载状态
- [x] T042 [US4] 在 ChartPage.ets 中实现洞察显示逻辑，展示AI生成的洞察文本，必须包括：趋势分析（数据的变化趋势：上升、下降、波动等）、关键点（数据中的最大值、最小值、异常值等关键信息）、建议（基于数据分析的操作建议，如"建议关注X月的异常下降"）
- [x] T043 [US4] 在 ChartPage.ets 中实现洞察错误处理，包括：服务超时（>5秒）时显示"AI洞察生成超时，请稍后重试"Toast提示（2秒），不影响图表正常显示；服务错误（网络错误、服务不可用等）时显示"AI洞察暂时不可用，请稍后重试"Toast提示（2秒），不影响图表正常显示；降级时图表生成、类型切换等主要功能正常使用；用户可以通过刷新页面或重新打开洞察区域重新尝试；在AI洞察加载过程中切换图表类型时取消洞察请求，立即切换图表类型

---

## Phase 7: User Story 5 - 专注数据AI洞察 (P3)

**Goal**: 实现专注数据AI洞察功能，在专注进度统计页面提供基于专注时间数据的智能分析报告。

**Independent Test**: 用户可以获得专注数据分析，具备独立价值。

**Acceptance Criteria**:
- 用户在专注进度统计页面，点击"总专注时间"部分的"AI 洞察"按钮，显示基于专注数据的AI分析报告
- 用户查看洞察报告时，报告包含专注趋势、最佳时段、改进建议等内容
- 用户没有足够的专注数据时，系统提示需要更多数据或显示基础统计信息

### Tasks

- [x] T044 [US5] 在 generate_insight/index.ts 中扩展支持专注洞察类型（type: 'focus'），处理专注数据请求
- [x] T045 [US5] 在 generate_insight/index.ts 中实现专注洞察的Qwen模型调用，使用不同的prompt生成专注数据分析
- [x] T046 [US5] 在 aiService.ets 中实现 generateFocusInsight() 方法，调用 generate_insight Edge Function，传递用户ID、周期、专注数据
- [x] T047 [US5] 在 aiService.ets 中实现专注洞察内存缓存逻辑，缓存键为 `focus-{userId}-{period}`，缓存时间1小时
- [x] T048 [US5] 在 ProgressPage.ets（或对应专注统计页面）中新增"AI 洞察"按钮，位于"总专注时间"部分（已创建 FocusProgressPage.ets 示例实现）
- [x] T049 [US5] 在 ProgressPage.ets 中实现专注洞察加载逻辑，点击按钮后调用 aiService.generateFocusInsight()，传递当前周期和专注数据（已在 FocusProgressPage.ets 中实现）
- [x] T050 [US5] 在 ProgressPage.ets 中实现专注洞察显示逻辑，展示AI生成的分析报告（专注趋势、最佳时段、改进建议等）（已在 FocusProgressPage.ets 中实现）
- [x] T051 [US5] 在 ProgressPage.ets 中实现数据不足处理，当专注数据不足时，显示友好提示或基础统计信息（已在 FocusProgressPage.ets 中实现）

---

## Phase 8: Polish & Cross-Cutting Concerns

**Goal**: 完善多设备适配、错误处理、性能优化等横切关注点。

### Tasks

- [x] T052 完善多设备适配，确保所有新增按钮和功能在 phone、tablet、2in1、TV、wearable、car、smartVision 上正常工作，包括：TV/车机实现焦点导航（焦点导航顺序从左到右、从上到下Tab键顺序，焦点指示器提供清晰视觉反馈如高亮边框/阴影效果，方向键移动焦点、确认键触发操作、返回键返回上一级）；可穿戴设备精简按钮布局，减少显示数量，支持手势操作，关键功能≤2步完成；所有设备按钮布局和交互方式需适配，确保功能可用性（已实现，详见 IMPLEMENTATION_VERIFICATION.md）
- [x] T053 优化性能，确保样本数据加载≤1秒，类型切换≤500ms，AI洞察生成≤5秒（超时降级）（已实现，详见 IMPLEMENTATION_VERIFICATION.md）
- [x] T054 完善错误处理，所有新增功能都有完善的错误处理和用户友好的错误提示（已实现，详见 IMPLEMENTATION_VERIFICATION.md）
- [x] T055 添加单元测试，为 sampleDataManager.ets 和 chartTypeSwitcher.ets 添加最小测试覆盖（已添加 sampleDataManager.test.ets 和 chartTypeSwitcher.test.ets）
- [x] T056 添加合约测试，为 generate_insight Edge Function 添加基于OpenAPI/Schema的请求-响应校验测试（已添加 generate_insight.test.ts）
- [x] T057 验证Constitution遵循，确保所有实施遵循规范先行、云端优先、安全合规等原则（已验证，详见 IMPLEMENTATION_VERIFICATION.md）

---

## Dependencies & Story Completion Order

### Story Dependencies Graph

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundational)
    ↓
Phase 3 (US1: 样本数据) ──┐
    ↓                      │
Phase 4 (US2: 重新生成) ────┤ 可并行
    ↓                      │
Phase 5 (US3: 类型切换) ────┤
    ↓                      │
Phase 6 (US4: 图表洞察) ────┤
    ↓                      │
Phase 7 (US5: 专注洞察) ────┘
    ↓
Phase 8 (Polish)
```

### Critical Path

1. **Phase 1** → **Phase 2** → **Phase 3** (US1) → **Phase 4** (US2) → **Phase 8**
   - MVP路径：样本数据 + 重新生成

2. **Phase 2** → **Phase 5** (US3) → **Phase 8**
   - 类型切换独立路径

3. **Phase 2** → **Phase 6** (US4) → **Phase 7** (US5) → **Phase 8**
   - AI洞察路径（依赖Edge Function）

### Parallel Execution Opportunities

**Within Phase 2 (Foundational)**:
- T005, T006, T007, T008 可并行（不同文件，无依赖）

**Within Phase 3 (US1)**:
- T009, T010, T011 可并行（不同数据文件）
- T012, T013, T014 可并行（同一文件不同方法）

**Within Phase 4 (US2)**:
- T018, T019, T020 可串行，但UI和逻辑可并行开发

**Within Phase 6 (US4)**:
- T031-T035 (Edge Function) 可串行开发
- T036, T037 (aiService扩展) 可并行
- T038-T041 (ChartPage UI) 可串行

**Cross-Phase Parallel**:
- Phase 3 (US1) 和 Phase 4 (US2) 可并行（不同页面）
- Phase 5 (US3) 和 Phase 6 (US4) 可并行（不同功能）
- Phase 6 (US4) 和 Phase 7 (US5) 可并行（不同洞察类型）

---

## MVP Scope Recommendation

**Recommended MVP**: Phase 1 + Phase 2 + Phase 3 (US1) + Phase 4 (US2) + Phase 8 (部分)

**Rationale**:
- US1 和 US2 都是 P1 优先级，提供核心价值
- 样本数据降低使用门槛，重新生成提供控制感
- 两个功能独立可测试，可快速交付
- 为后续功能（类型切换、AI洞察）奠定基础

**MVP Tasks**: T001-T022, T050-T052 (部分Polish任务)

---

## Notes

- 所有任务必须遵循项目宪法原则（规范先行、云端优先、安全合规）
- Edge Function 必须通过 `spec-kit validate` 验证
- 所有新增功能必须支持多设备适配
- 性能目标：样本数据加载≤1秒，类型切换≤500ms，AI洞察≤5秒
- 错误处理必须优雅降级，不影响主要功能

