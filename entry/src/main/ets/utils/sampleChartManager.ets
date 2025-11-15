/**
 * 示例图表管理器：提供预设的示例图表配置
 * @module sampleChartManager
 */

import { ChartConfig } from './aiService';

/**
 * 示例图表元数据接口
 */
export interface SampleChart {
  id: string;
  name: string;
  description: string;
  chartType: 'bar' | 'line' | 'pie';
  icon: string;
  chartConfig: ChartConfig;
}

/**
 * 获取柱状图示例配置
 */
function getBarChartConfig(): ChartConfig {
  return {
    title: {
      text: '月度销售数据',
      left: 'center',
      textStyle: {
        color: '#FFFFFF'
      }
    },
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'shadow'
      }
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '3%',
      containLabel: true
    },
    xAxis: {
      type: 'category',
      data: ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
      nameTextStyle: {
        color: '#FFFFFF'
      }
    },
    yAxis: {
      type: 'value',
      nameTextStyle: {
        color: '#FFFFFF'
      }
    },
    series: [{
      name: '销售额',
      type: 'bar',
      data: [12000, 15000, 18000, 16000, 20000, 22000, 25000, 23000, 27000, 29000, 31000, 35000],
      itemStyle: {
        color: '#007DFF'
      }
    }],
    backgroundColor: '#1C1C1C'
  };
}

/**
 * 获取饼图示例配置
 */
function getPieChartConfig(): ChartConfig {
  return {
    title: {
      text: '产品分类占比',
      left: 'center',
      textStyle: {
        color: '#FFFFFF'
      }
    },
    tooltip: {
      trigger: 'item'
    },
    legend: {
      orient: 'vertical',
      left: 'left'
    },
    series: [{
      name: '产品分类',
      type: 'pie',
      data: [
        { value: 35, name: '电子产品' },
        { value: 25, name: '服装' },
        { value: 20, name: '食品' },
        { value: 12, name: '家居' },
        { value: 8, name: '其他' }
      ]
    }],
    backgroundColor: '#1C1C1C'
  };
}

/**
 * 获取折线图示例配置
 */
function getLineChartConfig(): ChartConfig {
  return {
    title: {
      text: '用户增长趋势',
      left: 'center',
      textStyle: {
        color: '#FFFFFF'
      }
    },
    tooltip: {
      trigger: 'axis'
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '3%',
      containLabel: true
    },
    xAxis: {
      type: 'category',
      data: ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
      nameTextStyle: {
        color: '#FFFFFF'
      }
    },
    yAxis: {
      type: 'value',
      nameTextStyle: {
        color: '#FFFFFF'
      }
    },
    series: [{
      name: '用户数',
      type: 'line',
      data: [1200, 1500, 1800, 2100, 2400, 2700, 3000, 3300, 3600, 3900, 4200, 4500],
      itemStyle: {
        color: '#007DFF'
      }
    }],
    backgroundColor: '#1C1C1C'
  };
}

/**
 * 示例图表列表
 */
const SAMPLE_CHARTS: SampleChart[] = [
  {
    id: 'sample-bar',
    name: '柱状图',
    description: '月度销售数据柱状图',
    chartType: 'bar',
    icon: '📊',
    chartConfig: getBarChartConfig()
  },
  {
    id: 'sample-pie',
    name: '饼图',
    description: '产品分类占比饼图',
    chartType: 'pie',
    icon: '🥧',
    chartConfig: getPieChartConfig()
  },
  {
    id: 'sample-line',
    name: '折线图',
    description: '用户增长趋势折线图',
    chartType: 'line',
    icon: '📈',
    chartConfig: getLineChartConfig()
  }
];

/**
 * 获取所有示例图表列表
 * @returns SampleChart[] 示例图表列表
 */
export function getSampleChartList(): SampleChart[] {
  return SAMPLE_CHARTS;
}

/**
 * 根据ID获取示例图表
 * @param id 示例图表ID
 * @returns SampleChart | undefined 示例图表
 */
export function getSampleChartById(id: string): SampleChart | undefined {
  return SAMPLE_CHARTS.find(item => item.id === id);
}

/**
 * 根据图表类型获取示例图表
 * @param chartType 图表类型
 * @returns SampleChart | undefined 示例图表
 */
export function getSampleChartByType(chartType: 'bar' | 'line' | 'pie'): SampleChart | undefined {
  return SAMPLE_CHARTS.find(item => item.chartType === chartType);
}

