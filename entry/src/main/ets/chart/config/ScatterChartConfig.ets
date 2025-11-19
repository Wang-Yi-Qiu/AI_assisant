/**
 * 散点图配置实现
 * 继承自BaseChartConfig，专门处理散点图相关的配置
 */

import { BaseChartConfig, AxisConfig, SeriesConfig } from './BaseChartConfig';
import { LocalChartData } from '../../utils/localChartService';
import { ChartConfigOptions } from './ChartConfigFactory';

/**
 * 散点图数据点接口
 */
interface ScatterPoint {
  value: number[];
  itemStyle?: any;
}

/**
 * 散点图配置类
 */
export class ScatterChartConfig extends BaseChartConfig {
  private processedData: ScatterPoint[] = [];

  constructor(data: LocalChartData, options: ChartConfigOptions = {}) {
    super(data, options);
    this.processData();
  }

  /**
   * 获取图表类型
   */
  getChartType(): string {
    return 'scatter';
  }

  /**
   * 生成散点图配置
   */
  generateConfig(): object {
    if (!this.validateData() || this.processedData.length === 0) {
      throw new Error('Invalid data for scatter chart generation');
    }

    const baseConfig = this.getBaseConfig();

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
      tooltip: this.generateScatterTooltipConfig(),
      legend: baseConfig.legend,
      xAxis: this.generateScatterXAxisConfig(),
      yAxis: this.generateScatterYAxisConfig(),
      series: this.generateScatterSeries(),
      animation: baseConfig.animation,
      color: this.getColorPalette(),
      toolbox: this.generateToolboxConfig(),
      brush: this.generateBrushConfig(),
      dataZoom: this.generateDataZoomConfig()
    };
  }

  /**
   * 处理散点图数据
   */
  private processData(): void {
    const { numericColumns, rows } = this.data;

    if (numericColumns.length < 2) {
      return;
    }

    this.processedData = rows.map((row, index) => {
      const point: ScatterPoint = {
        value: [
          Number(row[numericColumns[0]]) || 0,
          Number(row[numericColumns[1]]) || 0
        ]
      };

      // 添加第三维数据作为点的大小（如果有）
      if (numericColumns.length >= 3) {
        const thirdDim = Number(row[numericColumns[2]]) || 1;
        point.value.push(thirdDim);
        point.itemStyle = {
          color: this.getPointColorByValue(thirdDim),
          opacity: this.getPointOpacity(thirdDim)
        };
      } else {
        point.itemStyle = {
          color: this.theme.getColor(index % this.getColorPalette().length),
          opacity: 0.7
        };
      }

      return point;
    });

    // 移除无效数据点
    this.processedData = this.processedData.filter(point =>
      point.value.length >= 2 &&
      !isNaN(point.value[0]) &&
      !isNaN(point.value[1]) &&
      point.value[0] !== 0 &&
      point.value[1] !== 0
    );
  }

  /**
   * 生成散点图系列配置
   */
  private generateScatterSeries(): SeriesConfig[] {
    const { numericColumns, headers } = this.data;
    const colors = this.getColorPalette();

    const seriesConfig: SeriesConfig = {
      name: this.getSeriesName(),
      type: 'scatter',
      data: this.processedData,
      symbolSize: this.calculateSymbolSize(),
      symbol: 'circle',
      itemStyle: {
        borderColor: this.theme.backgroundColor,
        borderWidth: 1,
        shadowBlur: 6,
        shadowColor: 'rgba(0, 0, 0, 0.2)',
        shadowOffsetY: 3
      },
      label: this.options.dataLabels ? {
        show: true,
        position: 'top',
        formatter: (params: any) => {
          if (params.value.length >= 3) {
            return `(${params.value[0]}, ${params.value[1]})\n${params.value[2]}`;
          }
          return `(${params.value[0]}, ${params.value[1]})`;
        },
        color: this.theme.textColor,
        fontSize: this.fontSize.label - 1
      } : {
        show: false
      },
      emphasis: {
        scale: true,
        scaleSize: 1.5,
        itemStyle: {
          borderWidth: 2,
          shadowBlur: 12,
          shadowColor: 'rgba(0, 0, 0, 0.4)',
          shadowOffsetY: 6
        },
        label: {
          show: true,
          color: this.theme.textColor,
          fontSize: this.fontSize.label,
          fontWeight: 'bold'
        }
      },
      animationDelay: (idx: number) => idx * 20,
      animationDuration: 1000
    };

    // 如果有多个数据维度，添加额外的系列
    const series: SeriesConfig[] = [seriesConfig];

    if (numericColumns.length > 2) {
      // 为第三个维度添加不同的可视化
      const thirdDimSeries: SeriesConfig = {
        name: `${headers[numericColumns[0]]} vs ${headers[numericColumns[1]]} (大小: ${headers[numericColumns[2]]})`,
        type: 'scatter',
        data: this.processedData,
        symbolSize: (val: number[]) => {
          if (val.length >= 3) {
            return this.mapValueToSize(val[2]);
          }
          return 6;
        },
        itemStyle: {
          color: colors[1],
          opacity: 0.6
        }
      };
      series.push(thirdDimSeries);
    }

    return series;
  }

  /**
   * 获取系列名称
   */
  private getSeriesName(): string {
    const { numericColumns, headers } = this.data;
    if (numericColumns.length >= 2) {
      return `${headers[numericColumns[0]]} vs ${headers[numericColumns[1]]}`;
    }
    return '散点图';
  }

  /**
   * 生成散点图X轴配置
   */
  private generateScatterXAxisConfig(): AxisConfig {
    const { numericColumns, headers } = this.data;

    // 计算数据范围
    const xValues = this.processedData.map(point => point.value[0]);
    const minX = Math.min(...xValues);
    const maxX = Math.max(...xValues);
    const padding = (maxX - minX) * 0.1;

    return {
      type: 'value',
      name: numericColumns.length > 0 ? headers[numericColumns[0]] : 'X轴',
      nameTextStyle: {
        color: this.theme.textColor,
        fontSize: this.fontSize.axis
      },
      nameLocation: 'middle',
      nameGap: 25,
      min: minX - padding,
      max: maxX + padding,
      axisLine: {
        lineStyle: {
          color: this.theme.axisColor,
          width: 1
        }
      },
      axisTick: {
        show: true,
        lineStyle: {
          color: this.theme.axisColor
        }
      },
      axisLabel: {
        color: this.theme.textColor,
        fontSize: this.fontSize.axis,
        formatter: this.formatAxisLabel
      },
      splitLine: {
        show: true,
        lineStyle: {
          color: this.theme.splitLineColor,
          type: 'dashed'
        }
      }
    };
  }

  /**
   * 生成散点图Y轴配置
   */
  private generateScatterYAxisConfig(): AxisConfig {
    const { numericColumns, headers } = this.data;

    // 计算数据范围
    const yValues = this.processedData.map(point => point.value[1]);
    const minY = Math.min(...yValues);
    const maxY = Math.max(...yValues);
    const padding = (maxY - minY) * 0.1;

    return {
      type: 'value',
      name: numericColumns.length > 1 ? headers[numericColumns[1]] : 'Y轴',
      nameTextStyle: {
        color: this.theme.textColor,
        fontSize: this.fontSize.axis
      },
      nameLocation: 'middle',
      nameGap: 50,
      min: minY - padding,
      max: maxY + padding,
      axisLine: {
        lineStyle: {
          color: this.theme.axisColor,
          width: 1
        }
      },
      axisTick: {
        show: true,
        lineStyle: {
          color: this.theme.axisColor
        }
      },
      axisLabel: {
        color: this.theme.textColor,
        fontSize: this.fontSize.axis,
        formatter: this.formatAxisLabel
      },
      splitLine: {
        show: true,
        lineStyle: {
          color: this.theme.splitLineColor,
          type: 'dashed'
        }
      }
    };
  }

  /**
   * 计算符号大小
   */
  private calculateSymbolSize(): number | ((val: number[]) => number) {
    const { numericColumns } = this.data;

    if (numericColumns.length >= 3) {
      return (val: number[]) => this.mapValueToSize(val[2]);
    }

    // 基于数据密度计算大小
    const dataSize = this.processedData.length;
    if (dataSize <= 50) return 8;
    if (dataSize <= 200) return 6;
    if (dataSize <= 500) return 4;
    return 3;
  }

  /**
   * 将数值映射到符号大小
   */
  private mapValueToSize(value: number): number {
    const { numericColumns, rows } = this.data;

    if (numericColumns.length < 3) return 6;

    // 计算第三个维度的范围
    const values = rows.map(row => Number(row[numericColumns[2]]) || 0);
    const minVal = Math.min(...values);
    const maxVal = Math.max(...values);
    const range = maxVal - minVal;

    if (range === 0) return 6;

    // 映射到 3-15 的大小范围
    const normalizedValue = (value - minVal) / range;
    return Math.floor(3 + normalizedValue * 12);
  }

  /**
   * 根据数值获取点颜色
   */
  private getPointColorByValue(value: number): string {
    const { numericColumns, rows } = this.data;

    if (numericColumns.length < 3) {
      return this.theme.getColor(0);
    }

    // 计算第三个维度的范围
    const values = rows.map(row => Number(row[numericColumns[2]]) || 0);
    const minVal = Math.min(...values);
    const maxVal = Math.max(...values);
    const range = maxVal - minVal;

    if (range === 0) return this.theme.getColor(0);

    // 根据数值选择颜色
    const normalizedValue = (value - minVal) / range;
    const colorIndex = Math.floor(normalizedValue * (this.getColorPalette().length - 1));
    return this.theme.getColor(colorIndex);
  }

  /**
   * 根据数值获取透明度
   */
  private getPointOpacity(value: number): number {
    const { numericColumns, rows } = this.data;

    if (numericColumns.length < 3) return 0.7;

    // 计算第三个维度的范围
    const values = rows.map(row => Number(row[numericColumns[2]]) || 0);
    const minVal = Math.min(...values);
    const maxVal = Math.max(...values);
    const range = maxVal - minVal;

    if (range === 0) return 0.7;

    // 根据数值映射透明度（0.3-0.9）
    const normalizedValue = (value - minVal) / range;
    return 0.3 + normalizedValue * 0.6;
  }

  /**
   * 格式化轴标签
   */
  private formatAxisLabel = (value: any): string => {
    if (typeof value === 'number') {
      if (Math.abs(value) >= 1000) {
        return (value / 1000).toFixed(1) + 'K';
      }
      if (Math.abs(value) >= 1000000) {
        return (value / 1000000).toFixed(1) + 'M';
      }
    }
    return String(value);
  };

  /**
   * 生成散点图提示框配置
   */
  private generateScatterTooltipConfig(): any {
    const { numericColumns, headers } = this.data;

    return {
      show: true,
      trigger: 'item',
      formatter: (params: any) => {
        const { data, seriesName } = params;
        let tooltip = `<strong>${seriesName}</strong><br/>`;

        if (data.value.length >= 2) {
          tooltip += `${headers[numericColumns[0]]}: ${this.formatNumber(data.value[0])}<br/>`;
          tooltip += `${headers[numericColumns[1]]}: ${this.formatNumber(data.value[1])}<br/>`;
        }

        if (data.value.length >= 3) {
          tooltip += `${headers[numericColumns[2]]}: ${this.formatNumber(data.value[2])}`;
        }

        return tooltip;
      },
      backgroundColor: this.theme.tooltipBackground,
      borderColor: this.theme.borderColor,
      borderWidth: 1,
      textStyle: {
        color: this.theme.textColor,
        fontSize: this.fontSize.tooltip
      },
      extraCssText: 'box-shadow: 0 4px 12px rgba(0,0,0,0.15); border-radius: 6px;'
    };
  }

  /**
   * 格式化数字显示
   */
  private formatNumber(num: number): string {
    if (Math.abs(num) >= 1000000) {
      return (num / 1000000).toFixed(2) + 'M';
    }
    if (Math.abs(num) >= 1000) {
      return (num / 1000).toFixed(2) + 'K';
    }
    return num.toFixed(2);
  }

  /**
   * 生成数据缩放配置
   */
  private generateDataZoomConfig(): any[] {
    return [
      {
        type: 'inside',
        xAxisIndex: 0,
        filterMode: 'none'
      },
      {
        type: 'inside',
        yAxisIndex: 0,
        filterMode: 'none'
      },
      {
        type: 'slider',
        xAxisIndex: 0,
        filterMode: 'none',
        backgroundColor: this.theme.splitLineColor,
        fillerColor: this.theme.getColor(0),
        borderColor: this.theme.borderColor
      },
      {
        type: 'slider',
        yAxisIndex: 0,
        filterMode: 'none',
        backgroundColor: this.theme.splitLineColor,
        fillerColor: this.theme.getColor(0),
        borderColor: this.theme.borderColor
      }
    ];
  }

  /**
   * 生成刷选配置
   */
  private generateBrushConfig(): any {
    return {
      toolbox: ['rect', 'polygon', 'clear'],
      xAxisIndex: 0,
      yAxisIndex: 0,
      throttle: 100,
      brushStyle: {
        borderWidth: 2,
        color: this.theme.getColor(0),
        borderColor: this.theme.borderColor
      }
    };
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
   * 重写数据验证
   */
  protected validateData(): boolean {
    const baseValid = super.validateData();
    if (!baseValid) return false;

    const { numericColumns } = this.data;
    return numericColumns.length >= 2;
  }
}