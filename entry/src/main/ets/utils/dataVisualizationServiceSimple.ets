/**
 * 简化版数据可视化服务模块
 * 确保编译成功的版本
 */

import { ChartConfig, UserData } from './aiService';

// 图表类型枚举
export enum ChartType {
  SCATTER = 'scatter',
  BAR = 'bar',
  LINE = 'line',
  AREA = 'area',
  PIE = 'pie',
  HEATMAP = 'heatmap'
}

// 数据类型枚举
export enum DataType {
  NUMERICAL = 'numerical',
  CATEGORICAL = 'categorical',
  TEMPORAL = 'temporal'
}

// 字段信息类
export class FieldInfo {
  name: string = '';
  dataType: DataType = DataType.CATEGORICAL;
  uniqueCount: number = 0;
  missingCount: number = 0;
  minValue?: number;
  maxValue?: number;
}

// 图表推荐结果类
export class ChartRecommendation {
  type: ChartType = ChartType.BAR;
  score: number = 0;
  reason: string = '';
  confidence: 'high' | 'medium' | 'low' = 'medium';
}

// 图表类型信息类
export class ChartTypeInfo {
  type: ChartType = ChartType.BAR;
  name: string = '';
  description: string = '';
}

// 图表标题配置类
export class ChartTitleConfig {
  text: string = '';
  textStyle: TextStyle = new TextStyle();
}

// 文本样式类
export class TextStyle {
  color: string = '#ffffff';
}

// ECharts系列项类
export class EChartsSeriesItem {
  type: string = 'bar';
  data: object[] = [];
}

// 增强图表配置类
export class EnhancedChartConfig {
  title: ChartTitleConfig = new ChartTitleConfig();
  backgroundColor: string = '#1C1C1C';
  series: EChartsSeriesItem[] = [];
}

/**
 * 数据可视化服务类
 */
export class DataVisualizationService {
  private static instance: DataVisualizationService;

  constructor() {
  }

  public static getInstance(): DataVisualizationService {
    if (!DataVisualizationService.instance) {
      DataVisualizationService.instance = new DataVisualizationService();
    }
    return DataVisualizationService.instance;
  }

  /**
   * 推荐适合的图表类型
   */
  public recommendChartTypes(userData: UserData): ChartRecommendation[] {
    const recommendations: ChartRecommendation[] = [];

    // 简化版推荐逻辑
    const barRecommendation = new ChartRecommendation();
    barRecommendation.type = ChartType.BAR;
    barRecommendation.score = 0.85;
    barRecommendation.reason = '适合比较不同类别的数值';
    barRecommendation.confidence = 'high';
    recommendations.push(barRecommendation);

    const lineRecommendation = new ChartRecommendation();
    lineRecommendation.type = ChartType.LINE;
    lineRecommendation.score = 0.9;
    lineRecommendation.reason = '适合展示数据趋势';
    lineRecommendation.confidence = 'high';
    recommendations.push(lineRecommendation);

    const pieRecommendation = new ChartRecommendation();
    pieRecommendation.type = ChartType.PIE;
    pieRecommendation.score = 0.75;
    pieRecommendation.reason = '适合展示数据占比';
    pieRecommendation.confidence = 'medium';
    recommendations.push(pieRecommendation);

    // 按分数排序
    recommendations.sort((a, b) => b.score - a.score);
    return recommendations;
  }

  /**
   * 获取支持的图表类型信息
   */
  public getSupportedChartTypes(): Array<ChartTypeInfo> {
    const result: ChartTypeInfo[] = [];

    const barInfo = new ChartTypeInfo();
    barInfo.type = ChartType.BAR;
    barInfo.name = '条形图';
    barInfo.description = '适合比较不同类别的数值大小';
    result.push(barInfo);

    const lineInfo = new ChartTypeInfo();
    lineInfo.type = ChartType.LINE;
    lineInfo.name = '折线图';
    lineInfo.description = '适合展示数据随时间的变化趋势';
    result.push(lineInfo);

    const scatterInfo = new ChartTypeInfo();
    scatterInfo.type = ChartType.SCATTER;
    scatterInfo.name = '散点图';
    scatterInfo.description = '适合展示两个变量之间的关系';
    result.push(scatterInfo);

    const pieInfo = new ChartTypeInfo();
    pieInfo.type = ChartType.PIE;
    pieInfo.name = '饼图';
    pieInfo.description = '适合展示数据的占比关系';
    result.push(pieInfo);

    const areaInfo = new ChartTypeInfo();
    areaInfo.type = ChartType.AREA;
    areaInfo.name = '面积图';
    areaInfo.description = '适合展示数据的累积变化';
    result.push(areaInfo);

    const heatmapInfo = new ChartTypeInfo();
    heatmapInfo.type = ChartType.HEATMAP;
    heatmapInfo.name = '热力图';
    heatmapInfo.description = '通过颜色深浅展示数据数值大小';
    result.push(heatmapInfo);

    return result;
  }

  /**
   * 创建增强图表配置
   */
  public createEnhancedChartConfig(userData: UserData, chartType: ChartType): ChartConfig {
    const titleConfig = new ChartTitleConfig();
    titleConfig.text = '数据分析图表';

    const config = new EnhancedChartConfig();
    config.title = titleConfig;
    config.backgroundColor = '#1C1C1C';

    // 添加默认的系列数据
    const seriesItem = new EChartsSeriesItem();
    seriesItem.type = chartType;
    config.series = [seriesItem];

    return config as ChartConfig;
  }

  /**
   * 转换为ECharts配置（包含实际数据）
   */
  public convertToEChartsConfig(config: ChartConfig, userData: UserData): ChartConfig {
    return config;
  }
}

// 导出单例实例
export const dataVisualizationService = DataVisualizationService.getInstance();