/**
 * 历史页：列表展示与导航到历史图表记录
 * @module HistoryPage
 */

import { fetchCharts } from '../utils/supabaseClient';
import { ChartConfig } from '../utils/aiService';

export interface ChartRecord {
  id: string;
  title: string;
  type: string;
  createdAt: string;
  chartConfig: ChartConfig;
}

/**
 * 获取图表记录列表（按创建时间倒序）
 * @param limit 返回记录数量限制，默认10条
 * @returns Promise<ChartRecord[]> 图表记录数组
 */
export async function fetchChartRecords(limit: number = 10): Promise<ChartRecord[]> {
  try {
    const charts = await fetchCharts(limit);
    return charts.map((chart: any) => ({
      id: chart.id || '',
      title: chart.title || chart.chart_json?.title?.text || '未命名图表',
      type: chart.type || chart.chart_json?.series?.[0]?.type || 'unknown',
      createdAt: chart.created_at || new Date().toISOString(),
      chartConfig: chart.chart_json || chart.chartConfig || {},
    }));
  } catch (error) {
    console.error('获取历史记录失败:', error);
    throw new Error('加载历史记录失败，请稍后重试');
  }
}

/**
 * 导航到图表页并加载指定记录
 * @param record 图表记录
 */
export function navigateToChart(record: ChartRecord): void {
  if (!record || !record.chartConfig) {
    throw new Error('无效的图表记录');
  }
  
  // TODO: 使用HarmonyOS路由导航到ChartPage
  // import router from '@ohos.router';
  // router.pushUrl({
  //   url: 'pages/ChartPage',
  //   params: { chartConfig: record.chartConfig }
  // });
  
  console.log(`导航到图表: ${record.title} (占位实现)`);
}

