/**
 * 基础图表配置抽象类
 * 定义所有图表配置的通用接口和基础功能
 */

import { LocalChartData } from '../../utils/localChartService';
import { ChartTheme } from './ChartTheme';
import { ChartConfigOptions } from './ChartConfigFactory';

// 通用图表配置接口
export interface CommonChartConfig {
  title: string;
  subtitle?: string;
  backgroundColor: string;
  animation: boolean;
  responsive: boolean;
  legend: LegendConfig;
  tooltip: TooltipConfig;
  grid?: GridConfig;
  dataZoom?: DataZoomConfig[];
  toolbox?: ToolboxConfig;
}

// 坐标轴配置接口
export interface AxisConfig {
  type: 'category' | 'value' | 'time' | 'log';
  name?: string;
  nameTextStyle?: TextStyleConfig;
  nameLocation?: 'start' | 'middle' | 'end';
  nameGap?: number;
  axisLine?: AxisLineConfig;
  axisTick?: AxisTickConfig;
  axisLabel?: AxisLabelConfig;
  splitLine?: SplitLineConfig;
  data?: string[];
  min?: number;
  max?: number;
}

// 系列配置接口
export interface SeriesConfig {
  name: string;
  type: string;
  data: any[];
  color?: string | string[];
  symbol?: string;
  symbolSize?: number;
  lineStyle?: LineStyleConfig;
  itemStyle?: ItemStyleConfig;
  areaStyle?: AreaStyleConfig;
  label?: LabelConfig;
  emphasis?: EmphasisConfig;
  smooth?: boolean;
  stack?: string;
  radius?: string | number[];
  center?: string[];
  roseType?: string;
  barWidth?: string | number;
  barGap?: string;
}

// 图例配置接口
export interface LegendConfig {
  show: boolean;
  type?: 'plain' | 'scroll';
  orient?: 'horizontal' | 'vertical';
  left?: string | number;
  top?: string | number;
  right?: string | number;
  bottom?: string | number;
  data?: string[];
  textStyle?: TextStyleConfig;
}

// 提示框配置接口
export interface TooltipConfig {
  show?: boolean;
  trigger?: 'item' | 'axis' | 'none';
  axisPointer?: AxisPointerConfig;
  formatter?: string | ((params: any) => string);
  backgroundColor?: string;
  borderColor?: string;
  borderWidth?: number;
  textStyle?: TextStyleConfig;
}

// 网格配置接口
export interface GridConfig {
  left?: string | number;
  top?: string | number;
  right?: string | number;
  bottom?: string | number;
  containLabel?: boolean;
  backgroundColor?: string;
  borderColor?: string;
  borderWidth?: number;
}

// 文本样式配置接口
export interface TextStyleConfig {
  color?: string;
  fontStyle?: string;
  fontWeight?: string;
  fontFamily?: string;
  fontSize?: number;
  align?: string;
  verticalAlign?: string;
  lineHeight?: number;
}

// 坐标轴线配置接口
export interface AxisLineConfig {
  show?: boolean;
  lineStyle?: LineStyleConfig;
}

// 坐标轴刻度配置接口
export interface AxisTickConfig {
  show?: boolean;
  alignWithLabel?: boolean;
  interval?: string | number;
  inside?: boolean;
  length?: number;
  lineStyle?: LineStyleConfig;
}

// 坐标轴标签配置接口
export interface AxisLabelConfig {
  show?: boolean;
  interval?: string | number;
  inside?: boolean;
  rotate?: number;
  margin?: number;
  color?: string;
  fontSize?: number;
  formatter?: string | ((value: any) => string);
}

// 分割线配置接口
export interface SplitLineConfig {
  show?: boolean;
  lineStyle?: LineStyleConfig;
}

// 线条样式配置接口
export interface LineStyleConfig {
  color?: string;
  width?: number;
  type?: string;
  shadowColor?: string;
  shadowBlur?: number;
  shadowOffsetX?: number;
  shadowOffsetY?: number;
  opacity?: number;
}

// 项目样式配置接口
export interface ItemStyleConfig {
  color?: string;
  borderColor?: string;
  borderWidth?: number;
  borderType?: string;
  shadowColor?: string;
  shadowBlur?: number;
  shadowOffsetX?: number;
  shadowOffsetY?: number;
  opacity?: number;
}

// 面积样式配置接口
export interface AreaStyleConfig {
  color?: string;
  shadowColor?: string;
  shadowBlur?: number;
  shadowOffsetX?: number;
  shadowOffsetY?: number;
  opacity?: number;
}

// 标签配置接口
export interface LabelConfig {
  show?: boolean;
  position?: string;
  distance?: number;
  rotate?: number;
  offset?: number[];
  formatter?: string | ((params: any) => string);
  color?: string;
  fontSize?: number;
}

// 强调配置接口
export interface EmphasisConfig {
  focus?: 'none' | 'self' | 'series';
  scale?: boolean;
  scaleSize?: number;
  label?: LabelConfig;
  itemStyle?: ItemStyleConfig;
  lineStyle?: LineStyleConfig;
}

// 坐标轴指示器配置接口
export interface AxisPointerConfig {
  type?: 'line' | 'shadow' | 'cross';
  axis?: string;
  snap?: boolean;
  label?: LabelConfig;
  lineStyle?: LineStyleConfig;
  shadowStyle?: LineStyleConfig;
}

// 数据缩放配置接口
export interface DataZoomConfig {
  type?: 'slider' | 'inside';
  start?: number;
  end?: number;
  startValue?: any;
  endValue?: any;
  filterMode?: 'filter' | 'weakFilter' | 'empty' | 'none';
}

// 工具箱配置接口
export interface ToolboxConfig {
  show?: boolean;
  orient?: 'horizontal' | 'vertical';
  left?: string | number;
  top?: string | number;
  right?: string | number;
  bottom?: string | number;
  feature?: {
    saveAsImage?: object;
    restore?: object;
    dataView?: object;
    dataZoom?: object;
    magicType?: object;
    brush?: object;
  };
}

/**
 * 基础图表配置抽象类
 */
export abstract class BaseChartConfig {
  protected data: LocalChartData;
  protected options: ChartConfigOptions;
  protected theme: ChartTheme;

  constructor(data: LocalChartData, options: ChartConfigOptions = {}) {
    this.data = data;
    this.options = options;
    this.theme = options.theme || new ChartTheme('dark');
  }

  /**
   * 获取图表类型（子类必须实现）
   */
  abstract getChartType(): string;

  /**
   * 生成完整的图表配置（子类必须实现）
   */
  abstract generateConfig(): object;

  /**
   * 获取通用配置基础
   */
  protected getBaseConfig(): CommonChartConfig {
    return {
      title: this.generateTitle(),
      subtitle: this.options.subtitle,
      backgroundColor: this.theme.backgroundColor,
      animation: this.options.animation !== false,
      responsive: this.options.responsive !== false,
      legend: this.generateLegendConfig(),
      tooltip: this.generateTooltipConfig()
    };
  }

  /**
   * 生成图表标题
   */
  protected generateTitle(): string {
    if (this.options.title) {
      return this.options.title;
    }

    const { headers, numericColumns, categoryColumns } = this.data;
    const chartType = this.getChartType();

    // 智能标题生成
    if (categoryColumns.length > 0 && numericColumns.length > 0) {
      const category = headers[categoryColumns[0]];
      const metric = headers[numericColumns[0]];

      const chartTypeNames = {
        'bar': '柱状图',
        'line': '折线图',
        'pie': '饼图',
        'scatter': '散点图'
      };

      return `${category}${metric}${chartTypeNames[chartType] || '图表'}`;
    }

    return `数据${this.getChartTypeName()}`;
  }

  /**
   * 生成图例配置
   */
  protected generateLegendConfig(): LegendConfig {
    return {
      show: this.data.numericColumns.length > 1,
      orient: 'horizontal',
      left: 'center',
      top: 'top',
      data: this.data.numericColumns.map(col => this.data.headers[col]),
      textStyle: {
        color: this.theme.textColor,
        fontSize: 12
      }
    };
  }

  /**
   * 生成提示框配置
   */
  protected generateTooltipConfig(): TooltipConfig {
    const chartType = this.getChartType();

    return {
      trigger: chartType === 'pie' ? 'item' : 'axis',
      backgroundColor: this.theme.tooltipBackground,
      borderColor: this.theme.borderColor,
      borderWidth: 1,
      textStyle: {
        color: this.theme.textColor,
        fontSize: 12
      },
      formatter: this.generateTooltipFormatter(chartType)
    };
  }

  /**
   * 生成提示框格式化函数
   */
  protected generateTooltipFormatter(chartType: string): string {
    switch (chartType) {
      case 'pie':
        return '{a} <br/>{b}: {c} ({d}%)';
      case 'scatter':
        return '{a}: ({b}, {c})';
      default:
        return '{a} <br/>{b}: {c}';
    }
  }

  /**
   * 生成X轴配置
   */
  protected generateXAxisConfig(): AxisConfig {
    const { categoryColumns } = this.data;

    if (categoryColumns.length > 0) {
      const categoryCol = categoryColumns[0];
      return {
        type: 'category',
        name: this.data.headers[categoryCol],
        nameTextStyle: {
          color: this.theme.textColor,
          fontSize: 12
        },
        axisLine: {
          lineStyle: {
            color: this.theme.axisColor
          }
        },
        axisTick: {
          lineStyle: {
            color: this.theme.axisColor
          }
        },
        axisLabel: {
          color: this.theme.textColor,
          fontSize: 11,
          rotate: this.shouldRotateLabels(categoryCol) ? 45 : 0
        },
        splitLine: {
          lineStyle: {
            color: this.theme.splitLineColor,
            type: 'dashed'
          }
        },
        data: this.data.rows.map(row => row[categoryCol])
      };
    }

    return {
      type: 'value',
      nameTextStyle: {
        color: this.theme.textColor,
        fontSize: 12
      },
      axisLine: {
        lineStyle: {
          color: this.theme.axisColor
        }
      },
      axisLabel: {
        color: this.theme.textColor,
        fontSize: 11
      }
    };
  }

  /**
   * 生成Y轴配置
   */
  protected generateYAxisConfig(): AxisConfig {
    const { numericColumns } = this.data;

    if (numericColumns.length > 0) {
      const numericCol = numericColumns[0];
      return {
        type: 'value',
        name: this.data.headers[numericCol],
        nameTextStyle: {
          color: this.theme.textColor,
          fontSize: 12
        },
        axisLine: {
          lineStyle: {
            color: this.theme.axisColor
          }
        },
        axisTick: {
          lineStyle: {
            color: this.theme.axisColor
          }
        },
        axisLabel: {
          color: this.theme.textColor,
          fontSize: 11
        },
        splitLine: {
          lineStyle: {
            color: this.theme.splitLineColor,
            type: 'dashed'
          }
        }
      };
    }

    return {
      type: 'value',
      nameTextStyle: {
        color: this.theme.textColor,
        fontSize: 12
      },
      axisLine: {
        lineStyle: {
          color: this.theme.axisColor
        }
      },
      axisLabel: {
        color: this.theme.textColor,
        fontSize: 11
      }
    };
  }

  /**
   * 生成网格配置
   */
  protected generateGridConfig(): GridConfig {
    return {
      left: '3%',
      right: '4%',
      bottom: '3%',
      top: '15%',
      containLabel: true
    };
  }

  /**
   * 判断标签是否需要旋转
   */
  private shouldRotateLabels(categoryCol: number): boolean {
    const categoryValues = this.data.rows.map(row => row[categoryCol]);
    const maxLabelLength = Math.max(...categoryValues.map(label => label.length));
    return maxLabelLength > 8;
  }

  /**
   * 获取图表类型名称
   */
  protected getChartTypeName(): string {
    const typeNames = {
      'bar': '柱状图',
      'line': '折线图',
      'pie': '饼图',
      'scatter': '散点图'
    };
    return typeNames[this.getChartType()] || '图表';
  }

  /**
   * 获取颜色数组
   */
  protected getColorPalette(): string[] {
    return this.theme.colorPalette;
  }

  /**
   * 数据预处理
   */
  protected preprocessData(): any[] {
    // 通用数据预处理逻辑
    return this.data.rows;
  }

  /**
   * 验证数据有效性
   */
  protected validateData(): boolean {
    return this.data &&
           this.data.headers &&
           this.data.rows &&
           this.data.rows.length > 0;
  }
}