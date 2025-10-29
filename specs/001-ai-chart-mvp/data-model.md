# Data Model — AI 可视化最小闭环（Qwen 模型）

## Entities

### User
- Fields: id (uuid), email (text), createdAt (timestamp)
- Notes: 来自 Supabase Auth，前端只持短期 token。

### Dataset
- Fields: id (uuid), ownerId (uuid), name (text), createdAt (timestamp), size (int)
- Validation: size 限制（例如 ≤ 10MB）；文件类型（CSV/JSON/文本）

### ChartRecord
- Fields: id (uuid), ownerId (uuid), title (text), type (text), createdAt (timestamp), chartConfig (jsonb)
- Validation: chartConfig 必须符合 chartConfig.schema.json；RLS owner 访问控制

## Relationships
- User 1—N Dataset
- User 1—N ChartRecord
- ChartRecord 可引用 Dataset（可选，保留数据来源）

## Validation Rules
- 输入数据：上传前类型与大小检查；文本输入长度限制
- 模型输出：对 ECharts 配置进行 JSON Schema 校验；失败则降级模板

## RLS Policies (Supabase)

```sql
-- Enable RLS on charts table
ALTER TABLE charts ENABLE ROW LEVEL SECURITY;

-- Users can only see their own charts
CREATE POLICY charts_select_own ON charts FOR SELECT
  USING (auth.uid() = user_id);

-- Users can only insert their own charts
CREATE POLICY charts_insert_own ON charts FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```
