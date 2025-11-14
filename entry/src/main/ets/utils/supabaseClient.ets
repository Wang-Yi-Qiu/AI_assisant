/**
 * Supabase客户端封装：提供数据库访问能力
 * @module supabaseClient
 */

import { ChartConfig } from './aiService';
import { getAppConfig } from './config';
import { authService } from './authService';
import http from '@ohos.net.http';

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

interface DatabaseRow {
  id: string;
  user_id: string;
  chart_config: object;
  created_at: string;
  updated_at: string;
}

interface InsertStage {
  insert: (data: DatabaseRow) => Promise<QueryResult<DatabaseRow>>;
}

type TableRowType = DatabaseRow;

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
  // 从运行时配置读取（EntryAbility 启动时注入），提供默认回退
  const cfg = getAppConfig();
  return (cfg.supabaseUrl || 'https://ugeyrsnrmxjyoflkaapk.supabase.co');
}

/**
 * 读取 Supabase 公共 anon key（仅用于前端调用 Edge/REST，属于公开密钥）。
 * 为避免在仓库中泄露，请在本地开发时通过安全方式注入，并在此函数中返回真实值。
 * 如果返回空字符串，将自动降级为匿名未鉴权请求（会被 401 拒绝）。
 */
export function getSupabaseAnonKey(): string {
  // 由 EntryAbility 在启动时通过 rawfile/supabase.json 注入
  const cfg = getAppConfig();
  return cfg.supabaseAnonKey || '';
}

export interface ChartRecordRow {
  id?: string;
  title?: string;
  type?: string;
  created_at?: string;
  chart_config?: ChartConfig;
  chartConfig?: ChartConfig;
}

// Supabase REST 返回的 charts 表结构（后端字段原样映射）
interface DbChartRow {
  id?: string | number | null;
  title?: string | null;
  type?: string | null;
  created_at?: string | null;
  chart_config?: ChartConfig | null;
}

// 插入 charts 时的请求负载
interface InsertChartPayload {
  title: string;
  type: string;
  chart_config: ChartConfig;
  user_id: string;
}

export async function fetchCharts(limit: number = 10): Promise<ChartRecordRow[]> {
  try {
    const baseUrl: string = getSupabaseUrl().replace(/\/$/, '');
    const anonKey: string = getSupabaseAnonKey();
    const sessionToken = authService.getSessionToken();
    if (!anonKey) {
      throw new Error('缺少 Supabase anon key 配置');
    }

    const userId = authService.getUserId();
    const url: string = `${baseUrl}/rest/v1/charts?select=*&user_id=eq.${encodeURIComponent(userId)}&order=created_at.desc&limit=${encodeURIComponent(String(limit))}`;
    const httpRequest = http.createHttp();
    const response = await httpRequest.request(url, {
      method: http.RequestMethod.GET,
      header: {
        'apikey': anonKey,
        'Authorization': `Bearer ${sessionToken || anonKey}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      expectDataType: http.HttpDataType.STRING,
    });
    httpRequest.destroy();

    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error(`请求失败(${response.responseCode})`);
    }

    const text = String(response.result || '[]');
    const rows = JSON.parse(text) as ReadonlyArray<DbChartRow>;

    const mapped: ChartRecordRow[] = rows.map((row: DbChartRow): ChartRecordRow => {
      const rec: ChartRecordRow = {
        id: row.id !== null && row.id !== undefined ? String(row.id) : '',
        title: typeof row.title === 'string' ? row.title : undefined,
        type: typeof row.type === 'string' ? row.type : undefined,
        created_at: typeof row.created_at === 'string' ? row.created_at : undefined,
        chart_config: row.chart_config ?? undefined,
        chartConfig: row.chart_config ?? undefined,
      };
      return rec;
    });

    return mapped;
  } catch (error) {
    console.error('查询图表记录失败:', error);
    throw new Error('加载图表记录失败');
  }
}

export async function saveChart(chartConfig: ChartConfig): Promise<void> {
  try {
    const baseUrl: string = getSupabaseUrl().replace(/\/$/, '');
    const anonKey: string = getSupabaseAnonKey();
    const sessionToken = authService.getSessionToken();
    if (!anonKey) {
      throw new Error('缺少 Supabase anon key 配置');
    }

    const url: string = `${baseUrl}/rest/v1/charts`;
    const title: string = chartConfig?.title?.text || '未命名图表';
    const type: string = chartConfig?.series?.[0]?.type || 'unknown';
    const userId = authService.getUserId();
    const payload: InsertChartPayload = {
      title: title,
      type: type,
      chart_config: chartConfig,
      user_id: userId, // 使用真实用户ID
    };

    const httpRequest = http.createHttp();
    const response = await httpRequest.request(url, {
      method: http.RequestMethod.POST,
      header: {
        'apikey': anonKey,
        'Authorization': `Bearer ${sessionToken || anonKey}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
        'Accept': 'application/json',
      },
      extraData: JSON.stringify(payload),
      expectDataType: http.HttpDataType.STRING,
    });
    httpRequest.destroy();

    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error(`保存失败(${response.responseCode})`);
    }

    // 成功即返回
  } catch (error) {
    console.error('保存图表失败:', error);
    throw new Error('保存图表记录失败');
  }
}
