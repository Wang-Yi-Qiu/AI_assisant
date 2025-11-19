/**
 * 测试运行器
 * 统一执行所有测试套件
 */

import { LocalChartServiceTests } from './LocalChartService.test';
import { ChartConfigFactoryTests } from './ChartConfigFactory.test';

/**
 * 测试结果接口
 */
interface TestResult {
  suite: string;
  passed: boolean;
  duration: number;
  error?: string;
}

/**
 * 测试统计接口
 */
interface TestStats {
  totalSuites: number;
  passedSuites: number;
  totalDuration: number;
  results: TestResult[];
}

/**
 * 测试运行器类
 */
export class TestRunner {
  private results: TestResult[] = [];

  /**
   * 运行单个测试套件
   */
  private async runTestSuite(
    name: string,
    testClass: any,
    methodName: string
  ): Promise<TestResult> {
    console.log(`\n🧪 运行测试: ${name}.${methodName}`);

    const startTime = Date.now();
    let passed = false;
    let error: string | undefined;

    try {
      const instance = new testClass();
      await instance[methodName]();
      passed = true;
      console.log(`✅ ${name}.${methodName} 通过`);
    } catch (err) {
      error = err instanceof Error ? err.message : String(err);
      console.error(`❌ ${name}.${methodName} 失败:`, error);
    }

    const duration = Date.now() - startTime;

    return {
      suite: `${name}.${methodName}`,
      passed,
      duration,
      error
    };
  }

  /**
   * 运行所有测试
   */
  async runAllTests(): Promise<TestStats> {
    console.log('🚀 开始执行自动化测试套件...\n');

    // 测试套件配置
    const testSuites = [
      { name: 'LocalChartService', class: LocalChartServiceTests, methods: ['runAllTests'] },
      { name: 'ChartConfigFactory', class: ChartConfigFactoryTests, methods: ['runAllTests'] }
    ];

    const startTime = Date.now();

    // 执行所有测试套件
    for (const suite of testSuites) {
      for (const method of suite.methods) {
        const result = await this.runTestSuite(suite.name, suite.class, method);
        this.results.push(result);
      }
    }

    const totalDuration = Date.now() - startTime;
    const stats = this.generateStats(totalDuration);

    this.printSummary(stats);

    return stats;
  }

  /**
   * 生成测试统计
   */
  private generateStats(totalDuration: number): TestStats {
    const passedSuites = this.results.filter(r => r.passed).length;
    const failedSuites = this.results.filter(r => !r.passed);

    return {
      totalSuites: this.results.length,
      passedSuites,
      totalDuration,
      results: this.results
    };
  }

  /**
   * 打印测试摘要
   */
  private printSummary(stats: TestStats): void {
    console.log('\n' + '='.repeat(50));
    console.log('📊 测试摘要报告');
    console.log('='.repeat(50));
    console.log(`总测试套件: ${stats.totalSuites}`);
    console.log(`✅ 通过: ${stats.passedSuites}`);
    console.log(`❌ 失败: ${stats.totalSuites - stats.passedSuites}`);
    console.log(`⏱️  总耗时: ${stats.totalDuration}ms`);

    // 显示失败的测试详情
    const failedResults = stats.results.filter(r => !r.passed);
    if (failedResults.length > 0) {
      console.log('\n❌ 失败的测试:');
      failedResults.forEach(result => {
        console.log(`  • ${result.suite}`);
        console.log(`    错误: ${result.error}`);
      });
    }

    // 显示通过的测试
    const passedResults = stats.results.filter(r => r.passed);
    if (passedResults.length > 0) {
      console.log('\n✅ 通过的测试:');
      passedResults.forEach(result => {
        console.log(`  • ${result.suite} (${result.duration}ms)`);
      });
    }

    console.log('='.repeat(50));

    if (stats.passedSuites === stats.totalSuites) {
      console.log('🎉 所有测试通过！');
    } else {
      console.log('⚠️  部分测试失败，请检查上述错误信息');
    }
  }

  /**
   * 运行特定测试套件
   */
  async runSpecificTest(suiteName: string): Promise<TestStats> {
    const startTime = Date.now();

    switch (suiteName.toLowerCase()) {
      case 'localchartservice':
        const localServiceResult = await this.runTestSuite(
          'LocalChartService',
          LocalChartServiceTests,
          'runAllTests'
        );
        this.results.push(localServiceResult);
        break;

      case 'chartconfigfactory':
        const factoryResult = await this.runTestSuite(
          'ChartConfigFactory',
          ChartConfigFactoryTests,
          'runAllTests'
        );
        this.results.push(factoryResult);
        break;

      default:
        throw new Error(`未知的测试套件: ${suiteName}`);
    }

    const totalDuration = Date.now() - startTime;
    const stats = this.generateStats(totalDuration);
    this.printSummary(stats);

    return stats;
  }

  /**
   * 生成测试报告（JSON格式）
   */
  generateTestReport(): string {
    const stats = this.generateStats(this.results.reduce((sum, r) => sum + r.duration, 0));

    const report = {
      timestamp: new Date().toISOString(),
      summary: {
        totalSuites: stats.totalSuites,
        passedSuites: stats.passedSuites,
        failedSuites: stats.totalSuites - stats.passedSuites,
        totalDuration: stats.totalDuration,
        successRate: Math.round((stats.passedSuites / stats.totalSuites) * 100)
      },
      results: this.results.map(r => ({
        suite: r.suite,
        passed: r.passed,
        duration: r.duration,
        error: r.error || null
      }))
    };

    return JSON.stringify(report, null, 2);
  }

  /**
   * 清空测试结果
   */
  clearResults(): void {
    this.results = [];
  }
}

/**
 * 主函数 - 命令行入口
 */
export async function main(args: string[] = []): Promise<void> {
  const runner = new TestRunner();

  try {
    if (args.length > 0) {
      // 运行指定的测试套件
      console.log(`运行指定测试套件: ${args.join(', ')}`);
      await runner.runSpecificTest(args[0]);
    } else {
      // 运行所有测试
      await runner.runAllTests();
    }

    // 生成测试报告文件
    const report = runner.generateTestReport();
    console.log('\n📄 测试报告已生成');

  } catch (error) {
    console.error('测试运行失败:', error);
    process.exit(1);
  }
}

// 如果直接运行此文件，执行测试
if (require.main === module) {
  main(process.argv.slice(2));
}