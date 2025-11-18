/**
 * 纯本地图表生成服务
 * 完全本地运行，支持CSV/Excel解析和ECharts渲染
 * 对隐私和离线能力要求高，性能好，可控性强
 */

import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';

// 图表数据类型定义
export interface LocalChartData {
  headers: string[];
  rows: string[][];
  numericColumns: number[];
  categoryColumns: number[];
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

  private constructor() {}

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
   * 智能推荐图表类型
   */
  public recommendChartType(data: LocalChartData): 'bar' | 'line' | 'pie' | 'scatter' {
    const headers = data.headers;
    const rows = data.rows;
    const numericColumns = data.numericColumns;
    const categoryColumns = data.categoryColumns;

    // 如果只有一个数值列且有分类列，推荐饼图
    if (numericColumns.length === 1 && categoryColumns.length >= 1) {
      const uniqueCategories = new Set(rows.map(row => row[categoryColumns[0]]));
      if (uniqueCategories.size <= 10) { // 分类数量较少时适合饼图
        return 'pie';
      }
    }

    // 如果有两个数值列，推荐散点图
    if (numericColumns.length >= 2) {
      return 'scatter';
    }

    // 如果有多个数值列，推荐柱状图
    if (numericColumns.length >= 2) {
      return 'bar';
    }

    // 如果有连续的时间或有序数据，推荐折线图
    if (categoryColumns.length >= 1 && numericColumns.length === 1) {
      return 'line';
    }

    // 默认推荐柱状图
    return 'bar';
  }

  /**
   * 生成图表配置
   */
  public generateChartConfig(data: LocalChartData, chartType?: string): LocalChartConfig {
    const headers = data.headers;
    const rows = data.rows;
    const numericColumns = data.numericColumns;
    const categoryColumns = data.categoryColumns;

    const type = (chartType || this.recommendChartType(data)) as 'bar' | 'line' | 'pie' | 'scatter';

    const xAxisConfig: XAxisConfig = {
      type: 'category',
      name: categoryColumns.length > 0 ? headers[categoryColumns[0]] : 'X轴'
    };

    const yAxisConfig: YAxisConfig = {
      type: 'value',
      name: numericColumns.length > 0 ? headers[numericColumns[0]] : 'Y轴'
    };

    const legendConfig: LegendConfig = {
      show: false,
      data: []
    };

    const tooltipConfig: TooltipConfig = {
      trigger: type === 'pie' ? 'item' : 'axis'
    };

    const config: LocalChartConfig = {
      title: '数据图表',
      type: type,
      xAxis: xAxisConfig,
      yAxis: yAxisConfig,
      series: [],
      legend: legendConfig,
      tooltip: tooltipConfig
    };

    if (type === 'pie') {
      // 饼图配置
      const categoryCol = categoryColumns[0] || 0;
      const numericCol = numericColumns[0] || 1;

      const categoryData: Map<string, number> = new Map<string, number>();
      for (let i = 0; i < rows.length; i++) {
        const row = rows[i];
        const category = row[categoryCol];
        const value = Number(row[numericCol]) || 0;
        const currentValue = categoryData.get(category) || 0;
        categoryData.set(category, currentValue + value);
      }

      const pieDataArray: PieData[] = [];
      categoryData.forEach((value, name) => {
        const pieItem: PieData = {
          name: name,
          value: value
        };
        pieDataArray.push(pieItem);
      });

      const pieSeries: SeriesData = {
        name: headers[numericCol],
        type: 'pie',
        data: pieDataArray as Object
      };
      config.series.push(pieSeries);

    } else if (type === 'scatter') {
      // 散点图配置
      const xCol = numericColumns[0];
      const yCol = numericColumns.length > 1 ? numericColumns[1] : categoryColumns[0];

      const scatterData: number[][] = [];
      for (let i = 0; i < rows.length; i++) {
        const row = rows[i];
        const point = [
          Number(row[xCol]) || 0,
          Number(row[yCol]) || 0
        ];
        scatterData.push(point);
      }

      const scatterSeries: SeriesData = {
        name: `${headers[xCol]} vs ${headers[yCol]}`,
        type: 'scatter',
        data: scatterData as Object
      };
      config.series.push(scatterSeries);

      config.xAxis.type = 'value';

    } else {
      // 柱状图和折线图配置
      const categoryCol = categoryColumns[0] || 0;

      // X轴数据
      config.xAxis.data = rows.map(row => row[categoryCol]);

      // Y轴系列数据
      for (let i = 0; i < numericColumns.length; i++) {
        const col = numericColumns[i];
        const seriesData = rows.map(row => Number(row[col]) || 0);
        const seriesItem: SeriesData = {
          name: headers[col],
          type: type,
          data: seriesData as Object
        };
        config.series.push(seriesItem);
      }

      config.legend.show = numericColumns.length > 1;
      const legendDataArray: string[] = [];
      for (let i = 0; i < numericColumns.length; i++) {
        legendDataArray.push(headers[numericColumns[i]]);
      }
      config.legend.data = legendDataArray;
    }

    return config;
  }

  /**
   * 将本地配置转换为ECharts配置
   */
  public toEChartsOption(localConfig: LocalChartConfig): Object {
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
      const series = eChartsOption.get('series') as Record<string, Object>[];
      if (series.length > 0) {
        const pieSeriesConfig = new PieSeriesConfig();
        pieSeriesConfig.name = (series[0] as Record<string, Object>).name as string;
        pieSeriesConfig.type = 'pie';
        pieSeriesConfig.data = (series[0] as Record<string, Object>).data;
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
    const jsonData: Record<string, Object>[] = [];
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      const obj: Record<string, Object> = {};
      for (let j = 0; j < headers.length; j++) {
        obj[headers[j]] = row[j];
      }
      jsonData.push(obj);
    }

    return JSON.stringify(jsonData, null, 2);
  }
}