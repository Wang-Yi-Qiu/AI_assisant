// HistoryPage: list and navigate to previous chart records

import { getSupabaseClient } from '../utils/supabaseClient';

export interface ChartRecord {
  id: string;
  title: string;
  type: string;
  createdAt: string;
  chartConfig: any;
}

export async function fetchChartRecords(limit: number = 10): Promise<ChartRecord[]> {
  // TODO: call Supabase client to fetch charts ordered by createdAt DESC
  // const client = getSupabaseClient();
  // const { data } = await client.from('charts').select('*').order('created_at', { ascending: false }).limit(limit);
  // return data || [];
  return [];
}

export function navigateToChart(record: ChartRecord): void {
  // TODO: navigate to ChartPage with record.chartConfig
  void record;
}

