import { LocalChartService, LocalChartData } from './localChartService';
import { ChartConfigFactory } from '../chart/config/ChartConfigFactory';
import { OfflineDataManager, OfflineDataType } from './offlineDataManager';
import { OfflineModeManager, OfflineMode } from './offlineModeManager';
import hilog from '@ohos.hilog';

/**
 * 离线AI策略接口
 */
export interface OfflineAIStrategy {
  name: string;
  description: string;
  canHandle(data: LocalChartData): boolean;
  generateRecommendation(data: LocalChartData): Promise<any>;
  generateConfig(data: LocalChartData, chartType?: string): Promise<any>;
}

/**
 * 离线AI响应接口
 */
export interface OfflineAIResponse {
  success: boolean;
  recommendation?: {
    chartType: string;
    confidence: number;
    reason: string;
  };
  config?: any;
  fallbackUsed: boolean;
  message: string;
  processingTime: number;
}

/**
 * 数据模式识别结果
 */
export interface DataPattern {
  type: 'time_series' | 'categorical' | 'numerical' | 'mixed';
  hasTimeColumn: boolean;
  hasCategories: boolean;
  numericColumns: number[];
  categoryColumns: number[];
  trend?: 'increasing' | 'decreasing' | 'stable' | 'fluctuating';
  seasonality?: boolean;
  outliers?: number[];
}

/**
 * 离线AI服务
 * 提供无需网络的智能图表推荐和配置生成
 */
export class OfflineAIService {
  private static instance: OfflineAIService | null = null;
  private static readonly TAG = 'OfflineAIService';
  private static readonly DOMAIN = 0xFF04;

  private localChartService: LocalChartService;
  private chartFactory: ChartConfigFactory;
  private dataManager: OfflineDataManager;
  private offlineMode: OfflineModeManager;
  private strategies: Map<string, OfflineAIStrategy> = new Map();

  private constructor() {
    this.localChartService = LocalChartService.getInstance();
    this.chartFactory = ChartConfigFactory.getInstance();
    this.dataManager = OfflineDataManager.getInstance();
    this.offlineMode = OfflineModeManager.getInstance();
    this.initializeStrategies();
  }

  /**
   * 获取单例实例
   */
  public static getInstance(): OfflineAIService {
    if (!OfflineAIService.instance) {
      OfflineAIService.instance = new OfflineAIService();
    }
    return OfflineAIService.instance;
  }

  /**
   * 初始化离线AI策略
   */
  private initializeStrategies(): void {
    // 时间序列策略
    this.strategies.set('time_series', {
      name: '时间序列分析',
      description: '专门处理时间序列数据的图表推荐',
      canHandle: (data: LocalChartData) => this.isTimeSeriesData(data),
      generateRecommendation: async (data: LocalChartData) => this.generateTimeSeriesRecommendation(data),
      generateConfig: async (data: LocalChartData, chartType?: string) => this.generateTimeSeriesConfig(data, chartType)
    });

    // 分类数据策略
    this.strategies.set('categorical', {
      name: '分类数据分析',
      description: '处理分类数据的图表推荐',
      canHandle: (data: LocalChartData) => this.isCategoricalData(data),
      generateRecommendation: async (data: LocalChartData) => this.generateCategoricalRecommendation(data),
      generateConfig: async (data: LocalChartData, chartType?: string) => this.generateCategoricalConfig(data, chartType)
    });

    // 数值比较策略
    this.strategies.set('numerical', {
      name: '数值比较分析',
      description: '处理数值比较的图表推荐',
      canHandle: (data: LocalChartData) => this.isNumericalData(data),
      generateRecommendation: async (data: LocalChartData) => this.generateNumericalRecommendation(data),
      generateConfig: async (data: LocalChartData, chartType?: string) => this.generateNumericalConfig(data, chartType)
    });

    // 默认策略
    this.strategies.set('default', {
      name: '通用数据分析',
      description: '通用数据分析和图表推荐',
      canHandle: () => true,
      generateRecommendation: async (data: LocalChartData) => this.generateDefaultRecommendation(data),
      generateConfig: async (data: LocalChartData, chartType?: string) => this.generateDefaultConfig(data, chartType)
    });

    hilog.info(OfflineAIService.DOMAIN, OfflineAIService.TAG,
      `AI strategies initialized: ${this.strategies.size}`);
  }

  /**
   * 检测是否为时间序列数据
   */
  private isTimeSeriesData(data: LocalChartData): boolean {
    try {
      // 检查是否有日期/时间列
      for (let i = 0; i < data.headers.length; i++) {
        const header = data.headers[i].toLowerCase();
        if (header.includes('时间') || header.includes('日期') || header.includes('date') ||
            header.includes('time') || header.includes('月') || header.includes('年')) {
          return true;
        }
      }

      // 检查数据内容是否包含时间格式
      if (data.rows.length > 0) {
        const firstRow = data.rows[0];
        for (const cell of firstRow) {
          if (/\d{4}[-/]\d{1,2}[-/]\d{1,2}/.test(cell) || /\d{1,2}月/.test(cell)) {
            return true;
          }
        }
      }

      return false;
    } catch (error) {
      hilog.error(OfflineAIService.DOMAIN, OfflineAIService.TAG,
        `Error checking time series data: ${error}`);
      return false;
    }
  }

  /**
   * 检测是否为分类数据
   */
  private isCategoricalData(data: LocalChartData): boolean {
    try {
      // 如果有明确的分类列
      const uniqueValuesRatio = this.calculateUniqueValuesRatio(data);
      return uniqueValuesRatio < 0.5; // 唯一值比例小于50%认为是分类数据
    } catch (error) {
      return false;
    }
  }

  /**
   * 检测是否为数值数据
   */
  private isNumericalData(data: LocalChartData): boolean {
    try {
      let numericColumns = 0;
      const totalColumns = data.headers.length;

      for (let i = 0; i < data.headers.length; i++) {
        let numericCount = 0;
        for (const row of data.rows) {
          if (row[i] && !isNaN(Number(row[i]))) {
            numericCount++;
          }
        }
        if (numericCount / data.rows.length > 0.8) { // 80%以上是数字
          numericColumns++;
        }
      }

      return numericColumns >= 2 && numericColumns / totalColumns > 0.5;
    } catch (error) {
      return false;
    }
  }

  /**
   * 计算唯一值比例
   */
  private calculateUniqueValuesRatio(data: LocalChartData): number {
    if (data.rows.length === 0) return 1;

    const columnRatios: number[] = [];

    for (let colIndex = 0; colIndex < data.headers.length; colIndex++) {
      const uniqueValues = new Set<string>();
      for (const row of data.rows) {
        if (row[colIndex]) {
          uniqueValues.add(row[colIndex]);
        }
      }
      columnRatios.push(uniqueValues.size / data.rows.length);
    }

    return Math.max(...columnRatios);
  }

  /**
   * 生成时间序列推荐
   */
  private async generateTimeSeriesRecommendation(data: LocalChartData): Promise<any> {
    return {
      chartType: 'line',
      confidence: 0.85,
      reason: '检测到时间序列数据，推荐使用折线图展示趋势变化',
      alternatives: ['area', 'bar'],
      features: ['trend_analysis', 'seasonality_detection']
    };
  }

  /**
   * 生成时间序列配置
   */
  private async generateTimeSeriesConfig(data: LocalChartData, chartType?: string): Promise<any> {
    const type = chartType || 'line';
    return this.chartFactory.createChartConfig(data, type);
  }

  /**
   * 生成分类数据推荐
   */
  private async generateCategoricalRecommendation(data: LocalChartData): Promise<any> {
    const columnCount = data.headers.length;
    const rowCount = data.rows.length;

    if (columnCount === 2) {
      return {
        chartType: 'pie',
        confidence: 0.8,
        reason: '检测到分类数据，推荐使用饼图展示比例关系',
        alternatives: ['bar', 'donut']
      };
    } else {
      return {
        chartType: 'bar',
        confidence: 0.75,
        reason: '多列分类数据，推荐使用柱状图进行对比',
        alternatives: ['column', 'radar']
      };
    }
  }

  /**
   * 生成分类数据配置
   */
  private async generateCategoricalConfig(data: LocalChartData, chartType?: string): Promise<any> {
    const type = chartType || 'bar';
    return this.chartFactory.createChartConfig(data, type);
  }

  /**
   * 生成数值比较推荐
   */
  private async generateNumericalRecommendation(data: LocalChartData): Promise<any> {
    const numericColumns = this.countNumericColumns(data);

    if (numericColumns >= 3) {
      return {
        chartType: 'scatter',
        confidence: 0.7,
        reason: '多列数值数据，推荐使用散点图探索相关性',
        alternatives: ['heatmap', 'bubble']
      };
    } else {
      return {
        chartType: 'bar',
        confidence: 0.8,
        reason: '数值比较数据，推荐使用柱状图清晰展示对比',
        alternatives: ['line', 'column']
      };
    }
  }

  /**
   * 生成数值比较配置
   */
  private async generateNumericalConfig(data: LocalChartData, chartType?: string): Promise<any> {
    const type = chartType || 'bar';
    return this.chartFactory.createChartConfig(data, type);
  }

  /**
   * 生成默认推荐
   */
  private async generateDefaultRecommendation(data: LocalChartData): Promise<any> {
    const columnCount = data.headers.length;
    const rowCount = data.rows.length;

    if (columnCount === 2 && rowCount <= 10) {
      return {
        chartType: 'pie',
        confidence: 0.6,
        reason: '默认推荐：少量二维数据适合饼图展示',
        alternatives: ['bar', 'donut']
      };
    } else {
      return {
        chartType: 'bar',
        confidence: 0.65,
        reason: '默认推荐：通用柱状图适合大多数数据类型',
        alternatives: ['line', 'column']
      };
    }
  }

  /**
   * 生成默认配置
   */
  private async generateDefaultConfig(data: LocalChartData, chartType?: string): Promise<any> {
    const type = chartType || 'bar';
    return this.chartFactory.createChartConfig(data, type);
  }

  /**
   * 统计数值列数量
   */
  private countNumericColumns(data: LocalChartData): number {
    let count = 0;
    for (let i = 0; i < data.headers.length; i++) {
      let numericCount = 0;
      for (const row of data.rows) {
        if (row[i] && !isNaN(Number(row[i]))) {
          numericCount++;
        }
      }
      if (numericCount / data.rows.length > 0.8) {
        count++;
      }
    }
    return count;
  }

  /**
   * 分析数据模式
   */
  public analyzeDataPattern(data: LocalChartData): DataPattern {
    const pattern: DataPattern = {
      type: 'mixed',
      hasTimeColumn: this.isTimeSeriesData(data),
      hasCategories: this.isCategoricalData(data),
      numericColumns: [],
      categoryColumns: []
    };

    // 分析列类型
    for (let i = 0; i < data.headers.length; i++) {
      let numericCount = 0;
      for (const row of data.rows) {
        if (row[i] && !isNaN(Number(row[i]))) {
          numericCount++;
        }
      }

      if (numericCount / data.rows.length > 0.8) {
        pattern.numericColumns.push(i);
      } else {
        pattern.categoryColumns.push(i);
      }
    }

    // 确定主要数据类型
    if (pattern.hasTimeColumn) {
      pattern.type = 'time_series';
    } else if (pattern.categoryColumns.length > pattern.numericColumns.length) {
      pattern.type = 'categorical';
    } else if (pattern.numericColumns.length > 0) {
      pattern.type = 'numerical';
    }

    return pattern;
  }

  /**
   * 生成离线AI推荐
   */
  public async generateOfflineRecommendation(data: LocalChartData): Promise<OfflineAIResponse> {
    const startTime = Date.now();
    const config = this.offlineMode.getConfig();

    // 检查是否启用离线AI
    if (!config.enableOfflineAI || config.mode === OfflineMode.ONLINE_PREFERRED) {
      return {
        success: false,
        fallbackUsed: true,
        message: '离线AI功能未启用，使用在线服务',
        processingTime: Date.now() - startTime
      };
    }

    try {
      hilog.info(OfflineAIService.DOMAIN, OfflineAIService.TAG,
        'Generating offline AI recommendation');

      // 选择合适的策略
      let selectedStrategy: OfflineAIStrategy | null = null;
      for (const [name, strategy] of this.strategies.entries()) {
        if (strategy.canHandle(data)) {
          selectedStrategy = strategy;
          hilog.debug(OfflineAIService.DOMAIN, OfflineAIService.TAG,
            `Selected AI strategy: ${name}`);
          break;
        }
      }

      if (!selectedStrategy) {
        selectedStrategy = this.strategies.get('default')!;
      }

      // 生成推荐
      const recommendation = await selectedStrategy.generateRecommendation(data);

      // 保存到离线数据中
      await this.dataManager.storeOfflineData(
        OfflineDataType.AI_RESPONSE,
        `AI推荐_${Date.now()}`,
        recommendation,
        ['ai', 'recommendation'],
        { strategy: selectedStrategy.name, dataSize: data.rows.length }
      );

      const processingTime = Date.now() - startTime;

      hilog.info(OfflineAIService.DOMAIN, OfflineAIService.TAG,
        `Offline recommendation generated in ${processingTime}ms`);

      return {
        success: true,
        recommendation,
        fallbackUsed: false,
        message: `使用${selectedStrategy.name}策略生成推荐`,
        processingTime
      };

    } catch (error) {
      hilog.error(OfflineAIService.DOMAIN, OfflineAIService.TAG,
        `Failed to generate offline recommendation: ${error}`);

      return {
        success: false,
        fallbackUsed: true,
        message: `离线AI推荐失败: ${error}，使用默认推荐`,
        processingTime: Date.now() - startTime
      };
    }
  }

  /**
   * 生成离线图表配置
   */
  public async generateOfflineChartConfig(
    data: LocalChartData,
    chartType?: string
  ): Promise<OfflineAIResponse> {
    const startTime = Date.now();
    const config = this.offlineMode.getConfig();

    // 检查是否启用离线AI
    if (!config.enableOfflineAI || config.mode === OfflineMode.ONLINE_PREFERRED) {
      return {
        success: false,
        fallbackUsed: true,
        message: '离线AI功能未启用，使用在线服务',
        processingTime: Date.now() - startTime
      };
    }

    try {
      hilog.info(OfflineAIService.DOMAIN, OfflineAIService.TAG,
        'Generating offline chart config');

      // 选择合适的策略
      let selectedStrategy: OfflineAIStrategy | null = null;
      for (const [name, strategy] of this.strategies.entries()) {
        if (strategy.canHandle(data)) {
          selectedStrategy = strategy;
          break;
        }
      }

      if (!selectedStrategy) {
        selectedStrategy = this.strategies.get('default')!;
      }

      // 生成配置
      const chartConfig = await selectedStrategy.generateConfig(data, chartType);

      // 保存到离线数据中
      await this.dataManager.storeOfflineData(
        OfflineDataType.CHART_CONFIG,
        `图表配置_${Date.now()}`,
        chartConfig,
        ['chart', 'config'],
        { strategy: selectedStrategy.name, chartType: chartType || 'auto' }
      );

      const processingTime = Date.now() - startTime;

      hilog.info(OfflineAIService.DOMAIN, OfflineAIService.TAG,
        `Offline chart config generated in ${processingTime}ms`);

      return {
        success: true,
        config: chartConfig,
        fallbackUsed: false,
        message: `使用${selectedStrategy.name}策略生成图表配置`,
        processingTime
      };

    } catch (error) {
      hilog.error(OfflineAIService.DOMAIN, OfflineAIService.TAG,
        `Failed to generate offline chart config: ${error}`);

      return {
        success: false,
        fallbackUsed: true,
        message: `离线配置生成失败: ${error}，使用默认配置`,
        processingTime: Date.now() - startTime
      };
    }
  }

  /**
   * 获取离线AI统计信息
   */
  public getOfflineAIStats(): {
    availableStrategies: number;
    isEnabled: boolean;
    offlineMode: OfflineMode;
    recentRecommendations: number;
  } {
    const recentTime = Date.now() - (24 * 60 * 60 * 1000); // 24小时前
    const recentRecommendations = this.dataManager.queryOfflineData({
      type: OfflineDataType.AI_RESPONSE,
      startTime: recentTime,
      limit: 100
    }).length;

    return {
      availableStrategies: this.strategies.size,
      isEnabled: this.offlineMode.getConfig().enableOfflineAI,
      offlineMode: this.offlineMode.getConfig().mode,
      recentRecommendations
    };
  }

  /**
   * 注册自定义策略
   */
  public registerStrategy(name: string, strategy: OfflineAIStrategy): void {
    this.strategies.set(name, strategy);
    hilog.info(OfflineAIService.DOMAIN, OfflineAIService.TAG,
      `Custom AI strategy registered: ${name}`);
  }

  /**
   * 移除策略
   */
  public removeStrategy(name: string): boolean {
    if (name === 'default') {
      hilog.warn(OfflineAIService.DOMAIN, OfflineAIService.TAG,
        'Cannot remove default strategy');
      return false;
    }

    const removed = this.strategies.delete(name);
    if (removed) {
      hilog.info(OfflineAIService.DOMAIN, OfflineAIService.TAG,
        `AI strategy removed: ${name}`);
    }
    return removed;
  }

  /**
   * 销毁服务
   */
  public destroy(): void {
    this.strategies.clear();

    if (OfflineAIService.instance === this) {
      OfflineAIService.instance = null;
    }

    hilog.info(OfflineAIService.DOMAIN, OfflineAIService.TAG,
      'Offline AI service destroyed');
  }
}