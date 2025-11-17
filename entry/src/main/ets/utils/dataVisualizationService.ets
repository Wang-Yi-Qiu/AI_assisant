/**
 * 简化版数据可视化服务模块
 * 基于RawGraphs理念的智能数据可视化工具
 * 支持多种图表类型和智能推荐
 */

import { ChartConfig, UserData, EChartsTitle, EChartsLegend, EChartsGrid, EChartsTooltip } from './aiService';
import { ParsedData } from './fileDataParser';

// 通用对象类型，用于快速修复类型错误
type GenericObject = Record<string, Object | undefined>;
type QuickFix = GenericObject; // 快速修复类型

// 通用对象接口，用于修复所有对象字面量
export interface UniversalObject {
  [key: string]: Object | string | number | boolean | undefined;
}

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
  sampleValues?: object[];
}

// 图表推荐结果类
export class ChartRecommendation {
  type: ChartType = ChartType.BAR;
  score: number = 0;
  reason: string = '';
  confidence: 'high' | 'medium' | 'low' = 'medium';
}

// 图表类型信息接口
export interface ChartTypeInfo {
  type: ChartType;
  name: string;
  description: string;
}

// 图表配置相关接口 - 使用aiService中的ECharts接口
export interface ChartTooltipConfig extends EChartsTooltip {
  backgroundColor?: string;
  textStyle?: TextStyle;
}

export interface ChartLegendConfig extends EChartsLegend {
  textStyle?: TextStyle;
}

export interface TextStyle {
  color: string;
}

export interface ChartGridConfig extends EChartsGrid {
}

export interface ChartTitleConfig extends EChartsTitle {
  textStyle?: TitleTextStyle;
}

export interface TitleTextStyle {
  color: string;
  fontSize: number;
}

// 内联对象类型接口
export interface AxisLabelStyle {
  color: string;
}

export interface ItemStyle {
  color?: string;
}

export interface AreaStyle {
  opacity?: number;
}

export interface InRange {
  color?: string[];
}

export interface TextStyleWithColor {
  color?: string;
}

// ECharts配置对象接口
export interface AxisConfig {
  type: string;
  data?: string[];
  axisLabel?: AxisLabelStyle;
}

export interface SeriesConfig {
  type: string;
  data?: Object[];
  name?: string;
  itemStyle?: ItemStyle;
  showSymbol?: boolean;
  smooth?: boolean;
  fillArea?: boolean;
  areaStyle?: AreaStyle;
  radius?: string;
  stack?: string;
  showSymbol?: boolean;
  symbolSize?: number;
  color?: string;
  roseType?: string;
}

export interface VisualMapConfig {
  min?: number;
  max?: number;
  calculable?: boolean;
  orient?: string;
  left?: string;
  bottom?: string;
  inRange?: InRange;
  textStyle?: TextStyleWithColor;
}

export interface ChartBasicConfig {
  title: EChartsTitle;
  backgroundColor: string;
  tooltip: ChartTooltipConfig;
  legend: ChartLegendConfig;
  grid: ChartGridConfig;
  series: Object[];
}

export interface ChartAdvancedConfig {
  title: ChartTitleConfig;
  backgroundColor: string;
  tooltip: ChartTooltipConfig;
  legend: ChartLegendConfig;
  grid: ChartGridConfig;
  series: Object[];
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
   * 分析数据字段类型
   */
  public analyzeFields(userData: UserData): Map<string, FieldInfo> {
    const fieldInfo: Map<string, FieldInfo> = new Map<string, FieldInfo>();

    try {
      // 尝试解析为CSVData格式
      const csvData = userData as GenericObject;
      let data: Object[] = [];

      if (csvData.data && Array.isArray(csvData.data)) {
        data = csvData.data;
      } else if (Array.isArray(userData)) {
        data = userData;
      } else if (typeof userData === 'object') {
        data = [userData]; // 单个对象
      }

      if (data.length === 0) {
        return fieldInfo;
      }

      // 获取所有字段名
      const fields = Object.keys(data[0]);

      for (const field of fields) {
        const values = data.map(row => {
          const rowRecord = row as GenericObject;
          return rowRecord[field];
        }).filter(val => val !== null && val !== undefined);

        const info = new FieldInfo();
        info.name = field;
        info.dataType = this.detectDataType(values);
        info.uniqueCount = new Set(values).size;
        info.missingCount = data.length - values.length;
        info.sampleValues = values.slice(0, 5);

        // 如果是数值字段，计算最小最大值
        if (info.dataType === DataType.NUMERICAL) {
          const numericValues = values.filter(val => typeof val === 'number') as number[];
          if (numericValues.length > 0) {
            info.minValue = Math.min(...numericValues);
            info.maxValue = Math.max(...numericValues);
          }
        }

        fieldInfo.set(field, info);
      }
    } catch (error) {
      console.error('[DataVisualizationService] 分析字段失败:', error);
    }

    return fieldInfo;
  }

  /**
   * 从ParsedData分析字段类型
   */
  public analyzeFieldsFromParsedData(parsedData: ParsedData): Map<string, FieldInfo> {
    const fieldInfo: Map<string, FieldInfo> = new Map<string, FieldInfo>();

    try {
      const data = parsedData.data;
      if (data.length === 0) {
        return fieldInfo;
      }

      // 使用表头作为字段名
      const fields = parsedData.headers;

      for (const field of fields) {
        const values = data.map(row => {
          const rowRecord = row as GenericObject;
          return rowRecord[field];
        }).filter(val => val !== null && val !== undefined);

        const info = new FieldInfo();
        info.name = field;
        info.dataType = this.detectDataType(values);
        info.uniqueCount = new Set(values).size;
        info.missingCount = data.length - values.length;
        info.sampleValues = values.slice(0, 5);

        // 如果是数值字段，计算最小最大值
        if (info.dataType === DataType.NUMERICAL) {
          const numericValues = values.filter(val => typeof val === 'number') as number[];
          if (numericValues.length > 0) {
            info.minValue = Math.min(...numericValues);
            info.maxValue = Math.max(...numericValues);
          }
        }

        fieldInfo.set(field, info);
      }
    } catch (error) {
      console.error('[DataVisualizationService] 从ParsedData分析字段失败:', error);
    }

    return fieldInfo;
  }

  /**
   * 检测字段数据类型
   */
  private detectDataType(values: Object[]): DataType {
    if (values.length === 0) {
      return DataType.CATEGORICAL;
    }

    // 检查是否为数值型
    const numericCount = values.filter(val => typeof val === 'number' && !isNaN(val)).length;
    if (numericCount / values.length > 0.7) {
      return DataType.NUMERICAL;
    }

    // 检查是否为时间型
    const dateCount = values.filter(val => {
      if (typeof val === 'string' || typeof val === 'number') {
        const date = new Date(val);
        return !isNaN(date.getTime());
      }
      return false;
    }).length;
    if (dateCount / values.length > 0.7) {
      return DataType.TEMPORAL;
    }

    // 默认为分类变量
    return DataType.CATEGORICAL;
  }

  /**
   * 推荐适合的图表类型
   */
  public recommendChartTypes(userData: UserData): ChartRecommendation[] {
    const fieldInfo = this.analyzeFields(userData);
    const recommendations: ChartRecommendation[] = [];
    const numericalFields: FieldInfo[] = [];
    const categoricalFields: FieldInfo[] = [];
    const temporalFields: FieldInfo[] = [];

    // 将Map转换为数组并分类
    for (const info of fieldInfo.values()) {
      if (info.dataType === DataType.NUMERICAL) {
        numericalFields.push(info);
      } else if (info.dataType === DataType.CATEGORICAL) {
        categoricalFields.push(info);
      } else if (info.dataType === DataType.TEMPORAL) {
        temporalFields.push(info);
      }
    }

    // 散点图推荐
    if (numericalFields.length >= 2) {
      const recommendation = new ChartRecommendation();
      recommendation.type = ChartType.SCATTER;
      recommendation.score = 0.9;
      recommendation.reason = '数据包含多个数值字段，适合分析变量间的相关性';
      recommendation.confidence = 'high';
      recommendations.push(recommendation);
    }

    // 条形图推荐
    if (categoricalFields.length >= 1 && numericalFields.length >= 1) {
      const recommendation = new ChartRecommendation();
      recommendation.type = ChartType.BAR;
      recommendation.score = 0.85;
      recommendation.reason = '数据包含分类和数值字段，适合比较不同类别的数值';
      recommendation.confidence = 'high';
      recommendations.push(recommendation);
    }

    // 折线图推荐
    if (temporalFields.length > 0 && numericalFields.length >= 1) {
      const recommendation = new ChartRecommendation();
      recommendation.type = ChartType.LINE;
      recommendation.score = 0.9;
      recommendation.reason = '数据包含时间字段，适合展示时间序列趋势';
      recommendation.confidence = 'high';
      recommendations.push(recommendation);
    }

    // 饼图推荐
    if (categoricalFields.length >= 1 && numericalFields.length >= 1) {
      const categoricalField = categoricalFields[0];
      if (categoricalField.uniqueCount <= 8) {
        const recommendation = new ChartRecommendation();
        recommendation.type = ChartType.PIE;
        recommendation.score = 0.75;
        recommendation.reason = `分类字段包含${categoricalField.uniqueCount}个类别，适合展示占比`;
        recommendation.confidence = 'medium';
        recommendations.push(recommendation);
      }
    }

    // 按分数排序
    recommendations.sort((a, b) => b.score - a.score);
    return recommendations;
  }

  /**
   * 从ParsedData推荐适合的图表类型
   */
  public recommendChartTypesFromParsedData(parsedData: ParsedData): ChartRecommendation[] {
    const fieldInfo = this.analyzeFieldsFromParsedData(parsedData);
    const recommendations: ChartRecommendation[] = [];
    const numericalFields: FieldInfo[] = [];
    const categoricalFields: FieldInfo[] = [];
    const temporalFields: FieldInfo[] = [];

    // 将Map转换为数组并分类
    for (const info of fieldInfo.values()) {
      if (info.dataType === DataType.NUMERICAL) {
        numericalFields.push(info);
      } else if (info.dataType === DataType.CATEGORICAL) {
        categoricalFields.push(info);
      } else if (info.dataType === DataType.TEMPORAL) {
        temporalFields.push(info);
      }
    }

    // 散点图推荐
    if (numericalFields.length >= 2) {
      const recommendation = new ChartRecommendation();
      recommendation.type = ChartType.SCATTER;
      recommendation.score = 0.9;
      recommendation.reason = '数据包含多个数值字段，适合分析变量间的相关性';
      recommendation.confidence = 'high';
      recommendations.push(recommendation);
    }

    // 条形图推荐
    if (categoricalFields.length >= 1 && numericalFields.length >= 1) {
      const recommendation = new ChartRecommendation();
      recommendation.type = ChartType.BAR;
      recommendation.score = 0.85;
      recommendation.reason = '数据包含分类和数值字段，适合比较不同类别的数值';
      recommendation.confidence = 'high';
      recommendations.push(recommendation);
    }

    // 折线图推荐
    if (temporalFields.length > 0 && numericalFields.length >= 1) {
      const recommendation = new ChartRecommendation();
      recommendation.type = ChartType.LINE;
      recommendation.score = 0.9;
      recommendation.reason = '数据包含时间字段，适合展示时间序列趋势';
      recommendation.confidence = 'high';
      recommendations.push(recommendation);
    }

    // 饼图推荐
    if (categoricalFields.length >= 1 && numericalFields.length >= 1) {
      const categoricalField = categoricalFields[0];
      if (categoricalField.uniqueCount <= 8) {
        const recommendation = new ChartRecommendation();
        recommendation.type = ChartType.PIE;
        recommendation.score = 0.75;
        recommendation.reason = `分类字段包含${categoricalField.uniqueCount}个类别，适合展示占比`;
        recommendation.confidence = 'medium';
        recommendations.push(recommendation);
      }
    }

    // 面积图推荐
    if (temporalFields.length > 0 && numericalFields.length >= 1) {
      const recommendation = new ChartRecommendation();
      recommendation.type = ChartType.AREA;
      recommendation.score = 0.8;
      recommendation.reason = '数据包含时间字段，适合展示数据的累积变化';
      recommendation.confidence = 'medium';
      recommendations.push(recommendation);
    }

    // 热力图推荐
    if (categoricalFields.length >= 2 && numericalFields.length >= 1) {
      const recommendation = new ChartRecommendation();
      recommendation.type = ChartType.HEATMAP;
      recommendation.score = 0.7;
      recommendation.reason = '数据包含多个分类字段，适合展示数据矩阵';
      recommendation.confidence = 'medium';
      recommendations.push(recommendation);
    }

    // 按分数排序
    recommendations.sort((a, b) => b.score - a.score);
    return recommendations;
  }

  /**
   * 获取支持的图表类型信息
   */
  public getSupportedChartTypes(): ChartTypeInfo[] {
    const chartTypes: ChartTypeInfo[] = [
      { type: ChartType.BAR, name: '条形图', description: '适合比较不同类别的数值大小' },
      { type: ChartType.LINE, name: '折线图', description: '适合展示数据随时间的变化趋势' },
      { type: ChartType.SCATTER, name: '散点图', description: '适合展示两个变量之间的关系' },
      { type: ChartType.PIE, name: '饼图', description: '适合展示数据的占比关系' },
      { type: ChartType.AREA, name: '面积图', description: '适合展示数据的累积变化' },
      { type: ChartType.HEATMAP, name: '热力图', description: '通过颜色深浅展示数据数值大小' }
    ];
    return chartTypes;
  }

  /**
   * 创建增强图表配置
   */
  public createEnhancedChartConfig(userData: UserData, chartType: ChartType): ChartConfig {
    const fieldInfo = this.analyzeFields(userData);
    const numericalFields: FieldInfo[] = [];
    const categoricalFields: FieldInfo[] = [];
    const temporalFields: FieldInfo[] = [];

    // 将Map转换为数组并分类
    for (const info of fieldInfo.values()) {
      if (info.dataType === DataType.NUMERICAL) {
        numericalFields.push(info);
      } else if (info.dataType === DataType.CATEGORICAL) {
        categoricalFields.push(info);
      } else if (info.dataType === DataType.TEMPORAL) {
        temporalFields.push(info);
      }
    }

    const tooltipConfig: ChartTooltipConfig = {
      trigger: 'item',
      backgroundColor: 'rgba(0, 0, 0, 0.8)',
      textStyle: {
        color: '#fff'
      }
    };

    const legendConfig: ChartLegendConfig = {
      textStyle: {
        color: '#ffffff'
      }
    };

    const gridConfig: ChartGridConfig = {
      left: '3%',
      right: '4%',
      bottom: '3%',
      containLabel: true
    };

    const config: ChartBasicConfig = {
      title: {
        text: this.generateChartTitle(chartType),
        textStyle: {
          color: '#ffffff',
          fontSize: 16
        }
      },
      backgroundColor: '#1C1C1C',
      tooltip: tooltipConfig,
      legend: legendConfig,
      grid: gridConfig,
      series: []
    };

    // 根据图表类型配置ECharts
    switch (chartType) {
      case ChartType.BAR:
        this.configureBarChart(config as ChartConfig, userData, numericalFields, categoricalFields);
        break;
      case ChartType.LINE:
        this.configureLineChart(config as ChartConfig, userData, numericalFields, categoricalFields, temporalFields);
        break;
      case ChartType.SCATTER:
        this.configureScatterChart(config as ChartConfig, userData, numericalFields, categoricalFields);
        break;
      case ChartType.PIE:
        this.configurePieChart(config as ChartConfig, userData, numericalFields, categoricalFields);
        break;
      case ChartType.AREA:
        this.configureAreaChart(config as ChartConfig, userData, numericalFields, categoricalFields, temporalFields);
        break;
      case ChartType.HEATMAP:
        this.configureHeatmapChart(config as ChartConfig, userData, numericalFields, categoricalFields);
        break;
      default:
        this.configureBarChart(config as ChartConfig, userData, numericalFields, categoricalFields);
        break;
    }

    return config as ChartConfig;
  }

  /**
   * 从ParsedData创建增强图表配置
   */
  public createChartConfigFromParsedData(parsedData: ParsedData, chartType: ChartType): ChartConfig {
    const fieldInfo = this.analyzeFieldsFromParsedData(parsedData);
    const numericalFields: FieldInfo[] = [];
    const categoricalFields: FieldInfo[] = [];
    const temporalFields: FieldInfo[] = [];

    // 将Map转换为数组并分类
    for (const info of fieldInfo.values()) {
      if (info.dataType === DataType.NUMERICAL) {
        numericalFields.push(info);
      } else if (info.dataType === DataType.CATEGORICAL) {
        categoricalFields.push(info);
      } else if (info.dataType === DataType.TEMPORAL) {
        temporalFields.push(info);
      }
    }

    const titleConfig: ChartTitleConfig = {
      text: `${this.generateChartTitle(chartType)} - ${parsedData.fileName}`,
      textStyle: {
        color: '#ffffff',
        fontSize: 16
      }
    };

    const tooltipConfig2: ChartTooltipConfig = {
      trigger: 'item',
      backgroundColor: 'rgba(0, 0, 0, 0.8)',
      textStyle: {
        color: '#fff'
      }
    };

    const legendConfig2: ChartLegendConfig = {
      textStyle: {
        color: '#ffffff'
      }
    };

    const gridConfig2: ChartGridConfig = {
      left: '3%',
      right: '4%',
      bottom: '3%',
      containLabel: true
    };

    const config: ChartAdvancedConfig = {
      title: titleConfig,
      backgroundColor: '#1C1C1C',
      tooltip: tooltipConfig2,
      legend: legendConfig2,
      grid: gridConfig2,
      series: []
    };

    // 根据图表类型配置ECharts
    switch (chartType) {
      case ChartType.BAR:
        this.configureBarChartFromParsedData(config as ChartConfig, parsedData, numericalFields, categoricalFields);
        break;
      case ChartType.LINE:
        this.configureLineChartFromParsedData(config as ChartConfig, parsedData, numericalFields, categoricalFields, temporalFields);
        break;
      case ChartType.SCATTER:
        this.configureScatterChartFromParsedData(config as ChartConfig, parsedData, numericalFields, categoricalFields);
        break;
      case ChartType.PIE:
        this.configurePieChartFromParsedData(config as ChartConfig, parsedData, numericalFields, categoricalFields);
        break;
      case ChartType.AREA:
        this.configureAreaChartFromParsedData(config as ChartConfig, parsedData, numericalFields, categoricalFields, temporalFields);
        break;
      case ChartType.HEATMAP:
        this.configureHeatmapChartFromParsedData(config as ChartConfig, parsedData, numericalFields, categoricalFields);
        break;
      default:
        this.configureBarChartFromParsedData(config as ChartConfig, parsedData, numericalFields, categoricalFields);
        break;
    }

    return config as ChartConfig;
  }

  /**
   * 生成图表标题
   */
  private generateChartTitle(chartType: ChartType): string {
    switch (chartType) {
      case ChartType.BAR: return '条形图分析';
      case ChartType.LINE: return '折线图分析';
      case ChartType.SCATTER: return '散点图分析';
      case ChartType.PIE: return '饼图分析';
      case ChartType.AREA: return '面积图分析';
      case ChartType.HEATMAP: return '热力图分析';
      default: return '数据可视化分析';
    }
  }

  /**
   * 配置条形图
   */
  private configureBarChart(config: ChartConfig, userData: UserData, numericalFields: FieldInfo[], categoricalFields: FieldInfo[]): void {
    const xField = categoricalFields.length > 0 ? categoricalFields[0].name : 'category';
    const yField = numericalFields.length > 0 ? numericalFields[0].name : 'value';

    (config as GenericObject).xAxis = {
      type: 'category',
      data: [],
      axisLabel: {
        color: '#ffffff'
      } as AxisLabelStyle
    } as AxisConfig;
    (config as GenericObject).yAxis = {
      type: 'value',
      axisLabel: {
        color: '#ffffff'
      } as AxisLabelStyle
    } as AxisConfig;

    (config as GenericObject).series = [{
      type: 'bar',
      data: []
    } as SeriesConfig];
  }

  /**
   * 配置折线图
   */
  private configureLineChart(config: ChartConfig, userData: UserData, numericalFields: FieldInfo[], categoricalFields: FieldInfo[], temporalFields: FieldInfo[]): void {
    const xField = temporalFields.length > 0 ? temporalFields[0].name : (categoricalFields.length > 0 ? categoricalFields[0].name : 'x');
    const yField = numericalFields.length > 0 ? numericalFields[0].name : 'value';

    (config as GenericObject).xAxis = {
      type: 'category',
      data: [],
      axisLabel: {
        color: '#ffffff'
      } as AxisLabelStyle
    } as AxisConfig;
    (config as GenericObject).yAxis = {
      type: 'value',
      axisLabel: {
        color: '#ffffff'
      } as AxisLabelStyle
    } as AxisConfig;

    (config as GenericObject).series = [{
      type: 'line',
      data: []
    } as SeriesConfig];
  }

  /**
   * 配置散点图
   */
  private configureScatterChart(config: ChartConfig, userData: UserData, numericalFields: FieldInfo[], categoricalFields: FieldInfo[]): void {
    const xField = numericalFields.length >= 2 ? numericalFields[1].name : (categoricalFields.length > 0 ? categoricalFields[0].name : 'x');
    const yField = numericalFields.length >= 1 ? numericalFields[0].name : 'y';

    (config as GenericObject).xAxis = {
      type: 'value',
      axisLabel: {
        color: '#ffffff'
      } as AxisLabelStyle
    } as AxisConfig;
    (config as GenericObject).yAxis = {
      type: 'value',
      axisLabel: {
        color: '#ffffff'
      } as AxisLabelStyle
    } as AxisConfig;

    (config as GenericObject).series = [{
      type: 'scatter',
      data: []
    } as SeriesConfig];
  }

  /**
   * 配置饼图
   */
  private configurePieChart(config: ChartConfig, userData: UserData, numericalFields: FieldInfo[], categoricalFields: FieldInfo[]): void {
    const configObj = config as GenericObject;
    configObj.xAxis = undefined;
    configObj.yAxis = undefined;
    configObj.grid = undefined;

    (config as GenericObject).series = [{
      type: 'pie',
      radius: '50%',
      data: []
    } as SeriesConfig];
  }

  /**
   * 配置面积图
   */
  private configureAreaChart(config: ChartConfig, userData: UserData, numericalFields: FieldInfo[], categoricalFields: FieldInfo[], temporalFields: FieldInfo[]): void {
    this.configureLineChart(config, userData, numericalFields, categoricalFields, temporalFields);

    if (config.series && Array.isArray(config.series)) {
      const seriesArray = (config as GenericObject).series as GenericObject[];
      seriesArray.forEach((serie: GenericObject) => {
        serie.type = 'line';
        serie.areaStyle = {
          opacity: 0.3
        } as AreaStyle;
        serie.stack = 'total';
      });
    }
  }

  /**
   * 配置热力图
   */
  private configureHeatmapChart(config: ChartConfig, userData: UserData, numericalFields: FieldInfo[], categoricalFields: FieldInfo[]): void {
    if (categoricalFields.length < 2 || numericalFields.length < 1) {
      this.configureBarChart(config, userData, numericalFields, categoricalFields);
      return;
    }

    const xField = categoricalFields[0].name;
    const yField = categoricalFields[1].name || (numericalFields[0].name);
    const colorField = numericalFields[0].name;

    (config as GenericObject).xAxis = {
      type: 'category',
      data: [],
      axisLabel: {
        color: '#ffffff'
      } as AxisLabelStyle
    } as AxisConfig;
    (config as GenericObject).yAxis = {
      type: 'category',
      data: [],
      axisLabel: {
        color: '#ffffff'
      } as AxisLabelStyle
    } as AxisConfig;

    (config as GenericObject).visualMap = {
      min: 0,
      max: 100,
      calculable: true,
      orient: 'horizontal',
      left: 'center',
      bottom: '15%',
      textStyle: {
        color: '#ffffff'
      } as TextStyleWithColor
    } as VisualMapConfig;

    (config as GenericObject).series = [{
      type: 'heatmap',
      data: []
    } as SeriesConfig];
  }

  /**
   * 转换为ECharts配置（包含实际数据）
   */
  public convertToEChartsConfig(config: GenericObject, userData: UserData): GenericObject {
    try {
      // 尝试解析为CSVData格式
      let data: object[] = [];

      // 检查userData是否有data属性
      if (userData && typeof userData === 'object' && 'data' in userData) {
        const csvData = userData as GenericObject;
        if (csvData.data && Array.isArray(csvData.data)) {
          data = csvData.data;
        }
      } else if (Array.isArray(userData)) {
        data = userData;
      } else if (typeof userData === 'object') {
        data = [userData]; // 单个对象
      }

      if (data.length === 0) {
        return config;
      }

      // 获取所有字段名
      const fields = Object.keys(data[0]);

      // 根据图表类型填充数据
      if (config.series && Array.isArray(config.series)) {
        config.series.forEach((serie: GenericObject) => {
          switch (serie.type) {
            case 'bar':
            case 'line':
              this.fillBarLineData(serie, data, fields);
              break;
            case 'scatter':
              this.fillScatterData(serie, data, fields);
              break;
            case 'pie':
              this.fillPieData(serie, data, fields);
              break;
            case 'heatmap':
              this.fillHeatmapData(serie, data, fields);
              break;
          }
        });
      }

      // 填充坐标轴数据
      const xAxisConfig = (config as GenericObject).xAxis as GenericObject;
      if (xAxisConfig && xAxisConfig.type === 'category') {
        this.fillXAxisData(config as unknown as GenericObject, data, fields);
      }

      return config;
    } catch (error) {
      console.error('[DataVisualizationService] 转换ECharts配置失败:', error);
      return config;
    }
  }

  /**
   * 填充柱状图和折线图数据
   */
  private fillBarLineData(serie: object, data: object[], fields: string[]): void {
    const xField = fields[0];
    const yField = fields.length > 1 ? fields[1] : fields[0];

    // 如果有分类字段，分组数据
    if (fields.length > 2) {
      const categoryField = fields[2];
      const categorySet = new Set<string>();
      for (const item of data) {
        const dataItem = item as GenericObject;
        categorySet.add(String(dataItem[categoryField]));
      }
      const categories = Array.from(categorySet);

      (serie as GenericObject).data = categories.map(category => {
        const categoryData = data.filter(item => {
          const dataItem = item as GenericObject;
          return dataItem[categoryField] === category;
        });
        return {
          name: category,
          type: (serie as GenericObject).type,
          data: categoryData.map(item => {
            const dataItem = item as GenericObject;
            return dataItem[yField];
          })
        } as SeriesConfig;
      });
    } else {
      (serie as GenericObject).data = data.map(item => {
        const dataItem = item as GenericObject;
        return dataItem[yField];
      });
    }

    const serieRecord = serie as GenericObject;
    if (serieRecord.data && Array.isArray(serieRecord.data) && serieRecord.data.length > 0 && typeof serieRecord.data[0] === 'object') {
      // 数据保持不变
    }
  }

  /**
   * 填充散点图数据
   */
  private fillScatterData(serie: object, data: object[], fields: string[]): void {
    const xField = fields[0];
    const yField = fields.length > 1 ? fields[1] : fields[0];

    (serie as unknown as GenericObject).data = data.map(item => [item[xField], item[yField]]);
  }

  /**
   * 填充饼图数据
   */
  private fillPieData(serie: object, data: object[], fields: string[]): void {
    const nameField = fields[0];
    const valueField = fields.length > 1 ? fields[1] : fields[0];

    (serie as GenericObject).data = data.map(item => ({
      name: String(item[nameField]),
      value: Number(item[valueField])
    } as UniversalObject));
  }

  /**
   * 填充热力图数据
   */
  private fillHeatmapData(serie: object, data: object[], fields: string[]): void {
    // 简化热力图数据填充
    (serie as unknown as GenericObject).data = data.map((item, index) => [
      index % 10,  // x坐标
      Math.floor(index / 10),  // y坐标
      item[fields[0]] || Math.random() * 100  // 数值
    ]);
  }

  /**
   * 填充X轴数据
   */
  private fillXAxisData(config: object, data: object[], fields: string[]): void {
    const xField = fields[0];
    const uniqueValues = new Set<string>();
    data.forEach(item => {
      const value = item[xField];
      if (value !== null && value !== undefined) {
        uniqueValues.add(String(value));
      }
    });
    const xAxisConfig2 = (config as GenericObject).xAxis as GenericObject;
    xAxisConfig2.data = Array.from(uniqueValues);
  }

  /**
   * 从ParsedData配置条形图
   */
  private configureBarChartFromParsedData(config: ChartConfig, parsedData: ParsedData, numericalFields: FieldInfo[], categoricalFields: FieldInfo[]): void {
    const xField = categoricalFields.length > 0 ? categoricalFields[0].name : parsedData.headers[0];
    const yField = numericalFields.length > 0 ? numericalFields[0].name : parsedData.headers[parsedData.headers.length - 1];

    (config as GenericObject).xAxis = {
      type: 'category',
      data: parsedData.data.map(item => String(item[xField])),
      axisLabel: {
        color: '#ffffff',
        rotate: 45
      } as AxisLabelStyle
    } as AxisConfig;
    (config as GenericObject).yAxis = {
      type: 'value',
      axisLabel: {
        color: '#ffffff'
      } as AxisLabelStyle
    } as AxisConfig;

    (config as GenericObject).series = [{
      type: 'bar',
      name: yField,
      data: parsedData.data.map(item => Number(item[yField])),
      itemStyle: {
        color: '#007DFF'
      } as ItemStyle
    } as SeriesConfig];
  }

  /**
   * 从ParsedData配置折线图
   */
  private configureLineChartFromParsedData(config: ChartConfig, parsedData: ParsedData, numericalFields: FieldInfo[], categoricalFields: FieldInfo[], temporalFields: FieldInfo[]): void {
    const xField = temporalFields.length > 0 ? temporalFields[0].name : (categoricalFields.length > 0 ? categoricalFields[0].name : parsedData.headers[0]);
    const yField = numericalFields.length > 0 ? numericalFields[0].name : parsedData.headers[parsedData.headers.length - 1];

    (config as GenericObject).xAxis = {
      type: 'category',
      data: parsedData.data.map(item => String(item[xField])),
      axisLabel: {
        color: '#ffffff',
        rotate: 45
      } as AxisLabelStyle
    } as AxisConfig;
    (config as GenericObject).yAxis = {
      type: 'value',
      axisLabel: {
        color: '#ffffff'
      } as AxisLabelStyle
    } as AxisConfig;

    (config as GenericObject).series = [{
      type: 'line',
      name: yField,
      data: parsedData.data.map(item => Number(item[yField])),
      smooth: true,
      itemStyle: {
        color: '#007DFF'
      } as ItemStyle,
      areaStyle: {
        opacity: 0.1
      } as AreaStyle
    } as SeriesConfig];
  }

  /**
   * 从ParsedData配置散点图
   */
  private configureScatterChartFromParsedData(config: ChartConfig, parsedData: ParsedData, numericalFields: FieldInfo[], categoricalFields: FieldInfo[]): void {
    const xField = numericalFields.length >= 2 ? numericalFields[1].name : (categoricalFields.length > 0 ? categoricalFields[0].name : parsedData.headers[0]);
    const yField = numericalFields.length >= 1 ? numericalFields[0].name : parsedData.headers[parsedData.headers.length - 1];

    (config as GenericObject).xAxis = {
      type: 'value',
      axisLabel: {
        color: '#ffffff'
      } as AxisLabelStyle
    } as AxisConfig;
    (config as GenericObject).yAxis = {
      type: 'value',
      axisLabel: {
        color: '#ffffff'
      } as AxisLabelStyle
    } as AxisConfig;

    (config as GenericObject).series = [{
      type: 'scatter',
      name: `${xField} vs ${yField}`,
      data: parsedData.data.map(item => [item[xField], item[yField]]),
      itemStyle: {
        color: '#007DFF'
      }
    }];
  }

  /**
   * 从ParsedData配置饼图
   */
  private configurePieChartFromParsedData(config: ChartConfig, parsedData: ParsedData, numericalFields: FieldInfo[], categoricalFields: FieldInfo[]): void {
    const configObj = config as GenericObject;
    configObj.xAxis = undefined;
    configObj.yAxis = undefined;
    configObj.grid = undefined;

    const nameField = categoricalFields.length > 0 ? categoricalFields[0].name : parsedData.headers[0];
    const valueField = numericalFields.length > 0 ? numericalFields[0].name : parsedData.headers[parsedData.headers.length - 1];

    (config as GenericObject).series = [{
      type: 'pie',
      radius: '60%',
      center: ['50%', '50%'],
      data: parsedData.data.map(item => ({
        name: item[nameField],
        value: item[valueField]
      })),
      emphasis: {
        itemStyle: {
          shadowBlur: 10,
          shadowOffsetX: 0,
          shadowColor: 'rgba(0, 0, 0, 0.5)'
        }
      }
    }];
  }

  /**
   * 从ParsedData配置面积图
   */
  private configureAreaChartFromParsedData(config: ChartConfig, parsedData: ParsedData, numericalFields: FieldInfo[], categoricalFields: FieldInfo[], temporalFields: FieldInfo[]): void {
    this.configureLineChartFromParsedData(config, parsedData, numericalFields, categoricalFields, temporalFields);

    if (config.series && Array.isArray(config.series)) {
      const seriesArray = (config as GenericObject).series as GenericObject[];
      seriesArray.forEach((serie: GenericObject) => {
        serie.areaStyle = {
          opacity: 0.3
        } as AreaStyle;
        serie.stack = 'total';
      });
    }
  }

  /**
   * 从ParsedData配置热力图
   */
  private configureHeatmapChartFromParsedData(config: ChartConfig, parsedData: ParsedData, numericalFields: FieldInfo[], categoricalFields: FieldInfo[]): void {
    if (categoricalFields.length < 2 || numericalFields.length < 1) {
      this.configureBarChartFromParsedData(config, parsedData, numericalFields, categoricalFields);
      return;
    }

    const xField = categoricalFields[0].name;
    const yField = categoricalFields[1].name || (numericalFields[0].name);
    const colorField = numericalFields[0].name;

    // 获取唯一的X和Y值
    const xValueSet = new Set<string>();
    const yValueSet = new Set<string>();

    for (const item of parsedData.data) {
      xValueSet.add(String(item[xField]));
      yValueSet.add(String(item[yField]));
    }
    const xValues = Array.from(xValueSet);
    const yValues = Array.from(yValueSet);

    // 定义X轴配置
    const xAxisConfig: GenericObject = {
      type: 'category',
      data: xValues,
      axisLabel: {
        color: '#ffffff',
        rotate: 45
      }
    };
    (config as GenericObject).xAxis = xAxisConfig;
    // 定义Y轴配置
    const yAxisConfig: GenericObject = {
      type: 'category',
      data: yValues,
      axisLabel: {
        color: '#ffffff'
      } as AxisLabelStyle
    };
    (config as GenericObject).yAxis = yAxisConfig;

    // 定义视觉映射配置
    const visualMapConfig: GenericObject = {
      min: 0,
      max: 100,
      calculable: true,
      orient: 'horizontal',
      left: 'center',
      bottom: '15%',
      textStyle: {
        color: '#ffffff'
      }
    };
    (config as GenericObject).visualMap = visualMapConfig;

    // 构建热力图数据
    const heatmapData: number[][] = [];
    parsedData.data.forEach(item => {
      const xIndex = xValues.indexOf(item[xField]);
      const yIndex = yValues.indexOf(item[yField]);
      const value = item[colorField] || 0;
      heatmapData.push([xIndex, yIndex, value]);
    });

    // 定义热力图系列配置
    const heatmapSeries: GenericObject = {
      type: 'heatmap',
      data: heatmapData,
      emphasis: {
        itemStyle: {
          shadowBlur: 10,
          shadowColor: 'rgba(0, 0, 0, 0.5)'
        }
      }
    };

    (config as GenericObject).series = [heatmapSeries as SeriesConfig];
  }
}

// 导出单例实例
export const dataVisualizationService = DataVisualizationService.getInstance();