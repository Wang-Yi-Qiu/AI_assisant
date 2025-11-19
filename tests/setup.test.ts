/**
 * 测试环境配置和通用工具
 * 为HarmonyOS应用提供测试基础设施
 */

// 模拟测试数据
export const MockData = {
  // 销售数据
  salesData: {
    headers: ['月份', '销售额', '利润', '产品数量'],
    rows: [
      ['1月', '12000', '3000', '150'],
      ['2月', '15000', '4000', '180'],
      ['3月', '18000', '5000', '220'],
      ['4月', '14000', '3500', '160'],
      ['5月', '20000', '6000', '250'],
      ['6月', '22000', '7000', '280']
    ]
  },

  // 时间序列数据
  timeSeriesData: {
    headers: ['日期', '温度', '湿度', '降雨量'],
    rows: [
      ['2024-01-01', '22', '65', '0'],
      ['2024-01-02', '24', '70', '2'],
      ['2024-01-03', '19', '80', '15'],
      ['2024-01-04', '18', '85', '20'],
      ['2024-01-05', '21', '75', '5'],
      ['2024-01-06', '25', '60', '0'],
      ['2024-01-07', '23', '68', '1']
    ]
  },

  // 分类数据
  categoryData: {
    headers: ['产品', '销量', '收入', '评分'],
    rows: [
      ['产品A', '1200', '36000', '4.5'],
      ['产品B', '800', '24000', '4.2'],
      ['产品C', '1500', '45000', '4.8'],
      ['产品D', '600', '18000', '3.9'],
      ['产品E', '900', '27000', '4.1']
    ]
  },

  // 散点图数据
  scatterData: {
    headers: ['身高', '体重', '年龄'],
    rows: [
      ['165', '55', '25'],
      ['170', '62', '28'],
      ['175', '70', '30'],
      ['160', '50', '22'],
      ['168', '58', '26'],
      ['172', '65', '29'],
      ['178', '75', '32']
    ]
  }
};

// 测试工具函数
export class TestUtils {
  /**
   * 深度比较两个对象
   */
  static deepEqual(obj1: any, obj2: any): boolean {
    return JSON.stringify(obj1) === JSON.stringify(obj2);
  }

  /**
   * 延迟函数
   */
  static delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 生成随机数
   */
  static randomInt(min: number, max: number): number {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }

  /**
   * 生成随机字符串
   */
  static randomString(length: number): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    for (let i = 0; i < length; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }

  /**
   * 模拟网络延迟
   */
  static async simulateNetworkDelay(): Promise<void> {
    const delay = this.randomInt(100, 1000);
    await this.delay(delay);
  }

  /**
   * 验证ECharts配置格式
   */
  static validateEChartsConfig(config: any): boolean {
    try {
      // 基本结构验证
      if (!config || typeof config !== 'object') {
        return false;
      }

      // 验证必需的属性
      if (!config.series || !Array.isArray(config.series)) {
        return false;
      }

      // 验证系列配置
      for (const series of config.series) {
        if (!series.type || !series.data) {
          return false;
        }
      }

      return true;
    } catch (error) {
      console.error('ECharts配置验证失败:', error);
      return false;
    }
  }

  /**
   * 捕获控制台输出
   */
  static captureConsoleLogs(testFn: () => void): { logs: string[], errors: string[] } {
    const originalLog = console.log;
    const originalError = console.error;
    const logs: string[] = [];
    const errors: string[] = [];

    console.log = (...args: any[]) => {
      logs.push(args.join(' '));
      originalLog.apply(console, args);
    };

    console.error = (...args: any[]) => {
      errors.push(args.join(' '));
      originalError.apply(console, args);
    };

    try {
      testFn();
    } finally {
      console.log = originalLog;
      console.error = originalError;
    }

    return { logs, errors };
  }

  /**
   * 模拟文件系统操作
   */
  static createMockFile(name: string, content: string): { uri: string, content: string } {
    return {
      uri: `mock://files/${name}`,
      content
    };
  }

  /**
   * 验证CSV解析结果
   */
  static validateCSVData(data: any): boolean {
    if (!data || !data.headers || !data.rows) {
      return false;
    }

    if (!Array.isArray(data.headers) || !Array.isArray(data.rows)) {
      return false;
    }

    if (data.headers.length === 0) {
      return false;
    }

    // 验证每行的列数是否匹配表头
    for (const row of data.rows) {
      if (!Array.isArray(row) || row.length !== data.headers.length) {
        return false;
      }
    }

    return true;
  }
}

// 测试断言工具
export class Assert {
  /**
   * 断言相等
   */
  static equal(actual: any, expected: any, message?: string): void {
    if (actual !== expected) {
      throw new Error(message || `Expected ${expected}, but got ${actual}`);
    }
  }

  /**
   * 断言深度相等
   */
  static deepEqual(actual: any, expected: any, message?: string): void {
    if (!TestUtils.deepEqual(actual, expected)) {
      throw new Error(message || `Objects are not deeply equal`);
    }
  }

  /**
   * 断言不为空
   */
  static notNull(value: any, message?: string): void {
    if (value === null || value === undefined) {
      throw new Error(message || 'Value should not be null or undefined');
    }
  }

  /**
   * 断言为真
   */
  static isTrue(value: boolean, message?: string): void {
    if (!value) {
      throw new Error(message || 'Value should be true');
    }
  }

  /**
   * 断言包含
   */
  static contains(array: any[], item: any, message?: string): void {
    if (!array.includes(item)) {
      throw new Error(message || `Array should contain ${item}`);
    }
  }

  /**
   * 断言数组长度
   */
  static arrayLength(array: any[], expectedLength: number, message?: string): void {
    if (array.length !== expectedLength) {
      throw new Error(message || `Expected array length ${expectedLength}, but got ${array.length}`);
    }
  }

  /**
   * 断言抛出异常
   */
  static throws(fn: () => void, expectedError?: string | RegExp, message?: string): void {
    try {
      fn();
      throw new Error(message || 'Expected function to throw an error');
    } catch (error) {
      if (expectedError) {
        if (typeof expectedError === 'string') {
          if (!error.message.includes(expectedError)) {
            throw new Error(message || `Expected error message to contain "${expectedError}"`);
          }
        } else if (expectedError instanceof RegExp) {
          if (!expectedError.test(error.message)) {
            throw new Error(message || `Error message does not match expected pattern`);
          }
        }
      }
    }
  }

  /**
   * 断言数值范围
   */
  static inRange(value: number, min: number, max: number, message?: string): void {
    if (value < min || value > max) {
      throw new Error(message || `Expected value to be between ${min} and ${max}, but got ${value}`);
    }
  }
}

// 性能测试工具
export class PerformanceUtils {
  /**
   * 测量函数执行时间
   */
  static async measureTime<T>(fn: () => Promise<T>): Promise<{ result: T, duration: number }> {
    const start = Date.now();
    const result = await fn();
    const duration = Date.now() - start;
    return { result, duration };
  }

  /**
   * 性能基准测试
   */
  static async benchmark<T>(fn: () => T, iterations: number = 100): Promise<{
    average: number,
    min: number,
    max: number,
    total: number
  }> {
    const times: number[] = [];

    for (let i = 0; i < iterations; i++) {
      const start = Date.now();
      fn();
      const duration = Date.now() - start;
      times.push(duration);
    }

    const total = times.reduce((sum, time) => sum + time, 0);
    const average = total / iterations;
    const min = Math.min(...times);
    const max = Math.max(...times);

    return { average, min, max, total };
  }
}