# 测试运行指南

## 运行前端测试

### 使用 DevEco Studio
1. 打开 DevEco Studio
2. 右键点击测试文件或目录
3. 选择 "Run 'Tests'" 或使用快捷键

### 使用命令行
```bash
# 运行所有测试
hvigor test

# 运行特定测试
hvigor test --filter "httpClient"

# 运行测试并生成报告
hvigor test --coverage
```

## 运行后端测试

### Edge Function 测试
```bash
cd supabase/functions

# 运行所有测试
deno test

# 运行特定测试文件
deno test tests/generate_chart_qwen.test.ts

# 运行测试并查看覆盖率
deno test --coverage
```

### 合约测试
```bash
# 验证 API 合约
deno test tests/schema_contract.test.ts

# 测试 JSON Schema 验证
deno test --allow-read tests/
```

## 测试文件结构

```
├── entry/src/test/                    # 前端单元测试
│   ├── utils/                        # 工具类测试
│   │   ├── httpClient.test.ets
│   │   ├── authService.test.ets
│   │   ├── aiService.test.ets
│   │   └── config.test.ets
│   └── pages/                        # 页面组件测试
│       ├── Index.test.ets
│       ├── HomePage.test.ets
│       └── ChartPage.test.ets

├── entry/ohosTest/ets/test/           # UI集成测试
│   ├── runner.test.ets                # 测试运行器
│   └── integration/                   # 集成测试

└── supabase/functions/tests/          # 后端测试
    ├── generate_chart_qwen.test.ts    # Edge Function 测试
    └── schema_contract.test.ts        # 合约测试
```

## 测试覆盖率目标

- **单元测试**: 80%+ 代码覆盖率
- **集成测试**: 覆盖主要用户流程
- **合约测试**: 100% API 接口覆盖

## 测试环境配置

### 前端测试
- 环境变量使用测试配置
- 模拟网络请求和文件系统
- 使用 Hypium 测试框架

### 后端测试
- 使用 Deno 内置测试框架
- 模拟外部 API 调用
- 使用测试数据库（如需要）

## 持续集成

### GitHub Actions 工作流
```yaml
name: Test Suite
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup HarmonyOS SDK
        # 安装 HarmonyOS 开发环境

      - name: Run Frontend Tests
        run: hvigor test --coverage

      - name: Run Backend Tests
        run: |
          cd supabase/functions
          deno test --coverage

      - name: Upload Coverage
        # 上传测试覆盖率报告
```

## 调试测试

### 本地调试
1. 使用 DevEco Studio 调试器
2. 在测试中添加 `console.log` 语句
3. 使用断点调试

### 常见问题
1. **模拟请求失败**: 检查 mock 配置
2. **异步测试超时**: 增加超时时间或使用 Promise
3. **测试环境隔离**: 确保测试之间不共享状态

## 性能测试

### 前端性能测试
- 使用 `performance.now()` 测量执行时间
- 测试内存使用情况
- 验证 UI 响应性

### 后端性能测试
- 测试 API 响应时间
- 并发请求测试
- 内存泄漏检测