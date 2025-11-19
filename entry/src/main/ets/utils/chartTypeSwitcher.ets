/**
 * 图表类型切换工具：支持折线图、柱状图、饼图、散点图之间的切换
 * @module chartTypeSwitcher
 */

import { ChartConfig, EChartsSeriesItem as EChartsSeries } from './aiService';
import { AppError, ErrorCode } from './errorHandler';

/**
 * 支持的图表类型
 */
export type ChartType = 'line' | 'bar' | 'pie' | 'scatter';

/**
 * 图表类型显示名称映射
 */
export const CHART_TYPE_NAMES: Record<ChartType, string> = {
  'line': '折线图',
  'bar': '柱状图',
  'pie': '饼图',
  'scatter': '散点图'
};

/**
 * 获取支持的图表类型列表
 * @returns ChartType[] 图表类型列表
 */
export function getSupportedChartTypes(): ChartType[] {
  return ['line', 'bar', 'pie', 'scatter'];
}

/**
 * 获取图表类型显示名称
 * @param type 图表类型
 * @returns string 显示名称
 */
export function getChartTypeName(type: ChartType): string {
  return CHART_TYPE_NAMES[type] || type;
}

/**
 * 检查数据是否适合指定的图表类型
 * @param config 当前图表配置
 * @param targetType 目标图表类型
 * @returns boolean 是否兼容
 */
export function isCompatibleWithChartType(config: ChartConfig, targetType: ChartType): boolean {
  if (!config || !config.series || config.series.length === 0) {
    return false;
  }

  const firstSeries = config.series[0];
  if (!firstSeries || !firstSeries.data) {
    return false;
  }

  const data = firstSeries.data;
  const dataLength = Array.isArray(data) ? data.length : 0;

  // 检查数据点数量
  switch (targetType) {
    case 'line':
      // 折线图需要至少2个数据点
      return dataLength >= 2;
    
    case 'bar':
      // 柱状图需要至少1个数据点
      return dataLength >= 1;
    
    case 'pie':
      // 饼图需要至少1个数据点
      return dataLength >= 1;
    
    case 'scatter':
      // 散点图需要至少2个数据点，且需要x、y两个数值维度
      if (dataLength < 2) {
        return false;
      }
      // 检查是否有x、y两个数值维度
      if (Array.isArray(data) && data.length > 0) {
        const firstPoint = data[0];
        if (typeof firstPoint === 'object' && firstPoint !== null) {
          // 检查是否为对象格式的数据点（如 {x: 1, y: 2}）
          const point = firstPoint as Record<string, number | string>;
          const hasX = (point['x'] !== undefined) || (point['value'] !== undefined);
          const hasY = (point['y'] !== undefined) || (point['value'] !== undefined);
          // 如果数据是数组格式 [x, y] 或 [value]，也认为兼容
          if (Array.isArray(firstPoint)) {
            return firstPoint.length >= 2;
          }
          return hasX && hasY;
        } else if (typeof firstPoint === 'number') {
          // 如果数据是数字数组，需要至少2个数值维度（通过xAxis和yAxis判断）
          return true; // 简化处理，假设有xAxis和yAxis配置
        }
      }
      return false;
    
    default:
      return false;
  }
}

/**
 * 自动选择最合适的图表类型
 * @param config 当前图表配置
 * @returns ChartType | null 最合适的图表类型，如果都不兼容则返回null
 */
export function autoSelectChartType(config: ChartConfig): ChartType | null {
  if (!config || !config.series || config.series.length === 0) {
    return null;
  }

  const types: ChartType[] = ['line', 'bar', 'pie', 'scatter'];
  
  // 按优先级尝试每种类型
  for (const type of types) {
    if (isCompatibleWithChartType(config, type)) {
      return type;
    }
  }

  return null;
}

/**
 * 手动复制配置对象的辅助函数
 */
function copyChartConfig(src: ChartConfig): ChartConfig {
  const dest: ChartConfig = {
    series: []
  };
  if (src.title) {
    dest.title = src.title;
  }
  if (src.xAxis) {
    dest.xAxis = src.xAxis;
  }
  if (src.yAxis) {
    dest.yAxis = src.yAxis;
  }
  if (src.tooltip) {
    dest.tooltip = src.tooltip;
  }
  if (src.legend) {
    dest.legend = src.legend;
  }
  if (src.grid) {
    dest.grid = src.grid;
  }
  if (src.series && src.series.length > 0) {
    dest.series = [];
    for (let i = 0; i < src.series.length; i++) {
      const srcSeries = src.series[i];
      const destSeries: EChartsSeries = {
        type: srcSeries.type,
        data: srcSeries.data
      };
      if (srcSeries.name) {
        destSeries.name = srcSeries.name;
      }
      if (srcSeries.itemStyle) {
        destSeries.itemStyle = srcSeries.itemStyle;
      }
      dest.series.push(destSeries);
    }
  }
  return dest;
}

/**
 * 手动复制系列对象的辅助函数
 */
function copySeries(src: EChartsSeries): EChartsSeries {
  const dest: EChartsSeries = {
    type: src.type,
    data: src.data
  };
  if (src.name) {
    dest.name = src.name;
  }
  if (src.itemStyle) {
    dest.itemStyle = src.itemStyle;
  }
  return dest;
}

/**
 * 切换图表类型
 * @param config 当前图表配置
 * @param targetType 目标图表类型
 * @returns ChartConfig 更新后的图表配置
 * @throws {AppError} 当数据不兼容且无法自动选择合适类型时
 */
export function switchChartType(config: ChartConfig, targetType: ChartType): ChartConfig {
  if (!config || !config.series || config.series.length === 0) {
    throw new AppError(
      ErrorCode.CHART_CONFIG_INVALID,
      'Current chart has no valid data',
      '当前图表无数据，无法切换类型'
    );
  }

  // 检查数据兼容性
  if (!isCompatibleWithChartType(config, targetType)) {
    // 尝试自动选择最合适的类型
    const autoType = autoSelectChartType(config);
    if (autoType) {
      // 使用自动选择的类型，但保留原始配置的其他部分
      const newConfig = copyChartConfig(config);
      if (newConfig.series && newConfig.series.length > 0) {
        newConfig.series[0] = copySeries(newConfig.series[0]);
        newConfig.series[0].type = autoType;
      }
      return newConfig;
    } else {
      // 所有类型都不兼容
      throw new AppError(
        ErrorCode.CHART_CONFIG_INVALID,
        'Data is incompatible with all chart types',
        '当前数据无法切换图表类型，请使用重新生成功能'
      );
    }
  }

  // 数据兼容，直接切换类型
  // 保持原始数据的所有字段和值不变，仅修改 series[0].type 字段
  const newConfig: ChartConfig = copyChartConfig(config);
  if (newConfig.series && newConfig.series.length > 0) {
    newConfig.series[0] = copySeries(newConfig.series[0]);
    newConfig.series[0].type = targetType;
  } else {
    throw new AppError(
      ErrorCode.CHART_CONFIG_INVALID,
      'Chart config has no series',
      '当前图表配置无效，无法切换类型'
    );
  }

  return newConfig;
}

/**
 * 验证图表配置的数据完整性
 * @param config 图表配置
 * @returns boolean 数据是否有效
 */
export function validateChartData(config: ChartConfig): boolean {
  if (!config || !config.series || config.series.length === 0) {
    return false;
  }

  const firstSeries = config.series[0];
  if (!firstSeries || !firstSeries.data) {
    return false;
  }

  const data = firstSeries.data;
  if (Array.isArray(data)) {
    return data.length > 0;
  }

  return false;
}

