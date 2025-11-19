/**
 * 饼图配置实现
 * 继承自BaseChartConfig，专门处理饼图相关的配置
 */

import { BaseChartConfig, SeriesConfig } from './BaseChartConfig';
import { LocalChartData } from '../../utils/localChartService';
import { ChartConfigOptions } from './ChartConfigFactory';

/**
 * 饼图数据项接口
 */
interface PieDataItem {
  name: string;
  value: number;
  itemStyle?: any;
}

/**
 * 饼图配置类
 */
export class PieChartConfig extends BaseChartConfig {
  private aggregatedData: PieDataItem[] = [];

  constructor(data: LocalChartData, options: ChartConfigOptions = {}) {
    super(data, options);
    this.aggregateData();
  }

  /**
   * 获取图表类型
   */
  getChartType(): string {
    return 'pie';
  }

  /**
   * 生成饼图配置
   */
  generateConfig(): object {
    if (!this.validateData() || this.aggregatedData.length === 0) {
      throw new Error('Invalid data for pie chart generation');
    }

    const baseConfig = this.getBaseConfig();

    return {
      title: {
        text: baseConfig.title,
        subtext: baseConfig.subtitle,
        left: 'center',
        top: '5%',
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
      tooltip: this.generatePieTooltipConfig(),
      legend: this.generatePieLegendConfig(),
      series: this.generatePieSeries(),
      animation: baseConfig.animation,
      color: this.getColorPalette(),
      toolbox: this.generateToolboxConfig()
    };
  }

  /**
   * 聚合数据（饼图特殊处理）
   */
  private aggregateData(): void {
    const { categoryColumns, numericColumns, rows } = this.data;

    if (categoryColumns.length === 0 || numericColumns.length === 0) {
      return;
    }

    const categoryCol = categoryColumns[0];
    const numericCol = numericColumns[0];

    // 聚合相同类别的数据
    const dataMap = new Map<string, number>();

    rows.forEach(row => {
      const category = String(row[categoryCol] || '未知');
      const value = Number(row[numericCol]) || 0;
      const currentValue = dataMap.get(category) || 0;
      dataMap.set(category, currentValue + value);
    });

    // 转换为数组并排序
    this.aggregatedData = Array.from(dataMap.entries())
      .map(([name, value]) => ({ name, value }))
      .sort((a, b) => b.value - a.value);

    // 限制最大显示项目数量
    if (this.aggregatedData.length > 10) {
      const topItems = this.aggregatedData.slice(0, 9);
      const othersValue = this.aggregatedData.slice(9).reduce((sum, item) => sum + item.value, 0);
      topItems.push({ name: '其他', value: othersValue });
      this.aggregatedData = topItems;
    }
  }

  /**
   * 生成饼图系列配置
   */
  private generatePieSeries(): SeriesConfig[] {
    const colors = this.getColorPalette();
    const seriesConfig: SeriesConfig = {
      name: this.getPieSeriesName(),
      type: 'pie',
      radius: this.calculatePieRadius(),
      center: ['50%', '55%'],
      data: this.aggregatedData.map((item, index) => ({
        name: item.name,
        value: item.value,
        itemStyle: {
          color: colors[index % colors.length],
          borderRadius: this.aggregatedData.length <= 5 ? 8 : 4,
          borderWidth: 2,
          borderColor: this.theme.backgroundColor,
          emphasis: {
            shadowBlur: 20,
            shadowColor: 'rgba(0, 0, 0, 0.4)',
            shadowOffsetY: 5,
            borderWidth: 3
          }
        },
        label: this.generatePieLabel(item, index),
        labelLine: {
          show: this.shouldShowLabelLine(),
          lineStyle: {
            color: this.theme.textColor,
            width: 1
          }
        },
        emphasis: {
          scale: true,
          scaleSize: 5,
          itemStyle: {
            shadowBlur: 30,
            shadowColor: colors[index % colors.length],
            shadowOffsetY: 10,
            borderWidth: 0
          }
        }
      })),
      roseType: this.shouldUseRoseType() ? 'radius' : undefined,
      animationDelay: (idx: number) => idx * 100,
      animationDuration: 1200,
      avoidLabelOverlap: true,
      stillShowZeroSum: false,
      emptyCircleStyle: {
        color: this.theme.splitLineColor,
        borderColor: this.theme.borderColor,
        borderWidth: 1
      }
    };

    return [seriesConfig];
  }

  /**
   * 获取饼图系列名称
   */
  private getPieSeriesName(): string {
    const { numericColumns, headers } = this.data;
    if (numericColumns.length > 0) {
      return headers[numericColumns[0]];
    }
    return '数值';
  }

  /**
   * 计算饼图半径
   */
  private calculatePieRadius(): string | string[] {
    const dataCount = this.aggregatedData.length;
    if (dataCount <= 3) {
      return ['40%', '70%'];
    }
    if (dataCount <= 6) {
      return ['30%', '65%'];
    }
    return ['25%', '60%'];
  }

  /**
   * 生成饼图标签
   */
  private generatePieLabel(item: PieDataItem, index: number): any {
    const total = this.aggregatedData.reduce((sum, data) => sum + data.value, 0);
    const percentage = ((item.value / total) * 100).toFixed(1);

    if (this.options.dataLabels) {
      return {
        show: true,
        position: this.aggregatedData.length <= 5 ? 'outside' : 'inside',
        formatter: `{b}\n${percentage}%`,
        color: this.theme.textColor,
        fontSize: this.fontSize.label,
        fontWeight: index < 3 ? 'bold' : 'normal',
        backgroundColor: this.aggregatedData.length > 5 ? this.getBackgroundColor(index) : 'transparent',
        borderColor: this.theme.borderColor,
        borderWidth: 1,
        borderRadius: 4,
        padding: [2, 4]
      };
    }

    return {
      show: item.value / total > 0.05, // 只显示占比超过5%的标签
      position: 'inside',
      formatter: '{d}%',
      color: this.theme.backgroundColor,
      fontSize: this.fontSize.label,
      fontWeight: 'bold'
    };
  }

  /**
   * 判断是否应该显示标签线
   */
  private shouldShowLabelLine(): boolean {
    return this.options.dataLabels === true && this.aggregatedData.length <= 8;
  }

  /**
   * 判断是否应该使用玫瑰图
   */
  private shouldUseRoseType(): boolean {
    // 当数据项较少且数值差异不大时使用玫瑰图
    if (this.aggregatedData.length <= 6) {
      const values = this.aggregatedData.map(item => item.value);
      const max = Math.max(...values);
      const min = Math.min(...values);
      return (max - min) / max < 0.5; // 差异小于50%
    }
    return false;
  }

  /**
   * 获取背景色
   */
  private getBackgroundColor(index: number): string {
    const colors = this.getColorPalette();
    return colors[index % colors.length];
  }

  /**
   * 生成饼图提示框配置
   */
  private generatePieTooltipConfig(): any {
    return {
      show: true,
      trigger: 'item',
      formatter: (params: any) => {
        const { name, value, percent } = params;
        const total = this.aggregatedData.reduce((sum, data) => sum + data.value, 0);
        const actualPercent = ((value / total) * 100).toFixed(2);

        return `${name}<br/>数值: ${this.formatNumber(value)}<br/>占比: ${actualPercent}%`;
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
   * 生成饼图图例配置
   */
  private generatePieLegendConfig(): any {
    const data = this.aggregatedData.map(item => item.name);
    const orient = this.aggregatedData.length > 6 ? 'vertical' : 'horizontal';

    return {
      show: true,
      type: this.aggregatedData.length > 10 ? 'scroll' : 'plain',
      orient: orient,
      left: orient === 'horizontal' ? 'center' : 'left',
      top: orient === 'horizontal' ? 'bottom' : 'middle',
      data: data,
      textStyle: {
        color: this.theme.textColor,
        fontSize: this.fontSize.legend
      },
      itemGap: 10,
      itemWidth: 10,
      itemHeight: 10,
      pageButtonItemGap: 5,
      pageButtonGap: 20,
      pageButtonPosition: 'end',
      pageFormatter: '{current}/{total}',
      pageIconColor: this.theme.textColor,
      pageIconInactiveColor: this.theme.splitLineColor,
      pageTextStyle: {
        color: this.theme.textColor
      }
    };
  }

  /**
   * 格式化数字显示
   */
  private formatNumber(num: number): string {
    if (num >= 1000000000) {
      return (num / 1000000000).toFixed(1) + 'B';
    }
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M';
    }
    if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K';
    }
    return num.toString();
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
          backgroundColor: this.theme.backgroundColor,
          excludeComponents: ['toolbox']
        },
        dataView: {
          show: true,
          title: '数据视图',
          readOnly: true,
          backgroundColor: this.theme.tooltipBackground,
          textColor: this.theme.textColor,
          optionToContent: (opt: any) => {
            // 自定义数据视图内容
            const series = opt.series[0];
            const data = series.data;
            let html = '<table style="width:100%;text-align:left;border-collapse:collapse;">';
            html += '<thead><tr><th style="border:1px solid #ddd;padding:8px;">名称</th><th style="border:1px solid #ddd;padding:8px;">数值</th><th style="border:1px solid #ddd;padding:8px;">占比</th></tr></thead>';
            html += '<tbody>';

            const total = data.reduce((sum: number, item: any) => sum + item.value, 0);
            data.forEach((item: any) => {
              const percent = ((item.value / total) * 100).toFixed(2);
              html += `<tr>`;
              html += `<td style="border:1px solid #ddd;padding:8px;">${item.name}</td>`;
              html += `<td style="border:1px solid #ddd;padding:8px;">${this.formatNumber(item.value)}</td>`;
              html += `<td style="border:1px solid #ddd;padding:8px;">${percent}%</td>`;
              html += `</tr>`;
            });

            html += '</tbody></table>';
            return html;
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
   * 重写数据验证
   */
  protected validateData(): boolean {
    const baseValid = super.validateData();
    if (!baseValid) return false;

    const { categoryColumns, numericColumns } = this.data;
    return categoryColumns.length > 0 && numericColumns.length > 0;
  }
}