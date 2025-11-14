/**
 * AI服务封装：调用Edge Function generate_chart_qwen生成图表配置
 * @module aiService
 */

import { saveChart, getSupabaseUrl, getSupabaseAnonKey } from './supabaseClient';
import { startTimer, endTimer, newRequestId, LogPayload } from './metrics';
import http from '@ohos.net.http';

export interface EChartsTitle {
  text?: string;
}

export interface EChartsSeriesItem {
  type: string;
}

export interface ChartConfig {
  title?: EChartsTitle;
  series: EChartsSeriesItem[];
}

export interface CSVData {
  headers: string[];
  data: ReadonlyArray<Record<string, string>>;
}

export type UserData = string | Record<string, string | number | boolean | null> | CSVData;

export interface ErrorResponse { code: string; message?: string; errors?: string[] }

let lastGeneratedConfig: ChartConfig | null = null;

/**
 * 生成图表配置
 * @param userData 用户输入的数据（CSV解析后的对象、结构化JSON或字符串）
 * @returns Promise<ChartConfig> ECharts配置对象
 * @throws {Error} 当API调用失败或返回错误时
 */
export async function generateChart(userData: UserData): Promise<ChartConfig> {
  const url = getEdgeUrl();
  const requestId = newRequestId();
  const timer = startTimer('chart_generation_client');
  try {
    const httpRequest = http.createHttp();
    // 构建鉴权头
    const anonKey: string = getSupabaseAnonKey();
    if (!anonKey || anonKey.length === 0) {
      throw new Error('服务异常，请稍后重试: 缺少 Supabase anon key 配置');
    }
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (anonKey && anonKey.length > 0) {
      headers['Authorization'] = `Bearer ${anonKey}`;
      headers['apikey'] = anonKey;
    }
    const response = await httpRequest.request(url, {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: JSON.stringify(userData),
      expectDataType: http.HttpDataType.STRING,
    });
    httpRequest.destroy();

    if (response.responseCode < 200 || response.responseCode >= 300) {
      let errorData: ErrorResponse = { code: 'UNKNOWN_ERROR' };
      try {
        errorData = JSON.parse(String(response.result)) as ErrorResponse;
      } catch {
        // 忽略解析错误，使用默认值
      }
      const errorMessage = getErrorMessage(errorData.code, errorData.message);
      const duration = Date.now() - timer.start;
      const errorPayload: LogPayload = {
        action: timer.id,
        duration: duration,
        timestamp: new Date().toISOString(),
        requestId: requestId,
        ok: false,
        code: errorData.code || 'UNKNOWN_ERROR',
      };
      endTimer(timer, errorPayload);
      throw new Error(errorMessage);
    }

    const config: ChartConfig = JSON.parse(String(response.result)) as ChartConfig;
    lastGeneratedConfig = config;
    const duration = Date.now() - timer.start;
    const successPayload: LogPayload = {
      action: timer.id,
      duration: duration,
      timestamp: new Date().toISOString(),
      requestId: requestId,
      ok: true,
    };
    endTimer(timer, successPayload);
    
    // 保存到Supabase（需要认证token）
    try {
      await saveChart(config);
    } catch (saveError) {
      console.warn('保存图表记录失败:', saveError);
      // 不阻塞主流程，仅警告
    }

    return config;
  } catch (error) {
    const errorMsg: string = error instanceof Error ? error.message : String(error);
    const duration = Date.now() - timer.start;
    const errorPayload: LogPayload = {
      action: timer.id,
      duration: duration,
      timestamp: new Date().toISOString(),
      requestId: requestId,
      ok: false,
      error: errorMsg,
    };
    endTimer(timer, errorPayload);
    if (error instanceof Error) {
      throw new Error(`生成图表失败: ${error.message}`);
    }
    throw new Error('生成图表失败: 未知错误');
  }
}

/**
 * 获取最近生成的图表配置
 */
export function getLastGeneratedConfig(): ChartConfig | null {
  return lastGeneratedConfig;
}

/**
 * 获取Edge Function URL
 * 应从环境配置或应用配置中读取
 */
function getEdgeUrl(): string {
  // 从配置读取 Supabase 基础 URL 并拼接函数路径
  const base = getSupabaseUrl().replace(/\/$/, '');
  return `${base}/functions/v1/generate_chart_qwen`;
}

/**
 * 将错误代码转换为用户友好的中文错误消息
 */
function getErrorMessage(code: string, detail?: string): string {
  const messages: Record<string, string> = {
    'INVALID_INPUT': '输入数据格式无效，请检查数据格式',
    'INVALID_JSON_OUTPUT': 'AI返回格式异常，请重试',
    'INVALID_MODEL_OUTPUT': 'AI返回的图表配置不符合要求',
    'QWEN_ERROR': 'AI服务调用失败，请稍后重试',
    'UNKNOWN_ERROR': '服务异常，请稍后重试',
  };
  const baseMessage = messages[code] || messages['UNKNOWN_ERROR'];
  return detail ? `${baseMessage}: ${detail}` : baseMessage;
}


