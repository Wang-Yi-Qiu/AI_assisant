/**
 * 柱状图配置实现
 * 继承自BaseChartConfig，专门处理柱状图相关的配置
 */

import { BaseChartConfig, AxisConfig, SeriesConfig, GridConfig } from './BaseChartConfig';
import { LocalChartData } from '../../utils/localChartService';
import { ChartConfigOptions } from './ChartConfigFactory';

/**
 * 柱状图配置类
 */
export class BarChartConfig extends BaseChartConfig {
  constructor(data: LocalChartData, options: ChartConfigOptions = {}) {
    super(data, options);
  }

  /**
   * 获取图表类型
   */
  getChartType(): string {
    return 'bar';
  }

  /**
   * 生成柱状图配置
   */
  generateConfig(): object {
    if (!this.validateData()) {
      throw new Error('Invalid data for bar chart generation');
    }

    const baseConfig = this.getBaseConfig();
    const grid = this.generateGridConfig();
    const xAxis = this.generateXAxisConfig();
    const yAxis = this.generateYAxisConfig();
    const series = this.generateBarSeries();

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
      dataZoom: this.shouldShowDataZoom() ? this.generateDataZoomConfig() : undefined
    };
  }

  /**
   * 生成柱状图系列数据
   */
  private generateBarSeries(): SeriesConfig[] {
    const { numericColumns } = this.data;
    const series: SeriesConfig[] = [];
    const colors = this.getColorPalette();

    numericColumns.forEach((colIndex, seriesIndex) => {
      const data = this.extractSeriesData(colIndex);
      const seriesConfig: SeriesConfig = {
        name: this.data.headers[colIndex],
        type: 'bar',
        data: data,
        color: colors[seriesIndex % colors.length],
        barWidth: this.calculateBarWidth(),
        barGap: '20%',
        itemStyle: {
          borderRadius: [4, 4, 0, 0],
          borderWidth: 0,
          emphasis: {
            shadowBlur: 10,
            shadowColor: 'rgba(0, 0, 0, 0.3)',
            shadowOffsetY: 5
          }
        },
        label: this.options.dataLabels ? {
          show: true,
          position: 'top',
          color: this.theme.textColor,
          fontSize: this.fontSize.label,
          formatter: '{c}'
        } : {
          show: false
        },
        emphasis: {
          itemStyle: {
            shadowBlur: 10,
            shadowColor: 'rgba(0, 0, 0, 0.3)',
            shadowOffsetY: 5,
            borderColor: colors[seriesIndex % colors.length],
            borderWidth: 2
          }
        },
        animationDelay: (idx: number) => idx * 50,
        animationDuration: 1000
      };

      // 添加渐变效果（如果数据适合）
      if (this.shouldUseGradient()) {
        seriesConfig.itemStyle = {
          ...seriesConfig.itemStyle,
          color: new this.generateGradient(colors[seriesIndex % colors.length])
        };
      }

      series.push(seriesConfig);
    });

    return series;
  }

  /**
   * 提取系列数据
   */
  private extractSeriesData(columnIndex: number): number[] {
    return this.data.rows.map(row => {
      const value = Number(row[columnIndex]) || 0;
      return Math.max(0, value); // 确保柱状图不显示负值（除非特殊需求）
    });
  }

  /**
   * 计算柱子宽度
   */
  private calculateBarWidth(): string {
    const rowCount = this.data.rows.length;
    if (rowCount <= 5) return '40%';
    if (rowCount <= 10) return '30%';
    if (rowCount <= 20) return '25%';
    return '20%';
  }

  /**
   * 生成渐变色
   */
  private generateGradient(baseColor: string): any {
    // 这里应该返回ECharts的渐变配置对象
    // 由于ArkTS的类型限制，返回一个简化的配置
    return baseColor;
  }

  /**
   * 判断是否应该使用渐变色
   */
  private shouldUseGradient(): boolean {
    return this.options.dataLabels === true;
  }

  /**
   * 判断是否应该显示数据缩放
   */
  private shouldShowDataZoom(): boolean {
    return this.data.rows.length > 20;
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
        borderColor: this.theme.borderColor,
        textStyle: {
          color: this.theme.textColor
        }
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
          title: '保存为图片',
          backgroundColor: this.theme.backgroundColor
        },
        dataView: {
          show: true,
          title: '数据视图',
          readOnly: false,
          backgroundColor: this.theme.tooltipBackground,
          textColor: this.theme.textColor
        },
        magicType: {
          show: true,
          type: ['line', 'bar'],
          title: {
            line: '切换为折线图',
            bar: '切换为柱状图'
          }
        },
        restore: {
          show: true,
          title: '还原'
        }
      }
    };
  }

  /**
   * 重写X轴配置，优化柱状图显示
   */
  protected generateXAxisConfig(): AxisConfig {
    const baseConfig = super.generateXAxisConfig();

    // 柱状图特定的X轴优化
    if (baseConfig.type === 'category') {
      return {
        ...baseConfig,
        axisLabel: {
          ...baseConfig.axisLabel,
          interval: this.calculateLabelInterval(),
          margin: 15
        },
        axisTick: {
          ...baseConfig.axisTick,
          alignWithLabel: true
        }
      };
    }

    return baseConfig;
  }

  /**
   * 计算标签显示间隔
   */
  private calculateLabelInterval(): number {
    const labelCount = this.data.rows.length;
    if (labelCount <= 10) return 0;
    if (labelCount <= 20) return 1;
    if (labelCount <= 50) return Math.floor(labelCount / 20);
    return Math.floor(labelCount / 15);
  }
}