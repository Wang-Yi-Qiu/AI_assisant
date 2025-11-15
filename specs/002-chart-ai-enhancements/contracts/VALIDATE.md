# API Contract Validation

本文档说明如何验证 API 契约和 Schema 的正确性。

## 验证工具

使用 `spec-kit` 工具进行验证：

```bash
# 验证 OpenAPI 规范
spec-kit validate openapi.yaml

# 验证所有 Schema
spec-kit validate schemas/*.json

# 验证完整契约
spec-kit validate .
```

## 验证内容

### OpenAPI 规范验证

- ✅ 所有路径定义正确
- ✅ 请求/响应 Schema 引用有效
- ✅ 安全方案配置正确
- ✅ 参数定义完整

### Schema 验证

- ✅ `insightSchema.json`: AI洞察响应格式
- ✅ `sampleDataset.schema.json`: 样本数据元数据格式

## 验证步骤

1. **本地验证**（开发阶段）:
   ```bash
   cd specs/002-chart-ai-enhancements/contracts
   spec-kit validate .
   ```

2. **CI 验证**（提交前）:
   - 在 CI 流水线中自动运行验证
   - 验证失败时阻止合并

3. **合约测试**（运行时）:
   - Edge Function 实现必须通过合约测试
   - 测试文件：`supabase/functions/generate_insight/tests/schema_contract.test.ts`

## 注意事项

- Schema 变更需要同步更新实现代码
- 新增字段需要考虑向后兼容性
- 所有 Schema 必须通过 JSON Schema Draft 07 验证

