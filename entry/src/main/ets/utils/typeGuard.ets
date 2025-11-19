/**
 * 类型守卫和验证工具
 * @module typeGuard
 */

// 定义接口以替代object literals
interface EChartsTitle {
  text?: string;
}

interface EChartsSeriesItem {
  type: string;
  data?: (number | string | object)[];
}

interface ChartConfig {
  title?: EChartsTitle;
  series: EChartsSeriesItem[];
}

interface CSVData {
  headers: string[];
  data: CSVDataRow[];
}

interface CSVDataRow {
  values: string[]; // 替换索引签名为数组结构
}

interface KeyValueItem {
  name: string;
  value: string | number | boolean | object | null | undefined;
}

/**
 * 验证是否为ECharts标题配置
 */
export function isEChartsTitle(obj: object | null | undefined): boolean {
  if (typeof obj !== 'object' || obj === null) {
    return false;
  }

  const title = obj as EChartsTitle;
  return title.text === undefined || typeof title.text === 'string';
}

/**
 * 验证是否为ECharts系列配置
 */
export function isEChartsSeriesItem(obj: object | null | undefined): boolean {
  if (typeof obj !== 'object' || obj === null) {
    return false;
  }

  const series = obj as EChartsSeriesItem;
  return typeof series.type === 'string' && series.type.length > 0;
}

/**
 * 验证是否为完整的ChartConfig
 */
export function isChartConfig(obj: object | null | undefined): boolean {
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
  for (let i = 0; i < config.series.length; i++) {
    if (!isEChartsSeriesItem(config.series[i])) {
      return false;
    }
  }

  return true;
}

/**
 * 验证是否为CSVData
 */
export function isCSVData(obj: object | null | undefined): boolean {
  if (typeof obj !== 'object' || obj === null) {
    return false;
  }

  const csv = obj as CSVData;

  // 验证headers
  if (!Array.isArray(csv.headers)) {
    return false;
  }
  for (let i = 0; i < csv.headers.length; i++) {
    if (typeof csv.headers[i] !== 'string') {
      return false;
    }
  }

  // 验证data
  if (!Array.isArray(csv.data)) {
    return false;
  }
  for (let i = 0; i < csv.data.length; i++) {
    const row = csv.data[i];
    if (!Array.isArray(row.values)) {
      return false;
    }
    for (let j = 0; j < row.values.length; j++) {
      if (typeof row.values[j] !== 'string') {
        return false;
      }
    }
  }

  return true;
}

/**
 * 验证是否为有效的UserData
 */
export function isValidUserData(obj: object | string | null | undefined): boolean {
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
    const keys = Object.keys(obj);
    return keys.length <= 100; // 限制键的数量
  }

  return false;
}

/**
 * 安全的类型转换
 */
export function safeCast<T>(
  value: object | string | number | boolean | null | undefined,
  validator: (obj: object | string | number | boolean | null | undefined) => boolean,
  errorMessage?: string
): T {
  if (validator(value)) {
    return value as T;
  }

  throw new Error(errorMessage || `类型转换失败: ${typeof value}`);
}

/**
 * 验证并清理字符串
 */
export function validateAndCleanString(str: string | number | boolean | object | null | undefined): string {
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
export function isValidNumber(value: number | string | boolean | object | null | undefined): boolean {
  return typeof value === 'number' && !isNaN(value) && isFinite(value);
}

/**
 * 验证数值数组
 */
export function isValidNumberArray(arr: object | null | undefined): boolean {
  if (!Array.isArray(arr)) {
    return false;
  }

  for (let i = 0; i < arr.length; i++) {
    if (!isValidNumber(arr[i])) {
      return false;
    }
  }

  return true;
}

/**
 * 验证字符串数组
 */
export function isValidStringArray(arr: object | null | undefined): boolean {
  if (!Array.isArray(arr)) {
    return false;
  }

  for (let i = 0; i < arr.length; i++) {
    if (typeof arr[i] !== 'string') {
      return false;
    }
  }

  return true;
}

// 键值对项接口
interface KeyValuePairItem {
  name?: string | number | boolean | object | null | undefined;
  value?: string | number | boolean | object | null | undefined;
}

/**
 * 验证对象键值对数组
 */
export function isValidKeyValueArray(arr: object | null | undefined): boolean {
  if (!Array.isArray(arr)) {
    return false;
  }

  for (let i = 0; i < arr.length; i++) {
    const item: object | null | undefined = arr[i] as object | null | undefined;
    if (typeof item !== 'object' || item === null) {
      return false;
    }
    const keyValueItem = item as KeyValuePairItem;
    if (!keyValueItem.name || typeof keyValueItem.name !== 'string') {
      return false;
    }
  }

  return true;
}