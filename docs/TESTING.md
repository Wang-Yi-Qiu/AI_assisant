# 自动化测试指南

## 测试架构概览

本项目采用分层测试架构，确保代码质量和功能稳定性：

```
tests/
├── setup.test.ts          # 测试基础设施和工具
├── LocalChartService.test.ts  # 本地图表服务测试
├── ChartConfigFactory.test.ts # 图表配置工厂测试
├── run-tests.ts           # 测试运行器
└── README.md             # 本文档
```

## 测试类型

### 1. 单元测试 (Unit Tests)
- **LocalChartService**: 测试CSV解析、图表推荐、配置生成
- **ChartConfigFactory**: 测试工厂模式、策略模式、配置生成

### 2. 集成测试 (Integration Tests)
- **数据流测试**: 验证从文件导入到图表生成的完整流程
- **API兼容性测试**: 验证ECharts配置的正确性

### 3. 性能测试 (Performance Tests)
- **基准测试**: 确保核心功能在合理时间内完成
- **内存测试**: 验证大数据量处理的内存使用

## 运行测试

### 命令行方式

```bash
# 运行所有测试
npm run test

# 运行特定测试套件
npm run test:local      # LocalChartService测试
npm run test:factory    # ChartConfigFactory测试

# 生成测试报告
npm run test:report

# 代码覆盖率分析
npm run test:coverage
```

### DevEco Studio集成

1. **创建测试配置文件**
   ```json
   // entry/ohosTest/ets/test/test-config.json
   {
     "package": "com.example.aiassistant",
     "deviceConfig": {
       "type": "phone",
       "apiLevel": 12
     }
   }
   ```

2. **添加测试依赖**
   ```json
   // entry/oh_test/package.json
   {
     "name": "ai-assistant-ohos-tests",
     "dependencies": {
       "@ohos/hypium": "^1.0.0"
     }
   }
   ```

## 测试用例设计原则

### 1. AAA模式
```typescript
// Arrange - 准备测试数据
const testData = MockData.salesData;

// Act - 执行被测试的功能
const result = service.generateChartConfig(testData, 'bar');

// Assert - 验证结果
Assert.notNull(result, '配置不应为空');
Assert.equal(result.type, 'bar', '配置类型应正确');
```

### 2. 边界值测试
```typescript
// 测试空数据
const emptyData = { headers: [], rows: [], numericColumns: [], categoryColumns: [] };
const config = service.generateChartConfig(emptyData, 'bar');

// 测试极大数值
const largeData = { headers: ['A'], rows: [['999999999']], numericColumns: [0], categoryColumns: [] };
const largeConfig = service.generateChartConfig(largeData, 'bar');
```

### 3. 错误处理测试
```typescript
// 测试无效输入
Assert.throws(
  () => service.generateChartConfig(invalidData, 'invalid'),
  'Invalid chart type',
  '应抛出无效图表类型错误'
);
```

## 性能基准

### 1. 响应时间要求
- 图表推荐: < 100ms (单次)
- 配置生成: < 50ms (单个配置)
- ECharts转换: < 30ms

### 2. 内存使用要求
- 处理10,000行数据: < 50MB
- 处理100,000行数据: < 200MB

### 3. 并发性能
- 同时处理10个图表请求: < 1s

## 持续集成 (CI/CD)

### GitHub Actions配置

```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'

    - name: Install dependencies
      run: npm install

    - name: Run tests
      run: npm run test

    - name: Generate coverage report
      run: npm run test:coverage

    - name: Upload coverage
      uses: codecov/codecov-action@v3
```

### 本地测试自动化

```bash
# pre-commit hook
#!/bin/sh
npm run test || exit 1
```

## 测试报告

### 1. HTML报告
访问 `coverage/lcov-report/index.html` 查看详细的覆盖率报告

### 2. JSON报告
```bash
npm run test:report > test-results.json
```

### 3. 控制台输出
```
🧪 运行测试: LocalChartService.runAllTests
✅ LocalChartService.runAllTests 通过
🧪 运行测试: ChartConfigFactory.runAllTests
✅ ChartConfigFactory.runAllTests 通过

==================================================
📊 测试摘要报告
==================================================
总测试套件: 2
✅ 通过: 2
❌ 失败: 0
⏱️  总耗时: 1250ms
🎉 所有测试通过！
```

## 测试最佳实践

### 1. 测试命名约定
```typescript
// 好的命名
async testChartTypeRecommendation(): Promise<void>

// 避免的命名
async test1(): Promise<void>
async testChart(): Promise<void>
```

### 2. 测试数据管理
```typescript
// 使用Mock数据类
export const MockData = {
  salesData: { ... },
  timeSeriesData: { ... }
};

// 避免硬编码测试数据
const badData = [
  ['1月', '12000', '3000'],
  ['2月', '15000', '4000']
];
```

### 3. 断言使用
```typescript
// 好的断言
Assert.notNull(config, '配置不应为空');
Assert.equal(config.type, 'bar', '配置类型应正确');

// 带消息的断言
Assert.isTrue(result.isValid, '数据验证应通过: ' + result.error);
```

## 故障排查

### 1. 测试失败处理
1. 检查控制台输出的详细错误信息
2. 使用调试工具逐步执行测试
3. 验证Mock数据的有效性
4. 检查被测试方法的实现逻辑

### 2. 性能问题排查
1. 使用PerformanceUtils测量执行时间
2. 检查是否有内存泄漏
3. 分析大数据量处理的情况
4. 优化算法复杂度

### 3. CI/CD问题解决
1. 检查环境变量配置
2. 验证依赖包安装
3. 查看GitHub Actions日志
4. 本地复现CI环境

## 测试扩展

### 1. 添加新的测试套件
1. 在`tests/`目录创建新的测试文件
2. 继承`TestUtils`和`Assert`基类
3. 实现测试方法
4. 更新`run-tests.ts`注册新测试

### 2. 集成E2E测试
```typescript
// e2e/ChartE2ETest.ts
export class ChartE2ETest {
  async testCompleteWorkflow(): Promise<void> {
    // 1. 选择文件
    // 2. 解析数据
    // 3. 选择图表类型
    // 4. 生成配置
    // 5. 渲染图表
    // 6. 验证结果
  }
}
```

通过这套完整的测试体系，我们可以确保AI Assistant应用的代码质量和功能稳定性。