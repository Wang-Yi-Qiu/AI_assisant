/**
 * Supabase客户端封装：提供数据库访问能力
 * @module supabaseClient
 */

import { ChartConfig } from './aiService';

export type SupabaseClient = {
  from: (table: string) => {
    select: (columns?: string) => {
      order: (column: string, options?: { ascending: boolean }) => {
        limit: (count: number) => Promise<{ data: any[] | null; error: any }>;
      };
    };
    insert: (data: any) => Promise<{ data: any | null; error: any }>;
  };
};

let cachedClient: SupabaseClient | null = null;

/**
 * 获取Supabase客户端实例（单例）
 */
export function getSupabaseClient(): SupabaseClient {
  if (cachedClient) return cachedClient;
  
  // TODO: 集成Supabase SDK
  // import { createClient } from '@supabase/supabase-js';
  // const supabaseUrl = getConfig('SUPABASE_URL');
  // const supabaseKey = getConfig('SUPABASE_ANON_KEY');
  // cachedClient = createClient(supabaseUrl, supabaseKey);
  
  cachedClient = {} as SupabaseClient;
  return cachedClient;
}

/**
 * 获取图表记录列表
 * @param limit 返回记录数量限制
 */
export async function fetchCharts(limit: number = 10): Promise<any[]> {
  try {
    const client = getSupabaseClient();
    // TODO: 实现真实查询
    // const { data, error } = await client
    //   .from('charts')
    //   .select('*')
    //   .order('created_at', { ascending: false })
    //   .limit(limit);
    // if (error) throw error;
    // return data || [];
    return [];
  } catch (error) {
    console.error('查询图表记录失败:', error);
    throw new Error('加载图表记录失败');
  }
}

/**
 * 保存图表配置到数据库
 * @param chartConfig ECharts配置对象
 */
export async function saveChart(chartConfig: ChartConfig): Promise<void> {
  try {
    const client = getSupabaseClient();
    const title = chartConfig?.title?.text || '未命名图表';
    const type = chartConfig?.series?.[0]?.type || 'unknown';
    
    // TODO: 实现真实插入（需要认证token）
    // const { error } = await client.from('charts').insert({
    //   chart_json: chartConfig,
    //   title: title,
    //   type: type,
    // });
    // if (error) throw error;
    
    console.log(`图表已保存（占位实现）: ${title}`);
  } catch (error) {
    console.error('保存图表失败:', error);
    throw new Error('保存图表记录失败');
  }
}

