/**
 * 图表页：渲染ECharts并支持导出
 * @module ChartPage
 */

import { ChartConfig } from '../utils/aiService';

let currentOption: ChartConfig | null = null;

/**
 * 设置图表配置并渲染
 * @param option ECharts配置对象
 */
export function setChartOption(option: ChartConfig): void {
  if (!option || !option.series || option.series.length === 0) {
    throw new Error('图表配置无效：缺少series数据');
  }

  currentOption = option;
  
  // TODO: 桥接到WebView并调用chart.setOption
  // 在HarmonyOS中：
  // import webview from '@ohos.web.webview';
  // const webComponent = findComponentById('chartWebView');
  // await webComponent.executeJavaScript(`
  //   if (!window.chart) {
  //     window.chart = echarts.init(document.getElementById('chart-container'));
  //   }
  //   window.chart.setOption(${JSON.stringify(option)});
  // `);
  
  console.log('图表配置已设置（占位实现）');
}

/**
 * 获取当前图表配置
 */
export function getCurrentOption(): ChartConfig | null {
  return currentOption;
}

/**
 * 导出图表为PNG（base64编码）
 * @returns Promise<string> base64编码的PNG图片数据URL
 */
export async function exportPng(): Promise<string> {
  if (!currentOption) {
    throw new Error('没有可导出的图表，请先生成图表');
  }

  // TODO: 桥接到WebView的chart.getDataURL
  // await webComponent.executeJavaScript(`
  //   return window.chart.getDataURL({
  //     type: 'png',
  //     backgroundColor: '#fff',
  //     pixelRatio: 2
  //   });
  // `);
  
  // 占位返回值
  return 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
}

/**
 * 导出图表配置为JSON
 */
export function exportJson(): ChartConfig {
  if (!currentOption) {
    throw new Error('没有可导出的图表配置');
  }
  return currentOption;
}

/**
 * 从历史记录加载图表配置
 */
export function loadChartFromRecord(config: ChartConfig): void {
  setChartOption(config);
}


