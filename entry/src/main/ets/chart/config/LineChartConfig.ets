/**
 * 折线图配置实现
 * 继承自BaseChartConfig，专门处理折线图相关的配置
 */

import { BaseChartConfig, AxisConfig, SeriesConfig, GridConfig } from './BaseChartConfig';
import { LocalChartData } from '../../utils/localChartService';
import { ChartConfigOptions } from './ChartConfigFactory';

/**
 * 折线图配置类
 */
export class LineChartConfig extends BaseChartConfig {
  constructor(data: LocalChartData, options: ChartConfigOptions = {}) {
    super(data, options);
  }

  /**
   * 获取图表类型
   */
  getChartType(): string {
    return 'line';
  }

  /**
   * 生成折线图配置
   */
  generateConfig(): object {
    if (!this.validateData()) {
      throw new Error('Invalid data for line chart generation');
    }

    const baseConfig = this.getBaseConfig();
    const grid = this.generateGridConfig();
    const xAxis = this.generateLineXAxisConfig();
    const yAxis = this.generateYAxisConfig();
    const series = this.generateLineSeries();

    return {
      title: {
        text: baseConfig.title,
        subtext: baseConfig.subtitle,
        left: 'center',
        textStyle: {
          color: this.theme.textColor,
          fontSize: this.fontSize.title,
          fontWeight: 'bold'
        },
        subtextStyle: {
          color: this.theme.textColor,
          fontSize: this.fontSize.subtitle
        }
      },
      backgroundColor: baseConfig.backgroundColor,
      tooltip: baseConfig.tooltip,
      legend: baseConfig.legend,
      grid: grid,
      xAxis: xAxis,
      yAxis: yAxis,
      series: series,
      animation: baseConfig.animation,
      color: this.getColorPalette(),
      toolbox: this.generateToolboxConfig(),
      dataZoom: this.shouldShowDataZoom() ? this.generateDataZoomConfig() : undefined,
      brush: this.generateBrushConfig()
    };
  }

  /**
   * 生成折线图专用的X轴配置
   */
  private generateLineXAxisConfig(): AxisConfig {
    const baseConfig = super.generateXAxisConfig();
    const { categoryColumns } = this.data;

    if (categoryColumns.length > 0) {
      const categoryCol = categoryColumns[0];
      const categoryValues = this.data.rows.map(row => row[categoryCol]);

      return {
        ...baseConfig,
        type: this.isTimeSeriesData(categoryValues) ? 'time' : 'category',
        boundaryGap: this.isTimeSeriesData(categoryValues) ? false : true,
        axisLabel: {
          ...baseConfig.axisLabel,
          formatter: this.isTimeSeriesData(categoryValues) ?
            this.formatTimeLabel : undefined
        },
        splitLine: {
          ...baseConfig.splitLine,
          show: this.shouldShowXSplitLines()
        }
      };
    }

    return baseConfig;
  }

  /**
   * 生成折线图系列数据
   */
  private generateLineSeries(): SeriesConfig[] {
    const { numericColumns } = this.data;
    const series: SeriesConfig[] = [];
    const colors = this.getColorPalette();

    numericColumns.forEach((colIndex, seriesIndex) => {
      const data = this.extractSeriesData(colIndex);
      const seriesConfig: SeriesConfig = {
        name: this.data.headers[colIndex],
        type: 'line',
        data: data,
        color: colors[seriesIndex % colors.length],
        smooth: this.shouldEnableSmooth(),
        symbol: this.getSymbolType(seriesIndex),
        symbolSize: this.getSymbolSize(),
        lineStyle: {
          width: 2.5,
          type: this.getLineStyle(seriesIndex),
          shadowBlur: 4,
          shadowColor: colors[seriesIndex % colors.length],
          shadowOffsetY: 2
        },
        itemStyle: {
          borderWidth: 2,
          borderColor: this.theme.backgroundColor,
          shadowBlur: 4,
          shadowColor: colors[seriesIndex % colors.length]
        },
        label: this.options.dataLabels ? {
          show: true,
          position: 'top',
          color: this.theme.textColor,
          fontSize: this.fontSize.label,
          formatter: this.getLabelFormatter()
        } : {
          show: false
        },
        areaStyle: this.shouldEnableArea(seriesIndex) ? {
          opacity: 0.15,
          color: new this.generateAreaGradient(colors[seriesIndex % colors.length])
        } : undefined,
        emphasis: {
          focus: 'series',
          scale: true,
          scaleSize: 1.1,
          lineStyle: {
            width: 4,
            shadowBlur: 10
          },
          itemStyle: {
            shadowBlur: 15,
            shadowColor: colors[seriesIndex % colors.length]
          }
        },
        animationDelay: (idx: number) => idx * 30,
        animationDuration: 1500,
        connectNulls: this.shouldConnectNulls()
      };

      series.push(seriesConfig);
    });

    return series;
  }

  /**
   * 提取系列数据
   */
  private extractSeriesData(columnIndex: number): Array<[string, number]> | number[] {
    const { categoryColumns } = this.data;
    const categoryCol = categoryColumns[0];

    if (categoryCol !== undefined) {
      // 返回二维数组格式，支持时间序列
      return this.data.rows.map(row => [
        row[categoryCol],
        Number(row[columnIndex]) || 0
      ]);
    }

    // 返回简单的一维数组
    return this.data.rows.map(row => Number(row[columnIndex]) || 0);
  }

  /**
   * 检查是否为时间序列数据
   */
  private isTimeSeriesData(categoryValues: string[]): boolean {
    const timePatterns = [
      /^\d{4}-\d{1,2}-\d{1,2}$/,          // YYYY-MM-DD
      /^\d{1,2}\/\d{1,2}\/\d{4}$/,          // MM/DD/YYYY
      /^\d{4}年\d{1,2}月\d{1,2}日$/,        // 中文日期
      /^\d{1,2}月\d{1,2}日$/,               // 中文月日
      /^\d{1,2}:\d{2}$/,                     // HH:MM
      /^周[一二三四五六日天]$/                 // 星期
    ];

    const matchCount = categoryValues.filter(value =>
      timePatterns.some(pattern => pattern.test(value))
    ).length;

    return (matchCount / categoryValues.length) > 0.5;
  }

  /**
   * 格式化时间标签
   */
  private formatTimeLabel = (value: any): string => {
    if (typeof value === 'string') {
      // 尝试解析和格式化时间
      const date = new Date(value);
      if (!isNaN(date.getTime())) {
        return `${date.getMonth() + 1}/${date.getDate()}`;
      }
    }
    return String(value);
  };

  /**
   * 判断是否应该启用平滑曲线
   */
  private shouldEnableSmooth(): boolean {
    const { categoryColumns } = this.data;
    if (categoryColumns.length === 0) return false;

    const categoryCol = categoryColumns[0];
    const categoryValues = this.data.rows.map(row => row[categoryCol]);
    return this.isTimeSeriesData(categoryValues) || this.data.rows.length > 10;
  }

  /**
   * 获取符号类型
   */
  private getSymbolType(seriesIndex: number): string {
    const symbols = ['circle', 'rect', 'triangle', 'diamond', 'pin'];
    return symbols[seriesIndex % symbols.length];
  }

  /**
   * 获取符号大小
   */
  private getSymbolSize(): number {
    const rowCount = this.data.rows.length;
    if (rowCount <= 10) return 8;
    if (rowCount <= 50) return 6;
    return 4;
  }

  /**
   * 获取线条样式
   */
  private getLineStyle(seriesIndex: number): string {
    const styles = ['solid', 'dashed', 'dotted'];
    return seriesIndex < 3 ? styles[seriesIndex] : 'solid';
  }

  /**
   * 判断是否应该启用面积填充
   */
  private shouldEnableArea(seriesIndex: number): boolean {
    // 第一个系列默认启用面积填充
    return seriesIndex === 0 && this.data.numericColumns.length === 1;
  }

  /**
   * 生成面积渐变
   */
  private generateAreaGradient(baseColor: string): any {
    // 这里应该返回ECharts的渐变配置对象
    return baseColor;
  }

  /**
   * 判断是否应该连接空值
   */
  private shouldConnectNulls(): boolean {
    return this.isTimeSeriesData(
      this.data.rows.map(row => row[this.data.categoryColumns[0]])
    );
  }

  /**
   * 判断是否应该显示X轴分割线
   */
  private shouldShowXSplitLines(): boolean {
    return this.data.rows.length <= 20;
  }

  /**
   * 获取标签格式化函数
   */
  private getLabelFormatter(): string {
    const { numericColumns } = this.data;
    if (numericColumns.length > 1) {
      return '{a}<br/>{b}: {c}';
    }
    return '{b}: {c}';
  }

  /**
   * 判断是否应该显示数据缩放
   */
  private shouldShowDataZoom(): boolean {
    return this.data.rows.length > 30;
  }

  /**
   * 生成数据缩放配置
   */
  private generateDataZoomConfig(): any[] {
    return [
      {
        type: 'slider',
        show: true,
        start: 0,
        end: 100,
        height: 30,
        bottom: 10,
        backgroundColor: this.theme.splitLineColor,
        fillerColor: this.theme.getColor(0),
        borderColor: this.theme.borderColor
      },
      {
        type: 'inside',
        start: 0,
        end: 100
      }
    ];
  }

  /**
   * 生成工具箱配置
   */
  private generateToolboxConfig(): any {
    return {
      show: true,
      orient: 'vertical',
      left: 'right',
      top: 'center',
      feature: {
        saveAsImage: {
          show: true,
          title: '保存为图片'
        },
        dataView: {
          show: true,
          title: '数据视图',
          readOnly: false
        },
        magicType: {
          show: true,
          type: ['line', 'bar', 'stack'],
          title: {
            line: '切换为折线图',
            bar: '切换为柱状图',
            stack: '切换为堆叠图'
          }
        },
        restore: {
          show: true,
          title: '还原'
        },
        brush: {
          show: true,
          title: '区域选择'
        }
      }
    };
  }

  /**
   * 生成刷选配置
   */
  private generateBrushConfig(): any {
    return {
      toolbox: ['rect', 'polygon', 'keep', 'clear'],
      xAxisIndex: 'all',
      yAxisIndex: 'all',
      throttle: 100,
      throttleType: 'fixRate'
    };
  }
}