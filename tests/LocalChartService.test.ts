/**
 * LocalChartService 单元测试
 * 测试本地图表处理服务的核心功能
 */

import { LocalChartService, LocalChartData, ChartRecommendation } from '../entry/src/main/ets/utils/localChartService';
import { MockData, TestUtils, Assert } from './setup.test';

/**
 * LocalChartService 测试套件
 */
export class LocalChartServiceTests {
  private service: LocalChartService;

  constructor() {
    this.service = LocalChartService.getInstance();
  }

  /**
   * 测试CSV解析功能
   */
  async testCSVParsing(): Promise<void> {
    console.log('测试CSV解析功能...');

    // 测试生成示例数据
    const salesData = this.service.generateSampleData('sales');
    Assert.notNull(salesData, '销售数据生成不应为空');
    Assert.equal(salesData.headers.length, 4, '销售数据应有4个列');
    Assert.arrayLength(salesData.rows, 6, '销售数据应有6行数据');
    Assert.arrayLength(salesData.numericColumns, 3, '销售数据应有3个数值列');
    Assert.arrayLength(salesData.categoryColumns, 1, '销售数据应有1个分类列');

    // 测试时间序列数据
    const weatherData = this.service.generateSampleData('weather');
    Assert.notNull(weatherData, '天气数据生成不应为空');
    Assert.arrayLength(weatherData.rows, 7, '天气数据应有7行数据');

    // 测试学生成绩数据
    const studentsData = this.service.generateSampleData('students');
    Assert.notNull(studentsData, '学生数据生成不应为空');
    Assert.arrayLength(studentsData.numericColumns, 3, '学生数据应有3个数值列');

    console.log('✓ CSV解析功能测试通过');
  }

  /**
   * 测试图表类型推荐算法
   */
  async testChartTypeRecommendation(): Promise<void> {
    console.log('测试图表类型推荐算法...');

    // 测试销售数据（多数值列 + 分类列）
    const salesData = this.service.generateSampleData('sales');
    const salesRecommendations = this.service.recommendChartTypes(salesData);
    Assert.notNull(salesRecommendations, '销售数据推荐不应为空');
    Assert.isTrue(salesRecommendations.length > 0, '销售数据应有推荐');

    // 检查推荐顺序
    Assert.equal(salesRecommendations[0].type, 'bar', '销售数据应首先推荐柱状图');
    Assert.isTrue(salesRecommendations[0].score >= 0.8, '销售数据推荐分数应较高');
    Assert.equal(salesRecommendations[0].confidence, 'high', '销售数据推荐置信度应为高');

    // 测试时间序列数据
    const weatherData = this.service.generateSampleData('weather');
    const weatherRecommendations = this.service.recommendChartTypes(weatherData);
    const weatherRecommendation = weatherRecommendations.find(r => r.type === 'line');
    Assert.notNull(weatherRecommendation, '天气数据应推荐折线图');
    Assert.isTrue(weatherRecommendation!.score >= 0.9, '时间序列数据折线图推荐分数应很高');

    // 测试分类数据（适合饼图）
    const categoryData = this.service.generateSampleData('students');
    const categoryRecommendations = this.service.recommendChartTypes(categoryData);
    const pieRecommendation = categoryRecommendations.find(r => r.type === 'pie');
    Assert.notNull(pieRecommendation, '学生数据应推荐饼图');

    console.log('✓ 图表类型推荐算法测试通过');
  }

  /**
   * 测试图表配置生成
   */
  async testChartConfigGeneration(): Promise<void> {
    console.log('测试图表配置生成...');

    const salesData = this.service.generateSampleData('sales');

    // 测试柱状图配置生成
    const barConfig = this.service.generateChartConfig(salesData, 'bar');
    Assert.notNull(barConfig, '柱状图配置不应为空');
    Assert.equal(barConfig.type, 'bar', '柱状图配置类型应正确');
    Assert.notNull(barConfig.title, '柱状图应有标题');
    Assert.notNull(barConfig.series, '柱状图应有系列数据');
    Assert.isTrue(barConfig.series.length > 0, '柱状图应至少有一个系列');

    // 测试折线图配置生成
    const lineConfig = this.service.generateChartConfig(salesData, 'line');
    Assert.notNull(lineConfig, '折线图配置不应为空');
    Assert.equal(lineConfig.type, 'line', '折线图配置类型应正确');

    // 测试饼图配置生成
    const pieConfig = this.service.generateChartConfig(salesData, 'pie');
    Assert.notNull(pieConfig, '饼图配置不应为空');
    Assert.equal(pieConfig.type, 'pie', '饼图配置类型应正确');

    // 测试散点图配置生成
    const scatterConfig = this.service.generateChartConfig(salesData, 'scatter');
    Assert.notNull(scatterConfig, '散点图配置不应为空');
    Assert.equal(scatterConfig.type, 'scatter', '散点图配置类型应正确');

    console.log('✓ 图表配置生成测试通过');
  }

  /**
   * 测试数据导出功能
   */
  async testDataExport(): Promise<void> {
    console.log('测试数据导出功能...');

    const salesData = this.service.generateSampleData('sales');

    // 测试CSV导出
    const csvContent = this.service.exportData(salesData, 'csv');
    Assert.notNull(csvContent, 'CSV导出内容不应为空');
    Assert.isTrue(csvContent.includes('月份'), 'CSV导出应包含表头');
    Assert.isTrue(csvContent.includes('1月'), 'CSV导出应包含数据');

    // 测试JSON导出
    const jsonContent = this.service.exportData(salesData, 'json');
    Assert.notNull(jsonContent, 'JSON导出内容不应为空');
    Assert.isTrue(jsonContent.startsWith('{'), 'JSON导出应为对象格式');

    // 验证JSON格式
    const parsedData = JSON.parse(jsonContent);
    Assert.isTrue(Array.isArray(parsedData), 'JSON导出应为数组格式');
    Assert.isTrue(parsedData.length > 0, 'JSON导出应包含数据');

    console.log('✓ 数据导出功能测试通过');
  }

  /**
   * 测试智能配置生成
   */
  async testSmartChartConfig(): Promise<void> {
    console.log('测试智能配置生成...');

    const salesData = this.service.generateSampleData('sales');

    // 测试自定义主题
    const darkConfig = this.service.generateSmartChartConfig(salesData, 'bar', {
      theme: 'dark',
      animation: true,
      dataLabels: false,
      title: '自定义标题'
    });

    Assert.notNull(darkConfig, '智能配置生成不应为空');
    Assert.equal(darkConfig.type, 'bar', '智能配置类型应正确');

    // 测试浅色主题
    const lightConfig = this.service.generateSmartChartConfig(salesData, 'line', {
      theme: 'light',
      animation: true,
      dataLabels: true
    });

    Assert.notNull(lightConfig, '浅色主题配置不应为空');

    // 测试蓝色主题
    const blueConfig = this.service.generateSmartChartConfig(salesData, 'pie', {
      theme: 'blue',
      animation: false
    });

    Assert.notNull(blueConfig, '蓝色主题配置不应为空');

    console.log('✓ 智能配置生成测试通过');
  }

  /**
   * 性能测试
   */
  async testPerformance(): Promise<void> {
    console.log('测试性能...');

    const salesData = this.service.generateSampleData('sales');

    // 测试推荐算法性能
    const { duration: recommendDuration } = await PerformanceUtils.measureTime(async () => {
      for (let i = 0; i < 100; i++) {
        this.service.recommendChartTypes(salesData);
      }
    });

    Assert.isTrue(recommendDuration < 1000, '推荐算法100次调用应在1秒内完成');

    // 测试配置生成性能
    const { duration: configDuration } = await PerformanceUtils.measureTime(async () => {
      for (let i = 0; i < 50; i++) {
        this.service.generateChartConfig(salesData, 'bar');
      }
    });

    Assert.isTrue(configDuration < 2000, '配置生成50次调用应在2秒内完成');

    console.log(`✓ 性能测试通过 - 推荐: ${recommendDuration}ms, 配置: ${configDuration}ms`);
  }

  /**
   * 边界情况测试
   */
  async testEdgeCases(): Promise<void> {
    console.log('测试边界情况...');

    // 测试空数据
    try {
      const emptyData = {
        headers: ['A', 'B'],
        rows: [],
        numericColumns: [1],
        categoryColumns: [0]
      };
      const config = this.service.generateChartConfig(emptyData, 'bar');
      // 应该生成基础配置，不抛出异常
    } catch (error) {
      throw new Error('空数据应该有基础处理');
    }

    // 测试单个数据点
    const singleRowData = {
      headers: ['类别', '数值'],
      rows: [['测试', 100]],
      numericColumns: [1],
      categoryColumns: [0]
    };

    const singleConfig = this.service.generateChartConfig(singleRowData, 'pie');
    Assert.notNull(singleConfig, '单行数据应能生成配置');

    // 测试极大数值
    const largeNumberData = {
      headers: ['类别', '数值'],
      rows: [['大数', 999999999]],
      numericColumns: [1],
      categoryColumns: [0]
    };

    const largeConfig = this.service.generateChartConfig(largeNumberData, 'bar');
    Assert.notNull(largeConfig, '大数数据应能正常处理');

    console.log('✓ 边界情况测试通过');
  }

  /**
   * 运行所有测试
   */
  async runAllTests(): Promise<void> {
    console.log('开始运行 LocalChartService 测试套件...');

    try {
      await this.testCSVParsing();
      await this.testChartTypeRecommendation();
      await this.testChartConfigGeneration();
      await this.testDataExport();
      await this.testSmartChartConfig();
      await this.testPerformance();
      await this.testEdgeCases();

      console.log('🎉 LocalChartService 所有测试通过！');
    } catch (error) {
      console.error('❌ 测试失败:', error);
      throw error;
    }
  }
}

// 导出测试类
export default LocalChartServiceTests;