/**
 * AI服务封装：调用Edge Function generate_chart_qwen生成图表配置
 * @module aiService
 */

import { saveChart } from './supabaseClient';
import { startTimer, endTimer, newRequestId } from './metrics';

export interface ChartConfig {
  title?: { text: string };
  series: Array<{ type: string; [key: string]: any }>;
  [key: string]: any;
}

export interface ErrorResponse {
  code: string;
  message?: string;
  errors?: any[];
}

let lastGeneratedConfig: ChartConfig | null = null;

/**
 * 生成图表配置
 * @param userData 用户输入的数据（CSV解析后的对象、结构化JSON或字符串）
 * @returns Promise<ChartConfig> ECharts配置对象
 * @throws {Error} 当API调用失败或返回错误时
 */
export async function generateChart(userData: unknown): Promise<ChartConfig> {
  const url = getEdgeUrl();
  const requestId = newRequestId();
  const timer = startTimer('chart_generation_client');
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        // TODO: 添加认证token
        // 'Authorization': `Bearer ${await getAuthToken()}`
      },
      body: JSON.stringify(userData),
    });

    if (!res.ok) {
      const errorData: ErrorResponse = await res.json().catch(() => ({ code: 'UNKNOWN_ERROR' }));
      const errorMessage = getErrorMessage(errorData.code, errorData.message);
      endTimer(timer, { requestId, ok: false, code: errorData.code || 'UNKNOWN_ERROR' });
      throw new Error(errorMessage);
    }

    const config: ChartConfig = await res.json();
    lastGeneratedConfig = config;
    endTimer(timer, { requestId, ok: true });
    
    // 保存到Supabase（需要认证token）
    try {
      await saveChart(config);
    } catch (saveError) {
      console.warn('保存图表记录失败:', saveError);
      // 不阻塞主流程，仅警告
    }

    return config;
  } catch (error) {
    endTimer(timer, { requestId, ok: false, error: String(error instanceof Error ? error.message : error) });
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
  // TODO: 从应用配置或环境变量读取
  // const config = getAppConfig();
  // return config.EDGE_GENERATE_CHART_URL || '';
  return 'https://your-project.supabase.co/functions/v1/generate_chart';
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


