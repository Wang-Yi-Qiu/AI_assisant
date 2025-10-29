/**
 * Supabase客户端封装：提供数据库访问能力
 * @module supabaseClient
 */

import { ChartConfig } from './aiService';

interface AscendingOption {
  ascending: boolean;
}

interface QueryResult<T> {
  data: T | null;
  error: Error | null;
}

interface LimitStage<T> {
  limit: (count: number) => Promise<QueryResult<T>>;
}

interface OrderStage<T> {
  order: (column: string, options?: AscendingOption) => LimitStage<T>;
}

interface SelectStage<T> {
  select: (columns?: string) => OrderStage<T>;
}

interface InsertStage {
  insert: (data: Record<string, string | number | boolean | null>) => Promise<QueryResult<Record<string, string | number | boolean | null>>>;
}

type TableRowType = Record<string, string | number | boolean | null>;

interface TableQuery extends SelectStage<readonly TableRowType[]> {
  insert: (data: TableRowType) => Promise<QueryResult<TableRowType>>;
}

interface FromStage {
  from: (table: string) => TableQuery;
}

export interface SupabaseClient extends FromStage {}

let cachedClient: SupabaseClient | null = null;

export function getSupabaseClient(): SupabaseClient {
  if (cachedClient) return cachedClient;
  cachedClient = {} as SupabaseClient;
  return cachedClient;
}

/**
 * 读取 Supabase 项目 URL（公开信息）
 * 注意：生产环境建议从安全配置读取，这里提供默认值以便联调。
 */
export function getSupabaseUrl(): string {
  // 已上线项目 URL（公开）
  return 'https://ugeyrsnrmxjyoflkaapk.supabase.co';
}

/**
 * 读取 Supabase 公共 anon key（仅用于前端调用 Edge/REST，属于公开密钥）。
 * 为避免在仓库中泄露，请在本地开发时通过安全方式注入，并在此函数中返回真实值。
 * 如果返回空字符串，将自动降级为匿名未鉴权请求（会被 401 拒绝）。
 */
export function getSupabaseAnonKey(): string {
  // TODO：请在本地开发环境安全注入 anon key 并返回真实值
  // 例如：
  // 1) DevEco 环境变量/构建变量
  // 2) AppScope 安全存储读取
  // 3) 本地未入库配置文件（.env.local 等）
  return '';
}

export interface ChartRecordRow {
  id?: string;
  title?: string;
  type?: string;
  created_at?: string;
  chart_config?: ChartConfig;
  chartConfig?: ChartConfig;
}

export async function fetchCharts(limit: number = 10): Promise<ChartRecordRow[]> {
  try {
    const client = getSupabaseClient();
    return [];
  } catch (error) {
    console.error('查询图表记录失败:', error);
    throw new Error('加载图表记录失败');
  }
}

export async function saveChart(chartConfig: ChartConfig): Promise<void> {
  try {
    const client = getSupabaseClient();
    const title = chartConfig?.title?.text || '未命名图表';
    console.log(`图表已保存（占位实现）: ${title}`);
  } catch (error) {
    console.error('保存图表失败:', error);
    throw new Error('保存图表记录失败');
  }
}
