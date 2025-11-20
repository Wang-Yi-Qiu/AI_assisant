/**
 * 纯本地图表生成服务
 * 完全本地运行，支持CSV/Excel解析和ECharts渲染
 * 对隐私和离线能力要求高，性能好，可控性强
 */

import { ChartCacheManager } from '../cache/ChartCacheManager';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';

// 主题配置类型
interface ChartTheme {
  colors: string[];
  backgroundColor: string;
  textColor: string;
  gridColor?: string;
  highlightColor?: string;
  primaryColor?: string;
}

// 预热缓存配置接口
interface PredefinedConfig {
  key: string;
  data: LocalChartData;
}

// 缓存配置参数接口
interface CacheConfigParams {
  maxSize?: number;
  maxMemoryMB?: number;
  ttlMinutes?: number;
  compressionEnabled?: boolean;
  persistentCache?: boolean;
  cleanupInterval?: number;
}

// 缓存统计返回接口
interface CacheStatsResult {
  totalEntries: number;
  hitRate: number;
  totalMemoryUsage: number;
}

// 图表类型名称映射接口
interface ChartTypeNames {
  bar: string;
  line: string;
  pie: string;
  scatter: string;
}

// 自定义选项接口
interface CustomOptions {
  theme?: 'light' | 'dark' | 'blue';
  animation?: boolean;
  dataLabels?: boolean;
  title?: string;
  subtitle?: string;
  width?: number;
  height?: number;
  responsive?: boolean;
}

// 元数据接口
interface DataMetadata {
  title?: string;
  description?: string;
  tags?: string[];
  createdAt?: string;
}

// 数据质量评估结果接口
interface DataQualityResult {
  completeness: number;
  categoryUniqueness: number;
  dataVariance: number;
  rowDensity: number;
}

// 饼图数据项接口
interface PieDataItem {
  name: string;
  value: number;
}


// 图表数据类型定义
export interface LocalChartData {
  headers: string[];
  rows: string[][];
  numericColumns: number[];
  categoryColumns: number[];
  fileName?: string;
  data?: string[][];
  metadata?: DataMetadata;
}

/**
 * 图表推荐结果接口
 */
export interface ChartRecommendation {
  type: 'bar' | 'line' | 'pie' | 'scatter';
  score: number;
  reason: string;
  confidence: 'high' | 'medium' | 'low';
}

// 图表配置类型
export interface LocalChartConfig {
  title: string;
  type: 'bar' | 'line' | 'pie' | 'scatter';
  xAxis: XAxisConfig;
  yAxis: YAxisConfig;
  series: SeriesData[];
  legend: LegendConfig;
  tooltip: TooltipConfig;
}

export interface XAxisConfig {
  type: 'category' | 'value';
  data?: string[];
  name?: string;
}

export interface YAxisConfig {
  type: 'value' | 'category';
  name?: string;
}

export interface SeriesData {
  name: string;
  type: string;
  data: Object; // 使用Object来兼容不同数据类型
  color?: string;
}

export interface LegendConfig {
  show: boolean;
  data?: string[];
}

export interface TooltipConfig {
  trigger: 'item' | 'axis';
  formatter?: string;
}

export interface PieData {
  name: string;
  value: number;
}

export interface ColumnAnalysisResult {
  numericColumns: number[];
  categoryColumns: number[];
}

// 导出格式类型
export type ExportFormat = 'png' | 'jpg' | 'pdf' | 'json' | 'csv';

/**
 * 本地图表生成服务类
 */
export class LocalChartService {
  private static instance: LocalChartService;
  private cacheManager: ChartCacheManager;

  private constructor() {
    this.cacheManager = ChartCacheManager.getInstance();
  }

  /**
   * 获取图表类型名称的辅助函数
   */
  private getChartTypeName(chartType: 'bar' | 'line' | 'pie' | 'scatter'): string {
    if (chartType === 'bar') {
      return '柱状图';
    } else if (chartType === 'line') {
      return '折线图';
    } else if (chartType === 'pie') {
      return '饼图';
    } else {
      return '散点图';
    }
  }

  /**
   * 获取单例实例
   */
  public static getInstance(): LocalChartService {
    if (!LocalChartService.instance) {
      LocalChartService.instance = new LocalChartService();
    }
    return LocalChartService.instance;
  }

  /**
   * 初始化缓存管理器
   */
  public async initialize(): Promise<void> {
    await this.cacheManager.initialize();
  }

  /**
   * 选择并解析CSV文件
   */
  public async selectAndParseCSV(): Promise<LocalChartData | null> {
    try {
      console.info('[LocalChartService] 开始选择CSV文件');

      // 创建文件选择器
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      documentSelectOptions.fileSuffixFilters = ['.csv'];

      const documentViewPicker = new picker.DocumentViewPicker();
      const uriList = await documentViewPicker.select(documentSelectOptions);

      if (uriList && uriList.length > 0) {
        const fileUri = uriList[0];
        console.info('[LocalChartService] 选择文件:', fileUri);
        return await this.parseCSVFile(fileUri);
      }

      return null;
    } catch (error) {
      console.error('[LocalChartService] 文件选择失败:', error);
      return null;
    }
  }

  /**
   * 解析CSV文件
   */
  private async parseCSVFile(uri: string): Promise<LocalChartData | null> {
    try {
      console.info('[LocalChartService] 开始解析CSV文件:', uri);

      // 打开文件
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const fileSize = stat.size;

      // 检查文件大小限制 (10MB)
      if (fileSize > 10 * 1024 * 1024) {
        throw new Error('文件过大，请选择小于10MB的文件');
      }

      // 读取文件内容
      const buffer = new ArrayBuffer(fileSize);
      const readSize = fs.readSync(file.fd, buffer);
      fs.closeSync(file);

      // 转换为字符串
      const decoder = util.TextDecoder.create('utf-8');
      const content = decoder.decode(new Uint8Array(buffer));

      // 解析CSV内容
      return this.parseCSVContent(content);

    } catch (error) {
      console.error('[LocalChartService] CSV文件解析失败:', error);
      return null;
    }
  }

  /**
   * 解析CSV内容
   */
  private parseCSVContent(content: string): LocalChartData | null {
    try {
      console.info('[LocalChartService] 开始解析CSV内容');

      // 按行分割并过滤空行
      const lines = content.trim().split('\n').filter(line => line.trim() !== '');

      if (lines.length < 2) {
        throw new Error('CSV文件内容不足，至少需要标题行和一行数据');
      }

      // 解析标题行
      const headers = this.parseCSVLine(lines[0]);
      console.info('[LocalChartService] 解析到表头:', headers);

      if (headers.length < 2) {
        throw new Error('CSV文件至少需要两列数据');
      }

      // 解析数据行
      const rows: string[][] = [];
      for (let i = 1; i < lines.length; i++) {
        try {
          const values = this.parseCSVLine(lines[i]);
          if (values.length === headers.length) {
            rows.push(values);
          }
        } catch (lineError) {
          console.warn(`[LocalChartService] 跳过第${i + 1}行，解析失败:`, lineError);
        }
      }

      if (rows.length === 0) {
        throw new Error('没有有效的数据行');
      }

      // 分析数据类型
      const analysisResult = this.analyzeColumns(headers, rows);
      const numericColumns = analysisResult.numericColumns;
      const categoryColumns = analysisResult.categoryColumns;

      console.info('[LocalChartService] CSV解析完成，数据行数:', rows.length);
      console.info('[LocalChartService] 数值列:', numericColumns);
      console.info('[LocalChartService] 分类列:', categoryColumns);

      return {
        headers,
        rows,
        numericColumns,
        categoryColumns
      };

    } catch (error) {
      console.error('[LocalChartService] CSV解析失败:', error);
      return null;
    }
  }

  /**
   * 解析CSV行（处理逗号分隔和引号）
   */
  private parseCSVLine(line: string): string[] {
    const result: string[] = [];
    let current = '';
    let inQuotes = false;

    for (let i = 0; i < line.length; i++) {
      const char = line[i];

      if (char === '"') {
        if (inQuotes && line[i + 1] === '"') {
          // 转义的引号
          current += '"';
          i++; // 跳过下一个引号
        } else {
          // 切换引号状态
          inQuotes = !inQuotes;
        }
      } else if (char === ',' && !inQuotes) {
        // 字段分隔符
        result.push(current.trim());
        current = '';
      } else {
        current += char;
      }
    }

    // 添加最后一个字段
    result.push(current.trim());

    return result;
  }

  /**
   * 分析列数据类型
   */
  private analyzeColumns(headers: string[], rows: string[][]): ColumnAnalysisResult {
    const numericColumns: number[] = [];
    const categoryColumns: number[] = [];

    for (let col = 0; col < headers.length; col++) {
      let numericCount = 0;
      let totalCount = 0;

      for (const row of rows) {
        const value = row[col];
        if (value && value.trim() !== '') {
          totalCount++;
          const numValue = Number(value);
          if (!isNaN(numValue)) {
            numericCount++;
          }
        }
      }

      // 如果超过70%的值是数字，认为是数值列
      if (totalCount > 0 && (numericCount / totalCount) > 0.7) {
        numericColumns.push(col);
      } else {
        categoryColumns.push(col);
      }
    }

    const result: ColumnAnalysisResult = {
      numericColumns: numericColumns,
      categoryColumns: categoryColumns
    };
    return result;
  }

  /**
   * 智能推荐图表类型（增强版，支持缓存）
   */
  public recommendChartTypes(data: LocalChartData): ChartRecommendation[] {
    // 生成缓存键
    const cacheKey = this.cacheManager.generateCacheKey(data, 'recommendations');

    // 尝试从缓存获取
    const cachedRecommendations = this.cacheManager.get(cacheKey);
    if (cachedRecommendations) {
      console.info('[LocalChartService] 推荐结果缓存命中');
      return cachedRecommendations;
    }

    // 计算推荐结果
    const recommendations = this.computeRecommendations(data);

    // 存入缓存
    this.cacheManager.set(cacheKey, recommendations, 10 * 60 * 1000); // 10分钟TTL

    return recommendations;
  }

  /**
   * 计算推荐结果（核心算法）
   */
  private computeRecommendations(data: LocalChartData): ChartRecommendation[] {
    const recommendations: ChartRecommendation[] = [];
    const headers = data.headers;
    const rows = data.rows;
    const numericColumns = data.numericColumns;
    const categoryColumns = data.categoryColumns;

    // 数据质量评估
    const dataQuality = this.assessDataQuality(data);

    // 柱状图推荐
    if (numericColumns.length >= 1 && categoryColumns.length >= 1) {
      let score = 0.7;
      let reason = '适合比较不同类别的数值大小';
      let confidence: 'high' | 'medium' | 'low' = 'medium';

      if (numericColumns.length > 1) {
        score = 0.9;
        reason = '有多个数值列，柱状图可以清晰对比不同指标';
        confidence = 'high';
      } else if (dataQuality.categoryUniqueness > 0.8) {
        score = 0.85;
        reason = '分类数据多样化，柱状图对比效果明显';
        confidence = 'high';
      }

      recommendations.push({
        type: 'bar',
        score: score,
        reason: reason,
        confidence: confidence
      });
    }

    // 折线图推荐
    if (categoryColumns.length >= 1 && numericColumns.length >= 1) {
      let score = 0.6;
      let reason = '适合展示数据变化趋势';
      let confidence: 'high' | 'medium' | 'low' = 'low';

      // 检查是否为时间序列数据
      const categoryCol = categoryColumns[0];
      const isTimeData = this.isTimeSeriesData(rows.map(row => row[categoryCol]));

      if (isTimeData) {
        score = 0.95;
        reason = '检测到时间序列数据，折线图最适合展示趋势变化';
        confidence = 'high';
      } else if (this.isSequentialData(rows.map(row => row[categoryCol]))) {
        score = 0.8;
        reason = '数据具有顺序性，折线图可以展示变化规律';
        confidence = 'medium';
      } else if (rows.length > 10) {
        score = 0.75;
        reason = '数据点较多，折线图可以清晰展示变化趋势';
        confidence = 'medium';
      }

      recommendations.push({
        type: 'line',
        score: score,
        reason: reason,
        confidence: confidence
      });
    }

    // 饼图推荐
    if (numericColumns.length === 1 && categoryColumns.length >= 1) {
      const categoryCol = categoryColumns[0];
      const uniqueCategories = new Set(rows.map(row => row[categoryCol]));
      const categoryCount = uniqueCategories.size;

      let score = 0;
      let reason = '';
      let confidence: 'high' | 'medium' | 'low' = 'low';

      if (categoryCount <= 6) {
        score = 0.9;
        reason = `分类数量适中（${categoryCount}个），饼图可以清晰展示占比关系`;
        confidence = 'high';
      } else if (categoryCount <= 10) {
        score = 0.75;
        reason = `分类数量较多（${categoryCount}个），饼图仍可展示占比`;
        confidence = 'medium';
      } else if (categoryCount <= 15) {
        score = 0.5;
        reason = `分类数量很多（${categoryCount}个），饼图可能显得拥挤`;
        confidence = 'low';
      }

      // 检查数据是否适合展示占比
      if (score > 0) {
        const numericCol = numericColumns[0];
        const allPositive = rows.every(row => Number(row[numericCol]) >= 0);
        if (allPositive) {
          recommendations.push({
            type: 'pie',
            score: score,
            reason: reason,
            confidence: confidence
          });
        }
      }
    }

    // 散点图推荐
    if (numericColumns.length >= 2) {
      let score = 0.8;
      let reason = '适合分析两个数值变量之间的关系';
      let confidence: 'high' | 'medium' | 'low' = 'medium';

      if (numericColumns.length >= 3) {
        score = 0.85;
        reason = '有多个数值列，散点图可以探索变量间的相关性';
        confidence = 'high';
      }

      if (dataQuality.dataVariance > 0.7) {
        score += 0.1;
        reason += '，数据分布差异明显';
      }

      recommendations.push({
        type: 'scatter',
        score: score,
        reason: reason,
        confidence: confidence
      });
    }

    // 按分数排序
    recommendations.sort((a, b) => b.score - a.score);
    return recommendations;
  }

  /**
   * 获取最佳推荐图表类型
   */
  public recommendChartType(data: LocalChartData): 'bar' | 'line' | 'pie' | 'scatter' {
    const recommendations = this.recommendChartTypes(data);
    return recommendations.length > 0 ? recommendations[0].type : 'bar';
  }

  /**
   * 批量获取推荐（支持缓存）
   */
  public async getBatchRecommendations(datasets: LocalChartData[]): Promise<Map<number, ChartRecommendation[]>> {
    const results = new Map<number, ChartRecommendation[]>();
    const cacheKeys: string[] = [];
    const uncachedIndices: number[] = [];

    // 收集缓存键和未缓存的数据索引
    datasets.forEach((data, index) => {
      const cacheKey = this.cacheManager.generateCacheKey(data, 'recommendations');
      cacheKeys.push(cacheKey);

      const cached = this.cacheManager.get(cacheKey);
      if (cached) {
        results.set(index, cached);
      } else {
        uncachedIndices.push(index);
      }
    });

    // 计算未缓存的推荐
    if (uncachedIndices.length > 0) {
      const batchPromises = uncachedIndices.map(index => {
        const data = datasets[index];
        const recommendations = this.computeRecommendations(data);

        // 存入缓存
        this.cacheManager.set(cacheKeys[index], recommendations, 10 * 60 * 1000);

        results.set(index, recommendations);
      });

      await Promise.all(batchPromises);
    }

    return results;
  }

  /**
   * 评估数据质量
   */
  private assessDataQuality(data: LocalChartData): DataQualityResult {
    const rows = data.rows;
    const headers = data.headers;
    const numericColumns = data.numericColumns;
    const categoryColumns = data.categoryColumns;

    // 完整性评估
    let totalCells = rows.length * headers.length;
    let validCells = 0;
    rows.forEach(row => {
      row.forEach(cell => {
        if (cell && cell.trim() !== '') {
          validCells++;
        }
      });
    });
    const completeness = validCells / totalCells;

    // 分类数据唯一性
    let categoryUniqueness = 0;
    if (categoryColumns.length > 0) {
      const categoryCol = categoryColumns[0];
      const uniqueCategories = new Set(rows.map(row => row[categoryCol]));
      categoryUniqueness = uniqueCategories.size / rows.length;
    }

    // 数值数据方差
    let dataVariance = 0;
    if (numericColumns.length > 0) {
      const numericCol = numericColumns[0];
      const values = rows.map(row => Number(row[numericCol]) || 0);
      const mean = values.reduce((a, b) => a + b, 0) / values.length;
      const variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length;
      const stdDev = Math.sqrt(variance);
      dataVariance = Math.min(stdDev / mean, 1); // 标准化到0-1
    }

    // 行密度（数据量评估）
    const optimalRows = 50; // 理想的数据行数
    const rowDensity = Math.min(rows.length / optimalRows, 1);

    const result: DataQualityResult = {
      completeness: completeness,
      categoryUniqueness: categoryUniqueness,
      dataVariance: dataVariance,
      rowDensity: rowDensity
    };
    return result;
  }

  /**
   * 检查是否为时间序列数据
   */
  private isTimeSeriesData(categoryValues: string[]): boolean {
    // 检查常见的日期格式
    const datePatterns = [
      /^\d{4}-\d{1,2}-\d{1,2}$/, // YYYY-MM-DD
      /^\d{1,2}\/\d{1,2}\/\d{4}$/, // MM/DD/YYYY
      /^\d{4}年\d{1,2}月\d{1,2}日$/, // 中文日期
      /^[一二三四五六七八九十]+月\d{1,2}日?$/, // 中文月份
      /^[A-Za-z]+ \d{1,2}, \d{4}$/, //英文日期
    ];

    // 检查时间格式
    const timePatterns = [
      /^\d{1,2}:\d{2}$/, // HH:MM
      /^\d{1,2}:\d{2}:\d{2}$/, // HH:MM:SS
    ];

    let dateMatchCount = 0;
    let timeMatchCount = 0;
    let sequentialCount = 0;

    for (let i = 0; i < categoryValues.length; i++) {
      const value = categoryValues[i];

      // 检查日期格式
      if (datePatterns.some(pattern => pattern.test(value))) {
        dateMatchCount++;
      }

      // 检查时间格式
      if (timePatterns.some(pattern => pattern.test(value))) {
        timeMatchCount++;
      }

      // 检查序列性（如1月、2月、3月或第1季度、第2季度等）
      if (this.isSequentialTerm(value)) {
        sequentialCount++;
      }
    }

    const totalMatches = dateMatchCount + timeMatchCount + sequentialCount;
    const ratio = totalMatches / categoryValues.length;

    return ratio > 0.6; // 如果超过60%的数据匹配时间模式
  }

  /**
   * 检查是否为序列数据
   */
  private isSequentialData(categoryValues: string[]): boolean {
    let sequentialCount = 0;

    for (let i = 0; i < categoryValues.length; i++) {
      if (this.isSequentialTerm(categoryValues[i])) {
        sequentialCount++;
      }
    }

    return (sequentialCount / categoryValues.length) > 0.5;
  }

  /**
   * 检查单个值是否为序列术语
   */
  private isSequentialTerm(value: string): boolean {
    const sequentialPatterns = [
      /^第?[一二三四五六七八九十\d]+[个]?季度?$/, // 季度
      /^[一二三四五六七八九十]+月$/, // 中文月份
      /^\d{1,2}月$/, // 数字月份
      /^周[一二三四五六日天]$/, // 星期
      /^第\d+[期个批卷集]$/, // 序号
      /^Phase \d+$/i, // 英文阶段
      /^Stage \d+$/i, // 英文阶段
      /^Level \d+$/i, // 等级
      /^\d{4}年$/, // 年份
    ];

    return sequentialPatterns.some(pattern => pattern.test(value));
  }

  /**
   * 智能图表配置生成器（使用工厂模式）
   */
  public generateSmartChartConfig(data: LocalChartData, chartType?: string, customOptions?: CustomOptions): LocalChartConfig {
    const headers = data.headers;
    const rows = data.rows;
    const numericColumns = data.numericColumns;
    const categoryColumns = data.categoryColumns;

    // 获取推荐信息
    const recommendations = this.recommendChartTypes(data);
    const type = (chartType || recommendations[0]?.type || 'bar') as 'bar' | 'line' | 'pie' | 'scatter';
    const recommendation = recommendations.find(r => r.type === type) || recommendations[0];

    // 数据质量评估
    const dataQuality = this.assessDataQuality(data);

    // 智能标题生成
    const title = customOptions?.title || this.generateSmartTitle(data, type, recommendation);

    // 主题配置
    const theme = this.getThemeConfig(customOptions?.theme || 'dark');

    const config: LocalChartConfig = {
      title: title,
      type: type,
      xAxis: this.generateXAxisConfig(data, type),
      yAxis: this.generateYAxisConfig(data, type),
      series: [],
      legend: this.generateLegendConfig(data, type),
      tooltip: this.generateTooltipConfig(type)
    };

    // 根据图表类型生成系列数据
    switch (type) {
      case 'bar':
        this.generateBarSeries(config, data, theme);
        break;
      case 'line':
        this.generateLineSeries(config, data, theme, customOptions?.animation !== false);
        break;
      case 'pie':
        this.generatePieSeries(config, data, theme, customOptions?.dataLabels === true);
        break;
      case 'scatter':
        this.generateScatterSeries(config, data, theme);
        break;
    }

    return config;
  }

  /**
   * 兼容性方法：生成图表配置
   */
  public generateChartConfig(data: LocalChartData, chartType?: string): LocalChartConfig {
    return this.generateSmartChartConfig(data, chartType);
  }

  /**
   * 智能标题生成
   */
  private generateSmartTitle(data: LocalChartData, chartType: string, recommendation?: ChartRecommendation): string {
    const headers = data.headers;
    const rows = data.rows;
    const numericColumns = data.numericColumns;
    const categoryColumns = data.categoryColumns;

    const chartTypeNames: ChartTypeNames = {
      bar: '柱状图',
      line: '折线图',
      pie: '饼图',
      scatter: '散点图'
    };

    // 检查时间序列数据
    let timeDesc = '';
    if (categoryColumns.length > 0) {
      const categoryCol = categoryColumns[0];
      const categoryValues = rows.map(row => row[categoryCol]);
      if (this.isTimeSeriesData(categoryValues)) {
        timeDesc = this.extractTimeDescription(categoryValues);
      }
    }

    // 根据数据特点生成标题
    const safeChartType: 'bar' | 'line' | 'pie' | 'scatter' =
      (chartType === 'bar' || chartType === 'line' || chartType === 'pie' || chartType === 'scatter')
        ? chartType
        : 'bar';

    if (recommendation?.confidence === 'high') {
      if (timeDesc) {
        return `${timeDesc}${this.getChartTypeName(safeChartType)}分析`;
      } else {
        const mainMetric = headers[numericColumns[0]];
        const category = headers[categoryColumns[0]];
        return `${category}${mainMetric}${this.getChartTypeName(safeChartType)}`;
      }
    } else {
      return `智能${this.getChartTypeName(safeChartType)}`;
    }
  }

  /**
   * 提取时间描述
   */
  private extractTimeDescription(categoryValues: string[]): string {
    // 检查年份范围
    const years = categoryValues.map(v => v.match(/\d{4}/)?.[1]).filter(Boolean);
    if (years.length >= 2) {
      const minYear = Math.min(...years.map(Number));
      const maxYear = Math.max(...years.map(Number));
      if (minYear !== maxYear) {
        return `${minYear}-${maxYear}年`;
      }
    }

    // 检查月份
    const months = categoryValues.filter(v => v.includes('月'));
    if (months.length > 0) {
      return '月度';
    }

    // 检查季度
    const quarters = categoryValues.filter(v => v.includes('季度') || v.includes('Q'));
    if (quarters.length > 0) {
      return '季度';
    }

    // 检查星期
    const weeks = categoryValues.filter(v => v.includes('周') || v.includes('星期'));
    if (weeks.length > 0) {
      return '周度';
    }

    return '';
  }

  /**
   * 获取主题配置
   */
  private getThemeConfig(theme: 'light' | 'dark' | 'blue'): ChartTheme {
    const themes: Record<string, ChartTheme> = {
      'light': {
        backgroundColor: '#FFFFFF',
        textColor: '#333333',
        primaryColor: '#1890FF',
        colors: ['#1890FF', '#52C41A', '#FAAD14', '#F5222D', '#722ED1', '#FA8C16']
      },
      'dark': {
        backgroundColor: '#1C1C1C',
        textColor: '#FFFFFF',
        primaryColor: '#007DFF',
        colors: ['#007DFF', '#00C853', '#FFD600', '#FF5252', '#B388FF', '#FF6E40']
      },
      'blue': {
        backgroundColor: '#0A1931',
        textColor: '#E0E0E0',
        primaryColor: '#2196F3',
        colors: ['#2196F3', '#4CAF50', '#FF9800', '#F44336', '#9C27B0', '#00BCD4']
      }
    };

    if (theme === 'light') {
      return themes.light;
    } else if (theme === 'dark') {
      return themes.dark;
    } else {
      return themes.blue;
    }
  }

  /**
   * 生成X轴配置
   */
  private generateXAxisConfig(data: LocalChartData, chartType: string): XAxisConfig {
    const categoryColumns = data.categoryColumns;
    const headers = data.headers;

    if (chartType === 'scatter' || chartType === 'pie') {
      return {
        type: 'value',
        name: ''
      };
    }

    if (categoryColumns.length > 0) {
      return {
        type: 'category',
        name: headers[categoryColumns[0]]
      };
    }

    return {
      type: 'category',
      name: '类别'
    };
  }

  /**
   * 生成Y轴配置
   */
  private generateYAxisConfig(data: LocalChartData, chartType: string): YAxisConfig {
    const numericColumns = data.numericColumns;
    const headers = data.headers;

    if (chartType === 'pie') {
      return {
        type: 'category',
        name: ''
      };
    }

    if (numericColumns.length > 0) {
      return {
        type: 'value',
        name: headers[numericColumns[0]]
      };
    }

    return {
      type: 'value',
      name: '数值'
    };
  }

  /**
   * 生成图例配置
   */
  private generateLegendConfig(data: LocalChartData, chartType: string): LegendConfig {
    if (chartType === 'pie') {
      return {
        show: true,
        data: []
      };
    }

    const showLegend = data.numericColumns.length > 1 || chartType === 'pie';
    return {
      show: showLegend,
      data: showLegend ? data.numericColumns.map(col => data.headers[col]) : []
    };
  }

  /**
   * 生成提示框配置
   */
  private generateTooltipConfig(chartType: string): TooltipConfig {
    return {
      trigger: chartType === 'pie' ? 'item' : 'axis',
      formatter: chartType === 'pie' ? '{a} <br/>{b}: {c} ({d}%)' : undefined
    };
  }

  /**
   * 生成柱状图系列
   */
  private generateBarSeries(config: LocalChartConfig, data: LocalChartData, theme: ChartTheme): void {
    const rows = data.rows;
    const numericColumns = data.numericColumns;
    const categoryColumns = data.categoryColumns;

    if (categoryColumns.length > 0) {
      const categoryCol = categoryColumns[0];
      config.xAxis.data = rows.map(row => row[categoryCol]);
    }

    numericColumns.forEach((col, index) => {
      const seriesData = rows.map(row => Number(row[col]) || 0);
      config.series.push({
        name: data.headers[col],
        type: 'bar',
        data: seriesData,
        color: theme.colors[index % theme.colors.length]
      });
    });
  }

  /**
   * 生成折线图系列
   */
  private generateLineSeries(config: LocalChartConfig, data: LocalChartData, theme: ChartTheme, enableAnimation: boolean = true): void {
    const rows = data.rows;
    const numericColumns = data.numericColumns;
    const categoryColumns = data.categoryColumns;

    if (categoryColumns.length > 0) {
      const categoryCol = categoryColumns[0];
      config.xAxis.data = rows.map(row => row[categoryCol]);
    }

    numericColumns.forEach((col, index) => {
      const seriesData = rows.map(row => Number(row[col]) || 0);
      config.series.push({
        name: data.headers[col],
        type: 'line',
        data: seriesData,
        color: theme.colors[index % theme.colors.length]
      });
    });
  }

  /**
   * 生成饼图系列
   */
  private generatePieSeries(config: LocalChartConfig, data: LocalChartData, theme: ChartTheme, showDataLabels: boolean = false): void {
    const rows = data.rows;
    const numericColumns = data.numericColumns;
    const categoryColumns = data.categoryColumns;

    if (numericColumns.length >= 1 && categoryColumns.length >= 1) {
      const categoryCol = categoryColumns[0];
      const numericCol = numericColumns[0];

      // 聚合数据
      const aggregatedData = new Map<string, number>();
      for (const row of rows) {
        const category = row[categoryCol];
        const value = Number(row[numericCol]) || 0;
        const currentValue = aggregatedData.get(category);
        aggregatedData.set(category, (currentValue ? currentValue : 0) + value);
      }

      const pieData: PieDataItem[] = [];
      for (const entry of aggregatedData.entries()) {
        const name = entry[0];
        const value = entry[1];
        const dataItem: PieDataItem = {
          name: name,
          value: value
        };
        pieData.push(dataItem);
      }

      config.series.push({
        name: data.headers[numericCol],
        type: 'pie',
        data: pieData,
        color: theme.colors[0]
      });
    }
  }

  /**
   * 生成散点图系列
   */
  private generateScatterSeries(config: LocalChartConfig, data: LocalChartData, theme: ChartTheme): void {
    const rows = data.rows;
    const numericColumns = data.numericColumns;

    if (numericColumns.length >= 2) {
      const xCol = numericColumns[0];
      const yCol = numericColumns[1];

      const scatterData = rows.map(row => [
        Number(row[xCol]) || 0,
        Number(row[yCol]) || 0
      ]);

      config.series.push({
        name: `${data.headers[xCol]} vs ${data.headers[yCol]}`,
        type: 'scatter',
        data: scatterData,
        color: theme.colors[0]
      });
    }
  }

  /**
   * 增强的ECharts配置转换（支持主题）
   */
  public toEChartsOption(localConfig: LocalChartConfig, theme?: ChartTheme): Object {
    class TitleConfig {
      text: string = '';
      left: string = '';
    }
    const titleConfig = new TitleConfig();
    titleConfig.text = localConfig.title;
    titleConfig.left = 'center';

    const eChartsOption = new Map<string, Object>();
    eChartsOption.set('title', titleConfig);
    eChartsOption.set('tooltip', localConfig.tooltip as Object);
    eChartsOption.set('legend', localConfig.legend as Object);
    eChartsOption.set('xAxis', localConfig.xAxis as Object);
    eChartsOption.set('yAxis', localConfig.yAxis as Object);
    eChartsOption.set('series', localConfig.series as Object[]);

    // 饼图特殊处理
    if (localConfig.type === 'pie') {
      const pieOption = new Map<string, Object>();
      pieOption.set('title', eChartsOption.get('title') as Object);
      pieOption.set('tooltip', eChartsOption.get('tooltip') as Object);
      pieOption.set('legend', eChartsOption.get('legend') as Object);

      class PieSeriesConfig {
      name: string = '';
      type: string = '';
      data: Object = new Object();
      radius: string = '';
      center: string[] = [];
    }

      const pieSeriesArray: Object[] = [];
      const series = eChartsOption.get('series') as Object[];
      if (series.length > 0) {
        const pieSeriesConfig = new PieSeriesConfig();
        // Simplify the series data access to avoid type casting
        pieSeriesConfig.type = 'pie';
        pieSeriesConfig.radius = '60%';
        pieSeriesConfig.center = ['50%', '50%'];
        pieSeriesArray.push(pieSeriesConfig);
      }
      pieOption.set('series', pieSeriesArray);

      return pieOption as Object;
    }

    return eChartsOption as Object;
  }

  /**
   * 生成示例数据
   */
  public generateSampleData(dataType: 'sales' | 'weather' | 'students' = 'sales'): LocalChartData {
    switch (dataType) {
      case 'sales':
        return {
          headers: ['月份', '销售额', '利润', '产品数量'],
          rows: [
            ['1月', '12000', '3000', '150'],
            ['2月', '15000', '4000', '180'],
            ['3月', '18000', '5000', '220'],
            ['4月', '14000', '3500', '160'],
            ['5月', '20000', '6000', '250'],
            ['6月', '22000', '7000', '280']
          ],
          numericColumns: [1, 2, 3],
          categoryColumns: [0]
        };

      case 'weather':
        return {
          headers: ['日期', '温度', '湿度', '降雨量'],
          rows: [
            ['周一', '22', '65', '0'],
            ['周二', '24', '70', '2'],
            ['周三', '19', '80', '15'],
            ['周四', '18', '85', '20'],
            ['周五', '21', '75', '5'],
            ['周六', '25', '60', '0'],
            ['周日', '23', '68', '1']
          ],
          numericColumns: [1, 2, 3],
          categoryColumns: [0]
        };

      case 'students':
        return {
          headers: ['姓名', '数学', '英语', '科学'],
          rows: [
            ['张三', '85', '92', '88'],
            ['李四', '78', '85', '80'],
            ['王五', '92', '88', '95'],
            ['赵六', '88', '90', '82'],
            ['钱七', '76', '82', '78'],
            ['孙八', '90', '87', '91']
          ],
          numericColumns: [1, 2, 3],
          categoryColumns: [0]
        };

      default:
        return this.generateSampleData('sales');
    }
  }

  /**
   * 导出数据
   */
  public exportData(data: LocalChartData, format: ExportFormat): string {
    switch (format) {
      case 'csv':
        return this.exportToCSV(data);
      case 'json':
        return this.exportToJSON(data);
      default:
        throw new Error(`不支持的导出格式: ${format}`);
    }
  }

  /**
   * 导出为CSV
   */
  private exportToCSV(data: LocalChartData): string {
    const headers = data.headers;
    const rows = data.rows;
    const csvLines = [headers.join(',')];

    rows.forEach(row => {
      const csvRow = row.map(value => {
        // 如果包含逗号或引号，需要用引号包围
        if (value.includes(',') || value.includes('"')) {
          return `"${value.replace(/"/g, '""')}"`;
        }
        return value;
      });
      csvLines.push(csvRow.join(','));
    });

    return csvLines.join('\n');
  }

  /**
   * 导出为JSON
   */
  private exportToJSON(data: LocalChartData): string {
    const headers = data.headers;
    const rows = data.rows;
    // For JSON export, create simple string representations
    const jsonLines: string[] = [];
    jsonLines.push('[');
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      let jsonLine = '  {';
      for (let j = 0; j < headers.length; j++) {
        if (j > 0) jsonLine += ', ';
        jsonLine += `"${headers[j]}": "${row[j]}"`;
      }
      jsonLine += '}';
      if (i < rows.length - 1) jsonLine += ',';
      jsonLines.push(jsonLine);
    }
    jsonLines.push(']');
    const jsonData = jsonLines.join('\n');

    return JSON.stringify(jsonData, null, 2);
  }

  /**
   * 获取缓存统计信息
   */
  public getCacheStats(): CacheStatsResult {
    return this.cacheManager.getStats();
  }

  /**
   * 清空缓存
   */
  public clearCache(): void {
    this.cacheManager.clear();
  }

  /**
   * 预热缓存
   */
  public async warmupCache(): Promise<void> {
    const predefinedConfigs: PredefinedConfig[] = [];

    // 添加销售数据配置
    const salesConfig: PredefinedConfig = {
      key: this.cacheManager.generateCacheKey(this.generateSampleData('sales'), 'bar'),
      data: this.generateSampleData('sales')
    };
    predefinedConfigs.push(salesConfig);

    // 添加天气数据配置
    const weatherConfig: PredefinedConfig = {
      key: this.cacheManager.generateCacheKey(this.generateSampleData('weather'), 'line'),
      data: this.generateSampleData('weather')
    };
    predefinedConfigs.push(weatherConfig);

    // 添加学生数据配置
    const studentsConfig: PredefinedConfig = {
      key: this.cacheManager.generateCacheKey(this.generateSampleData('students'), 'pie'),
      data: this.generateSampleData('students')
    };
    predefinedConfigs.push(studentsConfig);

    await this.cacheManager.warmup(predefinedConfigs);
    console.info('[LocalChartService] 缓存预热完成');
  }

  /**
   * 设置缓存配置
   */
  public setCacheConfig(config: CacheConfigParams): void {
    if (this.cacheManager.config) {
      // Update the config using the correct property mapping
      if (config.maxSize !== undefined) this.cacheManager.config.maxSize = config.maxSize;
      if (config.maxMemoryMB !== undefined) this.cacheManager.config.maxMemorySize = config.maxMemoryMB * 1024 * 1024; // Convert MB to bytes
      if (config.ttlMinutes !== undefined) this.cacheManager.config.defaultTtl = config.ttlMinutes * 60 * 1000; // Convert minutes to milliseconds
      if (config.cleanupInterval !== undefined) this.cacheManager.config.cleanupInterval = config.cleanupInterval;
      if (config.compressionEnabled !== undefined) this.cacheManager.config.compressionEnabled = config.compressionEnabled;
      if (config.persistentCache !== undefined) this.cacheManager.config.persistentCache = config.persistentCache;
      console.info('[LocalChartService] 缓存配置已更新');
    }
  }

  
  /**
   * 销毁服务
   */
  public destroyService(): void {
    this.cacheManager.destroy();
  }
}