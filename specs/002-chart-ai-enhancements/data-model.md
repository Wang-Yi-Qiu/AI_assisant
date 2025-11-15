# Data Model — 图表增强与AI洞察功能

## Entities

### SampleDataset（本地资源，非数据库实体）

- **Fields**: 
  - `id` (string): 样本数据唯一标识
  - `name` (string): 样本数据名称（如"月度销售数据"）
  - `description` (string): 样本数据描述
  - `filePath` (string): rawfile 资源路径（如 `sample-data/sales-monthly.json`）
  - `chartType` (string, optional): 推荐的图表类型（line/bar/pie/scatter）
  - `category` (string): 数据类别（sales/users/timeseries 等）

- **Storage**: 存储在 `entry/src/main/resources/rawfile/sample-data/` 目录
- **Validation**: 
  - 文件必须存在且可读
  - JSON 格式必须有效
  - 数据必须包含至少1个数据点

- **Notes**: 本地资源，不占用数据库存储。在代码中定义样本数据列表元数据。

---

### ChartInsight（可选持久化）

- **Fields**: 
  - `id` (uuid, primary key)
  - `chartId` (uuid, foreign key to charts table): 关联的图表ID
  - `ownerId` (uuid, foreign key to auth.users): 用户ID
  - `insightText` (text): AI生成的洞察文本
  - `confidence` (float, 0-1): 洞察置信度（可选）
  - `suggestions` (jsonb, optional): 结构化建议（可选）
  - `generatedAt` (timestamp): 生成时间
  - `expiresAt` (timestamp): 缓存过期时间（生成时间 + 1小时）

- **Storage**: Supabase PostgreSQL `insights` 表（可选，用于持久化缓存）
- **Validation**: 
  - `insightText` 不能为空
  - `confidence` 范围 0-1
  - `expiresAt` 必须晚于 `generatedAt`

- **RLS Policies**:
```sql
-- Enable RLS on insights table
ALTER TABLE insights ENABLE ROW LEVEL SECURITY;

-- Users can only see their own insights
CREATE POLICY insights_select_own ON insights FOR SELECT
  USING (auth.uid() = owner_id);

-- Users can only insert their own insights
CREATE POLICY insights_insert_own ON insights FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

-- Users can only update their own insights
CREATE POLICY insights_update_own ON insights FOR UPDATE
  USING (auth.uid() = owner_id);
```

- **Indexes**:
```sql
-- Index for cache lookup
CREATE INDEX idx_insights_chart_cache ON insights(chart_id, owner_id, expires_at)
  WHERE expires_at > NOW();

-- Index for user queries
CREATE INDEX idx_insights_owner ON insights(owner_id, generated_at DESC);
```

---

### FocusInsight（可选持久化）

- **Fields**: 
  - `id` (uuid, primary key)
  - `userId` (uuid, foreign key to auth.users): 用户ID
  - `insightText` (text): AI生成的专注数据洞察文本
  - `period` (text): 分析周期（week/month/year）
  - `periodStart` (date): 周期开始日期
  - `periodEnd` (date): 周期结束日期
  - `confidence` (float, 0-1): 洞察置信度（可选）
  - `suggestions` (jsonb, optional): 结构化建议（可选）
  - `generatedAt` (timestamp): 生成时间
  - `expiresAt` (timestamp): 缓存过期时间（生成时间 + 1小时）

- **Storage**: Supabase PostgreSQL `focus_insights` 表（可选，用于持久化缓存）
- **Validation**: 
  - `insightText` 不能为空
  - `period` 必须是 week/month/year 之一
  - `periodEnd` 必须晚于 `periodStart`
  - `confidence` 范围 0-1

- **RLS Policies**:
```sql
-- Enable RLS on focus_insights table
ALTER TABLE focus_insights ENABLE ROW LEVEL SECURITY;

-- Users can only see their own focus insights
CREATE POLICY focus_insights_select_own ON focus_insights FOR SELECT
  USING (auth.uid() = user_id);

-- Users can only insert their own focus insights
CREATE POLICY focus_insights_insert_own ON focus_insights FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

- **Indexes**:
```sql
-- Index for cache lookup
CREATE INDEX idx_focus_insights_user_cache ON focus_insights(user_id, period, period_start, expires_at)
  WHERE expires_at > NOW();

-- Index for user queries
CREATE INDEX idx_focus_insights_user ON focus_insights(user_id, generated_at DESC);
```

---

## Relationships

- **User 1—N ChartInsight**: 一个用户可以有多条图表洞察记录
- **Chart 1—1 ChartInsight**: 一个图表可以有一条洞察记录（缓存）
- **User 1—N FocusInsight**: 一个用户可以有多条专注洞察记录（不同周期）

---

## Validation Rules

### 样本数据验证

- **文件存在性**: 加载前检查 rawfile 资源是否存在
- **JSON 格式**: 解析 JSON 时进行格式验证
- **数据完整性**: 验证数据包含必要的字段（至少1个数据点）
- **错误处理**: 文件不存在或格式错误时，显示友好提示，允许用户手动输入

### 图表类型切换验证

- **数据维度检查**: 
  - 折线图（line）：需要至少1个数值字段，用于Y轴数据
  - 柱状图（bar）：需要至少1个数值字段，用于Y轴数据
  - 饼图（pie）：需要至少1个数值字段（通常需要比例数据或百分比数据）
  - 散点图（scatter）：需要至少2个数值字段（x、y 坐标），分别用于X轴和Y轴
- **数据点数量**: 
  - 折线图（line）：至少2个数据点（需要至少2个点才能形成趋势线）
  - 散点图（scatter）：至少2个数据点（需要至少2个点才能展示关系）
  - 柱状图（bar）：至少1个数据点（单个数据点也可以显示）
  - 饼图（pie）：至少1个数据点（单个数据点也可以显示，但通常需要多个分类）
- **类型兼容性**: 
  - 不兼容时自动选择最合适的类型：如果散点图不兼容（缺少2个数值维度），自动选择折线图或柱状图
  - 如果所有类型都不兼容：显示"当前数据无法切换图表类型，请使用重新生成功能"提示，保留当前图表类型
  - 数据为空或无效：显示"当前数据无效，无法切换图表类型"提示，保留当前图表类型
- **边界情况处理**:
  - 当前图表没有有效数据点：显示"当前图表无数据，无法切换类型"提示，保留当前图表类型
  - 数据点数量不足：根据类型要求，自动选择兼容的类型或提示用户
  - 数据维度不足：根据类型要求，自动选择兼容的类型或提示用户

### AI洞察验证

- **输入验证**: 
  - 图表洞察：需要有效的图表配置或数据
    - 图表配置必须包含有效的 series 数据
    - 数据不能为空或无效
    - 如果图表数据为空：显示"当前图表无数据，无法生成洞察"提示
  - 专注洞察：需要有效的用户ID和时间周期
    - 用户ID必须有效（已登录用户）
    - 时间周期必须是 week/month/year 之一
    - 如果用户没有足够的专注数据：显示"需要更多专注数据才能生成洞察"提示或显示基础统计信息
- **输出验证**: 
  - 响应必须符合 `insightSchema.json`
  - `insightText` 不能为空（如果为空，显示"洞察生成失败，请稍后重试"提示）
  - `confidence` 范围 0-1（如果超出范围，使用默认值 0.5）
  - 如果响应格式不符合Schema：显示"洞察数据格式错误，请稍后重试"提示
- **缓存验证**: 
  - 检查缓存是否过期（expiresAt > NOW()）
  - 缓存命中时直接返回，未命中时调用 AI 服务
  - 如果缓存查询失败：继续调用 AI 服务，不阻塞用户请求
- **缓存过期和刷新行为**:
  - 缓存过期时间：1小时（从生成时间开始计算）
  - 缓存刷新时机：缓存过期后，用户再次请求洞察时自动刷新
  - 缓存刷新策略：过期后立即清除缓存，重新调用 AI 服务生成新洞察
  - 手动刷新：用户可以通过刷新按钮或重新打开洞察区域手动刷新缓存
  - 数据变更检测：如果图表数据或专注数据发生变化，自动清除相关缓存
- **边界情况处理**:
  - AI洞察生成时图表数据为空或无效：显示"当前图表无数据，无法生成洞察"提示
  - AI洞察生成时专注数据不足：显示"需要更多专注数据才能生成洞察"提示或显示基础统计信息
  - AI洞察服务超时（>5秒）：显示"AI洞察生成超时，请稍后重试"提示，不影响图表正常显示
  - AI洞察服务错误：显示"AI洞察暂时不可用，请稍后重试"提示，不影响图表正常显示

---

## State Transitions

### 样本数据加载流程

```
初始状态 → 用户点击"使用样本数据" → 加载 rawfile 资源 → 解析 JSON → 填充输入框 → 完成
                ↓ (文件不存在)
            显示"样本数据文件不存在，请手动输入数据"提示 → 允许手动输入
                ↓ (JSON格式错误)
            显示"样本数据格式错误，请手动输入数据"提示 → 允许手动输入
                ↓ (数据为空或无效)
            显示"样本数据无效，请手动输入数据"提示 → 允许手动输入
                ↓ (设备存储/内存不足)
            显示"存储空间不足"或"内存不足"提示 → 允许手动输入
                ↓ (加载超时>3秒)
            显示"加载超时，请手动输入数据"提示 → 允许手动输入
```

### 图表类型切换流程

```
当前图表类型 → 用户选择新类型 → 数据兼容性校验 → 更新 series[0].type → 重新渲染 → 完成
                    ↓ (数据维度不足)
                自动选择最合适的类型 → 更新 series[0].type → 重新渲染 → 显示提示 → 完成
                    ↓ (数据点数量不足)
                自动选择最合适的类型 → 更新 series[0].type → 重新渲染 → 显示提示 → 完成
                    ↓ (所有类型都不兼容)
                显示"当前数据无法切换图表类型，请使用重新生成功能"提示 → 保留当前类型
                    ↓ (数据为空或无效)
                显示"当前数据无效，无法切换图表类型"提示 → 保留当前类型
                    ↓ (并发切换)
                仅处理最后一次选择 → 忽略中间选择 → 立即响应
```

### AI洞察生成流程

```
用户请求洞察 → 检查内存缓存 → 命中：返回缓存
                ↓ (未命中)
            检查持久化缓存 → 命中：返回缓存并更新内存缓存
                ↓ (未命中)
            输入验证（图表数据/专注数据有效性） → 调用 AI 服务 → 生成洞察 → 验证 Schema → 存储缓存 → 返回结果
                ↓ (输入无效：图表数据为空)
            显示"当前图表无数据，无法生成洞察"提示 → 不影响主要功能
                ↓ (输入无效：专注数据不足)
            显示"需要更多专注数据才能生成洞察"提示或显示基础统计信息 → 不影响主要功能
                ↓ (服务超时>5秒)
            显示"AI洞察生成超时，请稍后重试"提示 → 不影响主要功能
                ↓ (服务错误)
            显示"AI洞察暂时不可用，请稍后重试"提示 → 不影响主要功能
                ↓ (响应格式错误)
            显示"洞察数据格式错误，请稍后重试"提示 → 不影响主要功能
                ↓ (并发请求)
            取消之前的请求 → 仅处理最后一次请求
```

---

## Data Migration（如需要）

如果需要在现有数据库中创建 `insights` 和 `focus_insights` 表：

```sql
-- Create insights table for chart insights cache
CREATE TABLE IF NOT EXISTS insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chart_id UUID REFERENCES charts(id) ON DELETE CASCADE,
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  insight_text TEXT NOT NULL,
  confidence FLOAT CHECK (confidence >= 0 AND confidence <= 1),
  suggestions JSONB,
  generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create focus_insights table for focus insights cache
CREATE TABLE IF NOT EXISTS focus_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  insight_text TEXT NOT NULL,
  period TEXT NOT NULL CHECK (period IN ('week', 'month', 'year')),
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  confidence FLOAT CHECK (confidence >= 0 AND confidence <= 1),
  suggestions JSONB,
  generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CHECK (period_end > period_start)
);
```

**Note**: 这些表是可选的，仅用于持久化缓存。如果不需要持久化缓存，可以仅使用客户端内存缓存。

