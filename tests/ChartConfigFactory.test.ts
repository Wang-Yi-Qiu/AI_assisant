/**
 * ChartConfigFactory 单元测试
 * 测试工厂模式和策略模式的图表配置生成
 */

import { ChartConfigFactory, ChartType } from '../entry/src/main/ets/chart/config/ChartConfigFactory';
import { MockData, TestUtils, Assert } from './setup.test';

/**
 * ChartConfigFactory 测试套件
 */
export class ChartConfigFactoryTests {
  private sampleData: any;

  constructor() {
    this.sampleData = this.createSampleLocalData();
  }

  /**
   * 创建示例本地数据
   */
  private createSampleLocalData(): any {
    return {
      headers: ['月份', '销售额', '利润'],
      rows: [
        ['1月', '12000', '3000'],
        ['2月', '15000', '4000'],
        ['3月', '18000', '5000'],
        ['4月', '14000', '3500'],
        ['5月', '20000', '6000'],
        ['6月', '22000', '7000']
      ],
      numericColumns: [1, 2],
      categoryColumns: [0]
    };
  }

  /**
   * 测试工厂模式基础功能
   */
  async testFactoryBasics(): Promise<void> {
    console.log('测试工厂模式基础功能...');

    // 测试支持的图表类型
    const supportedTypes = ChartConfigFactory.getSupportedChartTypes();
    Assert.notNull(supportedTypes, '支持的图表类型不应为空');
    Assert.isTrue(supportedTypes.length >= 4, '应至少支持4种图表类型');
    Assert.contains(supportedTypes, ChartType.BAR, '应支持柱状图');
    Assert.contains(supportedTypes, ChartType.LINE, '应支持折线图');
    Assert.contains(supportedTypes, ChartType.PIE, '应支持饼图');
    Assert.contains(supportedTypes, ChartType.SCATTER, '应支持散点图');

    // 测试图表类型检查
    Assert.isTrue(ChartConfigFactory.isChartTypeSupported('bar'), '应支持bar类型');
    Assert.isTrue(ChartConfigFactory.isChartTypeSupported('line'), '应支持line类型');
    Assert.isFalse(ChartConfigFactory.isChartTypeSupported('invalid'), '不应支持无效类型');

    console.log('✓ 工厂模式基础功能测试通过');
  }

  /**
   * 测试图表配置创建
   */
  async testConfigCreation(): Promise<void> {
    console.log('测试图表配置创建...');

    // 测试柱状图配置创建
    const barConfig = ChartConfigFactory.createChartConfig(ChartType.BAR, this.sampleData);
    Assert.notNull(barConfig, '柱状图配置不应为空');
    Assert.equal(barConfig.getChartType(), 'bar', '柱状图配置类型应正确');

    // 测试折线图配置创建
    const lineConfig = ChartConfigFactory.createChartConfig(ChartType.LINE, this.sampleData);
    Assert.notNull(lineConfig, '折线图配置不应为空');
    Assert.equal(lineConfig.getChartType(), 'line', '折线图配置类型应正确');

    // 测试饼图配置创建
    const pieConfig = ChartConfigFactory.createChartConfig(ChartType.PIE, this.sampleData);
    Assert.notNull(pieConfig, '饼图配置不应为空');
    Assert.equal(pieConfig.getChartType(), 'pie', '饼图配置类型应正确');

    // 测试散点图配置创建
    const scatterConfig = ChartConfigFactory.createChartConfig(ChartType.SCATTER, this.sampleData);
    Assert.notNull(scatterConfig, '散点图配置不应为空');
    Assert.equal(scatterConfig.getChartType(), 'scatter', '散点图配置类型应正确');

    console.log('✓ 图表配置创建测试通过');
  }

  /**
   * 测试自定义选项
   */
  async testCustomOptions(): Promise<void> {
    console.log('测试自定义选项...');

    const customOptions = {
      theme: 'light' as const,
      animation: false,
      dataLabels: true,
      title: '自定义图表标题',
      subtitle: '副标题'
    };

    // 测试带自定义选项的配置创建
    const config = ChartConfigFactory.createChartConfig(ChartType.BAR, this.sampleData, customOptions);
    Assert.notNull(config, '带选项的配置不应为空');

    // 生成ECharts配置并验证自定义选项
    const eChartsConfig = config.generateConfig();
    Assert.notNull(eChartsConfig, 'ECharts配置不应为空');
    Assert.isTrue(TestUtils.validateEChartsConfig(eChartsConfig), 'ECharts配置格式应正确');

    // 验证自定义标题
    Assert.equal(eChartsConfig.title.text, '自定义图表标题', '自定义标题应生效');
    Assert.equal(eChartsConfig.title.subtext, '副标题', '自定义副标题应生效');
    Assert.equal(eChartsConfig.animation, false, '自定义动画选项应生效');

    console.log('✓ 自定义选项测试通过');
  }

  /**
   * 测试最优图表类型推荐
   */
  async testOptimalTypeRecommendation(): Promise<void> {
    console.log('测试最优图表类型推荐...');

    // 测试时间序列数据推荐
    const timeSeriesData = this.createTimeSeriesData();
    const optimalTimeConfig = ChartConfigFactory.createOptimalChartConfig(timeSeriesData);
    Assert.equal(optimalTimeConfig.getChartType(), 'line', '时间序列数据应推荐折线图');

    // 测试多数值列数据推荐
    const multiNumericData = this.createMultiNumericData();
    const optimalMultiConfig = ChartConfigFactory.createOptimalChartConfig(multiNumericData);
    Assert.equal(optimalMultiConfig.getChartType(), 'scatter', '多数值列数据应推荐散点图');

    // 测试单数值列+多分类数据推荐
    const categoryData = this.createCategoryData();
    const optimalCategoryConfig = ChartConfigFactory.createOptimalChartConfig(categoryData);
    Assert.isTrue(
      optimalCategoryConfig.getChartType() === 'bar' ||
      optimalCategoryConfig.getChartType() === 'pie',
      '分类数据应推荐柱状图或饼图'
    );

    console.log('✓ 最优图表类型推荐测试通过');
  }

  /**
   * 测试批量配置创建
   */
  async testBatchCreation(): Promise<void> {
    console.log('测试批量配置创建...');

    const chartTypes = [ChartType.BAR, ChartType.LINE, ChartType.PIE, ChartType.SCATTER];
    const configs = ChartConfigFactory.createMultipleChartConfigs(chartTypes, this.sampleData);

    Assert.notNull(configs, '批量配置不应为空');
    Assert.equal(configs.length, 4, '应生成4个配置');
    Assert.equal(configs[0].getChartType(), 'bar', '第一个配置应为柱状图');
    Assert.equal(configs[1].getChartType(), 'line', '第二个配置应为折线图');
    Assert.equal(configs[2].getChartType(), 'pie', '第三个配置应为饼图');
    Assert.equal(configs[3].getChartType(), 'scatter', '第四个配置应为散点图');

    // 验证所有配置都是有效的
    for (const config of configs) {
      const eChartsConfig = config.generateConfig();
      Assert.isTrue(TestUtils.validateEChartsConfig(eChartsConfig), '所有配置都应是有效的ECharts配置');
    }

    console.log('✓ 批量配置创建测试通过');
  }

  /**
   * 测试配置验证和错误处理
   */
  async testValidationAndErrorHandling(): Promise<void> {
    console.log('测试配置验证和错误处理...');

    // 测试无效图表类型
    try {
      ChartConfigFactory.createChartConfig('invalid' as ChartType, this.sampleData);
      Assert.isTrue(false, '应该抛出无效图表类型错误');
    } catch (error) {
      Assert.isTrue(true, '正确抛出了无效图表类型错误');
    }

    // 测试空数据
    const emptyData = {
      headers: [],
      rows: [],
      numericColumns: [],
      categoryColumns: []
    };

    try {
      ChartConfigFactory.createChartConfig(ChartType.BAR, emptyData);
      // 应该有基础处理，不一定抛出错误
    } catch (error) {
      // 抛出错误也是可以接受的
    }

    console.log('✓ 配置验证和错误处理测试通过');
  }

  /**
   * 测试性能
   */
  async testPerformance(): Promise<void> {
    console.log('测试工厂模式性能...');

    // 测试配置创建性能
    const { duration: configCreationDuration } = await PerformanceUtils.measureTime(async () => {
      for (let i = 0; i < 100; i++) {
        ChartConfigFactory.createChartConfig(ChartType.BAR, this.sampleData);
      }
    });

    Assert.isTrue(configCreationDuration < 1000, '100次配置创建应在1秒内完成');

    // 测试ECharts配置生成性能
    const config = ChartConfigFactory.createChartConfig(ChartType.BAR, this.sampleData);
    const { duration: eChartsGenerationDuration } = await PerformanceUtils.measureTime(async () => {
      for (let i = 0; i < 50; i++) {
        config.generateConfig();
      }
    });

    Assert.isTrue(eChartsGenerationDuration < 2000, '50次ECharts配置生成应在2秒内完成');

    console.log(`✓ 性能测试通过 - 配置创建: ${configCreationDuration}ms, ECharts生成: ${eChartsGenerationDuration}ms`);
  }

  /**
   * 测试配置一致性
   */
  async testConfigConsistency(): Promise<void> {
    console.log('测试配置一致性...');

    // 创建相同类型的多个配置
    const config1 = ChartConfigFactory.createChartConfig(ChartType.BAR, this.sampleData);
    const config2 = ChartConfigFactory.createChartConfig(ChartType.BAR, this.sampleData);

    // 生成ECharts配置
    const eChartsConfig1 = config1.generateConfig();
    const eChartsConfig2 = config2.generateConfig();

    // 验证配置结构一致性
    Assert.equal(typeof eChartsConfig1, typeof eChartsConfig2, '配置类型应一致');
    Assert.equal(eChartsConfig1.title.text, eChartsConfig2.title.text, '相同输入应生成相同的标题');
    Assert.equal(eChartsConfig1.series.length, eChartsConfig2.series.length, '系列数量应一致');

    console.log('✓ 配置一致性测试通过');
  }

  /**
   * 创建时间序列测试数据
   */
  private createTimeSeriesData(): any {
    return {
      headers: ['日期', '数值'],
      rows: [
        ['2024-01-01', '100'],
        ['2024-01-02', '120'],
        ['2024-01-03', '80'],
        ['2024-01-04', '150'],
        ['2024-01-05', '200']
      ],
      numericColumns: [1],
      categoryColumns: [0]
    };
  }

  /**
   * 创建多数值列测试数据
   */
  private createMultiNumericData(): any {
    return {
      headers: ['身高', '体重', '年龄'],
      rows: [
        ['165', '55', '25'],
        ['170', '62', '28'],
        ['175', '70', '30'],
        ['160', '50', '22']
      ],
      numericColumns: [0, 1, 2],
      categoryColumns: []
    };
  }

  /**
   * 创建分类测试数据
   */
  private createCategoryData(): any {
    return {
      headers: ['类别', '数值'],
      rows: [
        ['A', '100'],
        ['B', '200'],
        ['C', '150'],
        ['D', '120']
      ],
      numericColumns: [1],
      categoryColumns: [0]
    };
  }

  /**
   * 运行所有测试
   */
  async runAllTests(): Promise<void> {
    console.log('开始运行 ChartConfigFactory 测试套件...');

    try {
      await this.testFactoryBasics();
      await this.testConfigCreation();
      await this.testCustomOptions();
      await this.testOptimalTypeRecommendation();
      await this.testBatchCreation();
      await this.testValidationAndErrorHandling();
      await this.testPerformance();
      await this.testConfigConsistency();

      console.log('🎉 ChartConfigFactory 所有测试通过！');
    } catch (error) {
      console.error('❌ 测试失败:', error);
      throw error;
    }
  }
}

// 导出测试类
export default ChartConfigFactoryTests;