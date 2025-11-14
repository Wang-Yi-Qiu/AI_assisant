/**
 * 类型守卫和验证工具
 * @module typeGuard
 */

import { ChartConfig, EChartsTitle, EChartsSeriesItem } from './aiService';
import { CSVData } from './aiService';

/**
 * 验证是否为ECharts标题配置
 */
export function isEChartsTitle(obj: unknown): obj is EChartsTitle {
  if (typeof obj !== 'object' || obj === null) {
    return false;
  }

  const title = obj as EChartsTitle;
  return title.text === undefined || typeof title.text === 'string';
}

/**
 * 验证是否为ECharts系列配置
 */
export function isEChartsSeriesItem(obj: unknown): obj is EChartsSeriesItem {
  if (typeof obj !== 'object' || obj === null) {
    return false;
  }

  const series = obj as EChartsSeriesItem;
  return typeof series.type === 'string' && series.type.length > 0;
}

/**
 * 验证是否为完整的ChartConfig
 */
export function isChartConfig(obj: unknown): obj is ChartConfig {
  if (typeof obj !== 'object' || obj === null) {
    return false;
  }

  const config = obj as ChartConfig;

  // 检查基本结构
  if (!Array.isArray(config.series) || config.series.length === 0) {
    return false;
  }

  // 验证title（可选）
  if (config.title !== undefined && !isEChartsTitle(config.title)) {
    return false;
  }

  // 验证每个series项
  return config.series.every(item => isEChartsSeriesItem(item));
}

/**
 * 验证是否为CSVData
 */
export function isCSVData(obj: unknown): obj is CSVData {
  if (typeof obj !== 'object' || obj === null) {
    return false;
  }

  const csv = obj as CSVData;

  return (
    Array.isArray(csv.headers) &&
    csv.headers.every(header => typeof header === 'string') &&
    Array.isArray(csv.data) &&
    csv.data.every(row =>
      typeof row === 'object' &&
      row !== null &&
      Object.values(row).every(value => typeof value === 'string')
    )
  );
}

/**
 * 验证是否为有效的UserData
 */
export function isValidUserData(obj: unknown): obj is string | Record<string, any> | CSVData {
  // 字符串类型
  if (typeof obj === 'string') {
    return obj.length > 0 && obj.length <= 100000; // 限制最大长度
  }

  // 对象类型
  if (typeof obj === 'object' && obj !== null) {
    // 检查是否为CSV数据
    if (isCSVData(obj)) {
      return true;
    }

    // 检查是否为普通对象
    const record = obj as Record<string, any>;
    return Object.keys(record).length <= 100; // 限制键的数量
  }

  return false;
}

/**
 * 安全的类型转换
 */
export function safeCast<T>(
  value: unknown,
  validator: (obj: unknown) => obj is T,
  errorMessage?: string
): T {
  if (validator(value)) {
    return value;
  }

  throw new Error(errorMessage || `类型转换失败: ${typeof value}`);
}

/**
 * 验证并清理字符串
 */
export function validateAndCleanString(str: unknown): string {
  if (typeof str !== 'string') {
    throw new Error('输入必须是字符串');
  }

  if (str.length === 0) {
    throw new Error('输入不能为空');
  }

  if (str.length > 1000000) {
    throw new Error('输入过长，最大支持 1MB');
  }

  // 移除潜在的危险字符（简单的XSS防护）
  return str.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
}

/**
 * 验证图表类型
 */
export function isValidChartType(type: string): boolean {
  const validTypes = [
    'line', 'bar', 'pie', 'scatter', 'area', 'radar',
    'heatmap', 'treemap', 'sunburst', 'funnel', 'gauge'
  ];
  return validTypes.includes(type);
}

/**
 * 验证颜色值
 */
export function isValidColor(color: string): boolean {
  // 简单的颜色验证（十六进制、rgb、rgba、颜色名称）
  const colorRegex = /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$|^rgb\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)$|^rgba\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*[\d.]+\s*\)$|^[a-zA-Z]+$/;
  return colorRegex.test(color);
}

/**
 * 验证数值
 */
export function isValidNumber(value: unknown): value is number {
  return typeof value === 'number' && !isNaN(value) && isFinite(value);
}

/**
 * 验证数值数组
 */
export function isValidNumberArray(arr: unknown): arr is number[] {
  if (!Array.isArray(arr)) {
    return false;
  }

  return arr.every(item => isValidNumber(item));
}

/**
 * 验证字符串数组
 */
export function isValidStringArray(arr: unknown): arr is string[] {
  if (!Array.isArray(arr)) {
    return false;
  }

  return arr.every(item => typeof item === 'string');
}

/**
 * 验证对象键值对数组
 */
export function isValidKeyValueArray(arr: unknown): arr is Array<{name: string, value: any}> {
  if (!Array.isArray(arr)) {
    return false;
  }

  return arr.every(item =>
    typeof item === 'object' &&
    item !== null &&
    'name' in item &&
    typeof item.name === 'string'
  );
}