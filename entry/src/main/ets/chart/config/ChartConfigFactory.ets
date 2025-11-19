/**
 * 图表配置工厂 - 工厂模式实现
 * 负责创建和管理不同类型的图表配置
 */

import { BaseChartConfig } from './BaseChartConfig';
import { BarChartConfig } from './BarChartConfig';
import { LineChartConfig } from './LineChartConfig';
import { PieChartConfig } from './PieChartConfig';
import { ScatterChartConfig } from './ScatterChartConfig';
import { LocalChartData } from '../../utils/localChartService';
import { ChartTheme } from './ChartTheme';

// 图表类型枚举
export enum ChartType {
  BAR = 'bar',
  LINE = 'line',
  PIE = 'pie',
  SCATTER = 'scatter'
}

// 图表配置选项接口
export interface ChartConfigOptions {
  theme?: ChartTheme;
  animation?: boolean;
  dataLabels?: boolean;
  title?: string;
  subtitle?: string;
  width?: number;
  height?: number;
  responsive?: boolean;
}

/**
 * 图表配置工厂类
 */
export class ChartConfigFactory {
  // 配置策略注册表
  private static configStrategies: Map<ChartType, typeof BaseChartConfig> = new Map([
    [ChartType.BAR, BarChartConfig],
    [ChartType.LINE, LineChartConfig],
    [ChartType.PIE, PieChartConfig],
    [ChartType.SCATTER, ScatterChartConfig]
  ]);

  /**
   * 创建图表配置
   */
  static createChartConfig(
    chartType: ChartType,
    data: LocalChartData,
    options: ChartConfigOptions = {}
  ): BaseChartConfig {
    const ConfigClass = this.configStrategies.get(chartType);
    if (!ConfigClass) {
      throw new Error(`Unsupported chart type: ${chartType}`);
    }

    return new ConfigClass(data, options);
  }

  /**
   * 批量创建图表配置
   */
  static createMultipleChartConfigs(
    chartTypes: ChartType[],
    data: LocalChartData,
    options: ChartConfigOptions = {}
  ): BaseChartConfig[] {
    return chartTypes.map(type => this.createChartConfig(type, data, options));
  }

  /**
   * 获取支持的图表类型
   */
  static getSupportedChartTypes(): ChartType[] {
    return Array.from(this.configStrategies.keys());
  }

  /**
   * 检查图表类型是否支持
   */
  static isChartTypeSupported(chartType: string): boolean {
    return this.configStrategies.has(chartType as ChartType);
  }

  /**
   * 注册新的图表配置策略
   */
  static registerChartConfig(
    chartType: ChartType,
    configClass: typeof BaseChartConfig
  ): void {
    this.configStrategies.set(chartType, configClass);
  }

  /**
   * 创建最佳匹配的图表配置
   */
  static createOptimalChartConfig(
    data: LocalChartData,
    options: ChartConfigOptions = {}
  ): BaseChartConfig {
    // 分析数据特征并推荐最适合的图表类型
    const recommendedType = this.recommendOptimalChartType(data);
    return this.createChartConfig(recommendedType, data, options);
  }

  /**
   * 推荐最优图表类型（算法增强版）
   */
  private static recommendOptimalChartType(data: LocalChartData): ChartType {
    const { numericColumns, categoryColumns, headers, rows } = data;

    // 数据质量评估
    const dataQuality = this.assessDataQuality(data);

    // 时间序列检测
    const isTimeSeries = categoryColumns.length > 0 &&
      this.detectTimeSeriesData(rows.map(row => row[categoryColumns[0]]));

    // 分类数量评估
    const categoryCount = categoryColumns.length > 0 ?
      new Set(rows.map(row => row[categoryColumns[0]])).size : 0;

    // 决策树算法
    if (numericColumns.length >= 2 && !isTimeSeries) {
      // 多数值列 + 非时间序列 -> 散点图或柱状图
      return ChartType.SCATTER;
    }

    if (numericColumns.length === 1 && categoryColumns.length >= 1) {
      if (isTimeSeries) {
        // 单数值列 + 时间序列 -> 折线图
        return ChartType.LINE;
      } else if (categoryCount <= 8) {
        // 少量分类 -> 饼图
        return ChartType.PIE;
      } else {
        // 多分类 -> 柱状图
        return ChartType.BAR;
      }
    }

    if (numericColumns.length >= 2) {
      // 多数值列 -> 柱状图
      return ChartType.BAR;
    }

    // 默认选择柱状图
    return ChartType.BAR;
  }

  /**
   * 数据质量评估
   */
  private static assessDataQuality(data: LocalChartData): {
    completeness: number;
    variance: number;
    outliers: number;
  } {
    const { rows, numericColumns } = data;

    // 完整性评估
    let totalCells = rows.length * data.headers.length;
    let validCells = 0;
    rows.forEach(row => {
      row.forEach(cell => {
        if (cell && cell.trim() !== '') validCells++;
      });
    });

    const completeness = validCells / totalCells;

    // 方差评估（简化版）
    let variance = 0;
    if (numericColumns.length > 0) {
      const values = rows.map(row => Number(row[numericColumns[0]]) || 0);
      const mean = values.reduce((a, b) => a + b, 0) / values.length;
      variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length;
    }

    return {
      completeness,
      variance,
      outliers: 0 // 简化实现
    };
  }

  /**
   * 时间序列数据检测
   */
  private static detectTimeSeriesData(categoryValues: string[]): boolean {
    // 时间模式检测（增强版）
    const timePatterns = [
      /^\d{4}-\d{1,2}-\d{1,2}$/,          // YYYY-MM-DD
      /^\d{1,2}\/\d{1,2}\/\d{4}$/,          // MM/DD/YYYY
      /^\d{4}年\d{1,2}月\d{1,2}日$/,        // 中文日期
      /^[一二三四五六七八九十]+月\d{1,2}日?$/,  // 中文月份
      /^\d{1,2}月$/,                         // 数字月份
      /^第?[一二三四五六七八九十\d]+[个]?季度?$/, // 季度
      /^周[一二三四五六日天]$/,                 // 星期
      /^\d{1,2}:\d{2}$/,                     // 时间
      /^Phase \d+$/i,                         // 英文阶段
      /^Stage \d+$/i                          // 英文阶段
    ];

    const matchCount = categoryValues.filter(value =>
      timePatterns.some(pattern => pattern.test(value))
    ).length;

    // 超过60%匹配则认为是时间序列
    return (matchCount / categoryValues.length) > 0.6;
  }
}