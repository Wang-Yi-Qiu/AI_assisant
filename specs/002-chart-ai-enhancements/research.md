# Phase 0 Research — 图表增强与AI洞察功能

## Unknowns (from Technical Context)

1) AI洞察 Edge Function 的具体实现方式（NEEDS CLARIFICATION）
2) 样本数据的存储位置和格式（NEEDS CLARIFICATION）
3) 图表类型切换的数据兼容性校验规则（NEEDS CLARIFICATION）
4) AI洞察的缓存策略（NEEDS CLARIFICATION）

## Tasks

- Research: AI洞察 Edge Function 实现方式（复用现有函数 vs 新建函数）
- Research: 样本数据在 HarmonyOS 中的最佳存储方式（rawfile vs 代码内嵌）
- Research: ECharts 图表类型切换的数据兼容性规则
- Research: AI洞察缓存策略（内存缓存 vs 持久化存储）

## Findings

### AI洞察 Edge Function 实现方式

**Decision**: 创建新的独立 Edge Function `generate_insight`，与 `generate_chart_qwen` 分离。

**Rationale**: 
- 职责分离：图表生成和洞察生成是不同的业务逻辑，独立函数便于维护和扩展
- 性能优化：洞察生成可以独立优化和缓存，不影响图表生成性能
- 错误隔离：洞察生成失败不影响图表生成功能
- 扩展性：后续可以支持不同类型的洞察（图表洞察、专注洞察等）

**Alternatives considered**:
- 复用 `generate_chart_qwen`：会增加函数复杂度，混合两种不同的业务逻辑
- 在现有函数中添加参数：会导致函数职责不清，参数验证复杂

**Implementation**:
- 新建 `supabase/functions/generate_insight/index.ts`
- 支持两种洞察类型：`chart`（图表数据洞察）和 `focus`（专注数据洞察）
- 复用 Qwen 模型，通过不同的 prompt 实现不同类型的洞察
- 遵循现有架构：Schema 校验、错误处理、超时控制

---

### 样本数据存储位置和格式

**Decision**: 使用 HarmonyOS rawfile 资源目录存储样本数据，格式为 JSON 文件。

**Rationale**:
- 性能优势：rawfile 资源在应用安装时已打包，加载速度快（<1s）
- 维护简单：数据文件独立，便于更新和维护
- 多设备支持：rawfile 在所有设备类型上都能正常访问
- 无网络依赖：本地资源加载，不受网络状态影响

**Alternatives considered**:
- 代码内嵌：数据混在代码中，不便于维护和更新
- 云端存储：需要网络请求，加载时间不可控，不符合"快速体验"目标
- 配置文件：需要额外的解析逻辑，增加复杂度

**Implementation**:
- 目录结构：`entry/src/main/resources/rawfile/sample-data/`
- 文件命名：`{category}-{name}.json`（如 `sales-monthly.json`）
- 数据格式：标准 JSON 数组，包含示例数据
- 元数据：在代码中定义样本数据列表，包含 id、name、description、filePath

**Sample Data Structure**:
```json
{
  "id": "sales-monthly",
  "name": "月度销售数据",
  "description": "展示月度销售趋势的示例数据",
  "data": [
    {"month": "2024-01", "sales": 12000},
    {"month": "2024-02", "sales": 15000},
    ...
  ],
  "chartType": "line"
}
```

---

### 图表类型切换的数据兼容性校验规则

**Decision**: 实现轻量级的数据兼容性校验，基于数据维度和类型进行判断。

**Rationale**:
- 用户体验：快速切换，即时反馈，无需等待服务端验证
- 性能要求：≤500ms 响应时间，需要轻量级校验
- 覆盖场景：常用类型（line、bar、pie、scatter）的兼容性规则相对简单

**Compatibility Rules**:
1. **折线图（line）**: 需要至少2个数据点，支持数值类型
2. **柱状图（bar）**: 需要至少1个数据点，支持数值类型
3. **饼图（pie）**: 需要至少1个数据点，支持数值类型（通常需要百分比或比例数据）
4. **散点图（scatter）**: 需要至少2个数据点，需要 x、y 两个数值维度

**Implementation**:
- 前端校验：在 `chartTypeSwitcher.ets` 中实现校验逻辑
- 校验时机：切换前进行快速校验，不兼容时提示用户或自动选择合适类型
- 降级策略：如果数据不兼容，显示友好提示，保留当前图表类型

**Alternatives considered**:
- 服务端校验：会增加网络延迟，不符合即时响应要求
- 完整数据转换：复杂度高，不符合 MVP 原则

---

### AI洞察缓存策略

**Decision**: 使用内存缓存（客户端）+ 可选持久化缓存（服务端），缓存时间 1 小时。

**Rationale**:
- 性能优化：相同图表/专注数据的洞察可以复用，减少 AI 调用
- 成本控制：减少不必要的 AI 服务调用，降低 API 成本
- 用户体验：缓存的洞察可以即时显示，提升响应速度

**Cache Strategy**:
1. **客户端内存缓存**:
   - 缓存键：`{type}-{dataHash}`（如 `chart-abc123`、`focus-user123-week`）
   - 缓存时间：1 小时
   - 存储位置：应用内存，页面关闭后清除

2. **服务端持久化缓存（可选）**:
   - 存储位置：Supabase PostgreSQL `insights` 表
   - 缓存键：`{type}-{dataHash}-{period}`（专注洞察需要时间周期）
   - 缓存时间：1 小时（可配置）
   - RLS 策略：用户只能访问自己的洞察缓存

**Implementation**:
- 客户端：在 `aiService.ets` 中实现内存缓存逻辑
- 服务端：在 `generate_insight` Edge Function 中实现缓存查询和存储
- 缓存失效：超过缓存时间或数据变更时自动失效

**Alternatives considered**:
- 仅内存缓存：简单但无法跨会话复用
- 仅持久化缓存：增加数据库依赖，复杂度高
- 无缓存：每次调用 AI 服务，成本高，响应慢

---

## Resolutions

- **AI洞察实现**: 新建独立 Edge Function `generate_insight`，支持图表和专注两种洞察类型
- **样本数据存储**: 使用 rawfile 资源目录，JSON 格式，本地加载
- **类型切换校验**: 前端轻量级校验，基于数据维度和类型，不兼容时提示用户
- **洞察缓存策略**: 客户端内存缓存 + 可选服务端持久化缓存，缓存时间 1 小时

## Impact

- Constitution Check 无阻塞；所有澄清问题已解决
- Phase 1 可继续：技术方案明确，实现路径清晰
- 性能目标可达成：样本数据本地加载 <1s，类型切换 <500ms，洞察缓存提升响应速度

## Cross-Device Design References

- **样本数据加载**: rawfile 资源在所有设备上都能正常访问，无需特殊适配
- **类型切换**: 前端实现，所有设备响应一致，TV/车机通过焦点导航选择类型
- **AI洞察**: 异步加载，服务不可用时降级显示，不影响主要功能
- **缓存策略**: 内存缓存在所有设备上工作一致，持久化缓存需要网络连接

